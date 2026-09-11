/**
 * Validação ponta a ponta de um quiz ao vivo.
 *
 *   node scripts/quiz-e2e.mjs <prefixo> <slug-da-sala> [token] [base] [dir-de-screenshots]
 *
 * Exemplos:
 *   node scripts/quiz-e2e.mjs aula04 caixa-q2-a04
 *   node scripts/quiz-e2e.mjs aula05 atam-q2-a05 080909 https://afonsolelis.github.io/aulas_senac/pages/qualidade2/quiz/
 *
 * Sem `base`, roda nos arquivos locais (file://) — o mesmo código das páginas,
 * falando com o Supabase de verdade. Percorre lobby → pergunta → resposta →
 * revelação (disparada sozinha pelo painel) → encerramento → relatório e, no
 * fim, DESCARTA a sala: a validação não deixa jogador de teste no placar da
 * turma nem na série histórica
 * (descartar zera sem arquivar; reiniciar, o que o professor usa, arquiva).
 *
 * A alternativa correta não é chumbada aqui: ela é lida pelo painel do professor
 * (quiz_host devolve o gabarito da pergunta aberta), então o script serve para
 * qualquer sala sem edição.
 */
import { chromium } from 'playwright';
import path from 'node:path';

const [PRE, SALA, TOKEN = '080909', BASE_ARG, SHOTS] = process.argv.slice(2);
if (!PRE || !SALA) {
  console.error('uso: node scripts/quiz-e2e.mjs <prefixo> <slug-da-sala> [token] [base] [shots]');
  process.exit(2);
}
const BASE = BASE_ARG || 'file://' + path.resolve('pages/qualidade2/quiz') + '/';
const RPC = 'https://lwamaovuxcevsjfvtqhf.supabase.co/rest/v1/rpc/';
const KEY = 'sb_publishable_j0O_u0t7-lDCtBbmqaIz3A_8vAIGcyJ';

const rpc = async (fn, body) => (await fetch(RPC + fn, {
  method: 'POST',
  headers: { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})).json();

const erros = [];
const ok = (m) => console.log('  ok   ' + m);
const falha = (m) => { console.log(' FALHA ' + m); erros.push(m); };
const shot = async (p, nome) => { if (SHOTS) await p.screenshot({ path: `${SHOTS}/${PRE}-${nome}.png` }); };

// Simula o aluno trocando de aba por menos de um segundo: a página vê
// visibilitychange com a aba oculta e, em seguida, visível de novo.
const sairDaAba = (p) => p.evaluate(() => {
  const definir = (oculta) => {
    Object.defineProperty(document, 'hidden', { value: oculta, configurable: true });
    Object.defineProperty(document, 'visibilityState', { value: oculta ? 'hidden' : 'visible', configurable: true });
    document.dispatchEvent(new Event('visibilitychange'));
  };
  definir(true);
  return new Promise((r) => setTimeout(() => { definir(false); r(); }, 800));
});

// 'descartar' zera a sala sem arquivar: o jogador de teste não entra na
// série histórica de quiz_relatorios, que é dado de turma.
const inicial = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'descartar' });
if (!inicial.ok) { console.error('não foi possível falar com a sala:', inicial.erro || inicial); process.exit(1); }
ok(`sala ${SALA} zerada para o teste (${inicial.total} perguntas carregadas)`);

const navegador = await chromium.launch();
const ctxAluno = await navegador.newContext({ viewport: { width: 420, height: 900 } });
const aluno = await ctxAluno.newPage();
const ctxProf = await navegador.newContext({ viewport: { width: 1440, height: 810 } });
const prof = await ctxProf.newPage();
for (const [p, n] of [[aluno, 'aluno'], [prof, 'painel']]) {
  p.on('pageerror', (e) => falha(`[${n}] erro de página: ${e.message}`));
  p.on('console', (m) => { if (m.type() === 'error' && !/net::|websocket/i.test(m.text())) falha(`[${n}] console: ${m.text()}`); });
}

// ---- aluno entra -----------------------------------------------------
await aluno.goto(BASE + PRE + '-quiz.html');
await aluno.waitForSelector('[data-tela="entrada"].ativa', { timeout: 20000 });
await aluno.fill('#nome', 'Teste E2E');
await aluno.click('#btn-entrar');
await aluno.waitForSelector('[data-tela="espera"].ativa', { timeout: 20000 });
ok('aluno: inscrito e aguardando');
await aluno.waitForFunction(() => document.getElementById('conexao').textContent.includes('tempo real'), { timeout: 20000 })
  .then(() => ok('aluno: Realtime conectado'))
  .catch(() => falha('aluno: Realtime não conectou — a sala vai depender do polling de 3 s'));

// ---- painel ----------------------------------------------------------
await prof.goto(BASE + PRE + '-painel.html');
await prof.fill('#token', 'token-errado');
await prof.click('#btn-auth');
await prof.waitForFunction(() => document.getElementById('aviso-auth').textContent.includes('Token'), { timeout: 15000 })
  .then(() => ok('painel: token inválido é recusado'))
  .catch(() => falha('painel: token inválido NÃO foi recusado'));
