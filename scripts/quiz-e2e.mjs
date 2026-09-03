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
 * revelação → encerramento → relatório e, no fim, REINICIA a sala: a validação
 * não deixa jogador de teste no placar da turma.
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

const inicial = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'reiniciar' });
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
for (const [pagina, id, quem] of [[aluno, '#segundos', 'aluno'], [prof, '#m-tempo', 'painel']]) {
  const s = Number(await pagina.textContent(id));
  if (!(s > 0 && s <= 60)) falha(`${quem}: cronômetro fora da faixa (${s})`); else ok(`${quem}: cronômetro em ${s}s`);
}
await shot(aluno, 'aluno-pergunta');

// o gabarito vem do painel do professor, então o teste serve para qualquer sala
const visao = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'ver' });
const correta = visao.pergunta.correta;
await aluno.click('.alt >> nth=' + correta);
await aluno.waitForSelector('[data-tela="respondido"].ativa', { timeout: 20000 });
await prof.waitForFunction(() => document.getElementById('m-respostas').textContent === '1', { timeout: 20000 })
  .then(() => ok('painel: contador de respostas subiu'))
  .catch(() => falha('painel: contador de respostas não subiu'));

await prof.click('#btn-revelar');
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
for (let i = 2; i <= n; i++) {
  await prof.click('#btn-abrir');
  await prof.waitForFunction((o) => document.getElementById('m-pergunta').textContent === o, `${i}/${n}`, { timeout: 20000 });
  const v = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'ver' });
  if (!v.pergunta || !v.pergunta.enunciado) falha('pergunta ' + i + ' sem enunciado');
  if (!v.pergunta.explicacao) falha('pergunta ' + i + ' sem explicação no gabarito');
  await rpc('quiz_responder', { p_player: jogador, p_escolha: (v.pergunta.correta + 1) % v.pergunta.alternativas.length });
  await prof.click('#btn-revelar');
  await prof.waitForSelector('[data-tela="revelacao"].ativa', { timeout: 20000 });
}
ok(`painel: as ${n} perguntas abriram e revelaram em sequência`);

await prof.click('#btn-encerrar');
await aluno.waitForSelector('[data-tela="final"].ativa', { timeout: 20000 });
ok('aluno: encerramento — ' + (await aluno.textContent('#final-resumo')).trim());
const temas = await aluno.$$eval('#meus-temas li', (e) => e.length);
if (temas !== n - 1) falha(`aluno: esperava ${n - 1} temas a retomar, veio ${temas}`);
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
await shot(rel, 'relatorio');

await navegador.close();
const fim = await rpc('quiz_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'reiniciar' });
ok(`sala devolvida para a aula: estado=${fim.estado}, jogadores=${fim.jogadores}, perguntas=${fim.total}`);

if (erros.length) { console.log('\nPROBLEMAS:\n- ' + erros.join('\n- ')); process.exit(1); }
console.log('\nTUDO VERDE');