await prof.fill('#token', TOKEN);
await prof.click('#btn-auth');
await prof.waitForSelector('[data-tela="lobby"].ativa', { timeout: 20000 });
await prof.waitForFunction(() => document.querySelectorAll('#nomes .chip').length > 0, { timeout: 20000 });
ok('painel: lobby com ' + JSON.stringify(await prof.$$eval('#nomes .chip', (e) => e.map((x) => x.textContent))));
(await prof.$$eval('#qr img, #qr canvas, #qr table', (e) => e.length > 0))
  ? ok('painel: QR gerado para ' + (await prof.textContent('#url-quiz')))
  : falha('painel: QR não foi gerado');
await shot(prof, 'painel-lobby');

// ---- pergunta 1 ------------------------------------------------------
const t0 = Date.now();
await prof.click('#btn-abrir');
await aluno.waitForSelector('[data-tela="pergunta"].ativa', { timeout: 20000 });
ok(`aluno: pergunta chegou em ${Date.now() - t0} ms`);
const total = await prof.textContent('#m-pergunta');
const alts = await aluno.$$eval('.alt', (e) => e.length);
if (alts < 2) falha('aluno: pergunta veio com ' + alts + ' alternativas'); else ok(`aluno: ${alts} alternativas (${total})`);

// o gabarito vem do painel do professor, então o teste serve para qualquer sala
const visao = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'ver' });
const limite = visao.pergunta.segundos;
for (const [pagina, id, quem] of [[aluno, '#segundos', 'aluno'], [prof, '#m-tempo', 'painel']]) {
  const s = Number(await pagina.textContent(id));
  if (!(s > 0 && s <= limite)) falha(`${quem}: cronômetro fora da faixa (${s} de ${limite})`);
  else ok(`${quem}: cronômetro em ${s}s de ${limite}s`);
}
await shot(aluno, 'aluno-pergunta');

const correta = visao.pergunta.correta;
await aluno.click('.alt >> nth=' + correta);
await aluno.waitForSelector('[data-tela="respondido"].ativa', { timeout: 20000 });
await prof.waitForFunction(() => document.getElementById('m-respostas').textContent === '1', { timeout: 20000 })
  .then(() => ok('painel: contador de respostas subiu'))
  .catch(() => falha('painel: contador de respostas não subiu'));

// Ninguém clica em "Revelar": respondida por todos, a pergunta se fecha
// sozinha na leitura seguinte do painel. É esse avanço que se valida aqui.
await prof.waitForSelector('[data-tela="revelacao"].ativa', { timeout: 20000 })
  .then(() => ok('painel: revelou sozinho depois que todos responderam'))
  .catch(() => falha('painel: NÃO revelou sozinho com todos respondidos'));
await aluno.waitForSelector('[data-tela="revelacao"].ativa', { timeout: 20000 });
const veredito = await aluno.textContent('#veredito-titulo');
if (veredito !== 'Resposta correta') falha(`aluno: respondeu o gabarito e recebeu "${veredito}"`);
else ok('aluno: veredito e pontuação corretos (' + (await aluno.textContent('#veredito-pontos')) + ')');
const explic = (await aluno.textContent('#explicacao')) || '';
if (explic.length < 40) falha('aluno: explicação vazia ou curta demais'); else ok('aluno: explicação exibida');
await shot(prof, 'painel-revelacao');

// ---- restante da sessão ---------------------------------------------
const jogador = await aluno.evaluate((sala) => JSON.parse(localStorage.getItem('quiz:' + sala)).id, SALA);
const n = visao.total;
// Peso e strike valem em toda sala; a checagem ainda é condicional para o caso
// de uma página antiga, sem o aviso de strike, ser validada por este script.
const temStrike = (await aluno.$('#strike-pergunta')) !== null;
let acertosExtras = 0;   // questões além da 1 respondidas com o gabarito
for (let i = 2; i <= n; i++) {
  await prof.click('#btn-abrir');
  await prof.waitForFunction((o) => document.getElementById('m-pergunta').textContent === o, `${i}/${n}`, { timeout: 20000 });
  const v = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'ver' });
  if (!v.pergunta || !v.pergunta.enunciado) falha('pergunta ' + i + ' sem enunciado');
  if (!v.pergunta.explicacao) falha('pergunta ' + i + ' sem explicação no gabarito');
  let escolha = (v.pergunta.correta + 1) % v.pergunta.alternativas.length;

  // Pergunta 2: o aluno sai da aba antes de responder e depois acerta.
  // O acerto fica registrado, o ponto não.
  const comStrike = temStrike && i === 2;
  if (comStrike) {
    await aluno.waitForSelector('[data-tela="pergunta"].ativa', { timeout: 20000 });
    await sairDaAba(aluno);
    await aluno.waitForSelector('#strike-pergunta:not([hidden])', { timeout: 20000 })
      .then(() => ok('aluno: saiu da aba e o aviso de strike apareceu'))
      .catch(() => falha('aluno: saiu da aba e o aviso de strike NÃO apareceu'));
    await prof.waitForFunction(() => document.getElementById('m-strikes').textContent === '1', { timeout: 20000 })
      .then(() => ok('painel: contador de strikes da pergunta subiu'))
      .catch(() => falha('painel: contador de strikes não subiu'));
    escolha = v.pergunta.correta;
  }
  // Última pergunta: vale o dobro em toda sala. Acerta, para conferir o multiplicador.
  const pesada = i === n;
  if (pesada) {
    escolha = v.pergunta.correta;
    (v.pergunta.peso || 1) === 2
      ? ok(`servidor: a última pergunta (${i}) tem peso 2`)
      : falha(`servidor: a última pergunta (${i}) tem peso ${v.pergunta.peso || 1}, não 2 — rode quiz-ajuste-peso-secao.sql`);
    await prof.waitForSelector('#p-dobro:not([hidden])', { timeout: 20000 })
      .then(() => ok('painel: selo Vale o dobro na última pergunta'))
      .catch(() => falha('painel: a última pergunta abriu sem o selo Vale o dobro'));
    await aluno.waitForSelector('#selo-dobro:not([hidden])', { timeout: 20000 })
      .then(() => ok('aluno: selo Vale o dobro na última pergunta'))
      .catch(() => falha('aluno: a última pergunta abriu sem o selo Vale o dobro'));
  }
  if (escolha === v.pergunta.correta) acertosExtras++;

  await rpc('quiz_responder', { p_player: jogador, p_escolha: escolha });
  await prof.waitForSelector('[data-tela="revelacao"].ativa', { timeout: 20000 });

  if (comStrike || pesada) {
    const e = await rpc('quiz_estado', { p_slug: SALA, p_player: jogador });
    if (comStrike) {
      (e.acertei && e.pontos_rodada === 0 && e.strike)
        ? ok('servidor: acerto com strike valeu 0 ponto')
        : falha(`servidor: acerto com strike valeu ${e.pontos_rodada} (acertei=${e.acertei}, strike=${e.strike})`);
    }
    if (pesada) {
      (e.pontos_rodada >= 600 * v.pergunta.peso)
        ? ok(`servidor: a pergunta ${i} valeu ${e.pontos_rodada} pt (peso ${v.pergunta.peso})`)
        : falha(`servidor: a pergunta ${i} tem peso ${v.pergunta.peso} e valeu só ${e.pontos_rodada} pt`);
    }
  }
}
ok(`painel: as ${n} perguntas abriram e revelaram sozinhas em sequência`);

await prof.click('#btn-encerrar');
await aluno.waitForSelector('[data-tela="final"].ativa', { timeout: 20000 });
ok('aluno: encerramento — ' + (await aluno.textContent('#final-resumo')).trim());
const temas = await aluno.$$eval('#meus-temas li', (e) => e.length);
const erradas = n - 1 - acertosExtras;
if (temas !== erradas) falha(`aluno: esperava ${erradas} temas a retomar, veio ${temas}`);
else ok(`aluno: ${temas} temas a retomar listados`);
await shot(prof, 'painel-final');

// ---- relatório -------------------------------------------------------
const rel = await ctxProf.newPage();
rel.on('pageerror', (e) => falha('[relatório] ' + e.message));
await rel.goto(BASE + PRE + '-relatorio.html');
if (await rel.isVisible('#token')) { await rel.fill('#token', TOKEN); await rel.click('#btn-auth'); }
await rel.waitForSelector('[data-painel="dados"].ativo', { timeout: 20000 });
const nTemas = await rel.$$eval('#lista-temas .item', (e) => e.length);
if (nTemas !== n) falha(`relatório: ${nTemas} temas para ${n} questões — confira o campo tema do seed`);
else ok(`relatório: ${n} temas, acerto médio ${await rel.textContent('#m-media')}`);
if (temStrike) {
  const r = await rpc('quiz_relatorio', { p_slug: SALA, p_token: TOKEN });
  const eu = (r.alunos || []).find((a) => a.nome === 'Teste E2E');
  (eu && eu.strikes === 1)
    ? ok(`relatório: 1 strike registrado (Q${eu.questoes_strike.join(', Q')})`)
    : falha(`relatório: esperava 1 strike, veio ${eu ? eu.strikes : 'nenhum estudante'}`);
}
await shot(rel, 'relatorio');

await navegador.close();
const fim = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'descartar' });
ok(`sala devolvida para a aula: estado=${fim.estado}, jogadores=${fim.jogadores}, perguntas=${fim.total}`);

if (erros.length) { console.log('\nPROBLEMAS:\n- ' + erros.join('\n- ')); process.exit(1); }
console.log('\nTUDO VERDE');
