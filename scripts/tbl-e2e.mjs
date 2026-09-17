/**
 * Validação ponta a ponta de um TBL ao vivo.
 *
 *   node scripts/tbl-e2e.mjs <prefixo> <slug-da-sala> [token] [dir-de-screenshots]
 *
 * Exemplo:
 *   node scripts/tbl-e2e.mjs aula07 ff-q2-a07-tbl
 *
 * Roda nos arquivos locais (file://), com o mesmo código das páginas, falando
 * com o Supabase de verdade. Um painel e dois alunos percorrem: lobby com o
 * caso → primeira decisão → discussão → segunda decisão → síntese da questão
 * 1, conferem que o dado novo da questão que o tiver só aparece a partir da
 * discussão e terminam no consolidado. No fim, DESCARTA a sala (zera sem
 * arquivar): a validação não deixa aluno de teste no histórico da turma.
 *
 * Não rode durante a aula: descartar desconecta quem estiver na sala.
 */
import { chromium } from 'playwright';
import path from 'node:path';

const [PRE, SALA, TOKEN = '080909', SHOTS] = process.argv.slice(2);
if (!PRE || !SALA) {
  console.error('uso: node scripts/tbl-e2e.mjs <prefixo> <slug-da-sala> [token] [shots]');
  process.exit(2);
}
const BASE = 'file://' + path.resolve('pages/qualidade2/tbl') + '/';
const RPC = 'https://lwamaovuxcevsjfvtqhf.supabase.co/rest/v1/rpc/';
const KEY = 'sb_publishable_j0O_u0t7-lDCtBbmqaIz3A_8vAIGcyJ';
const PADRAO = SALA === 'ff-q2-a07-tbl' ? '' : `?sala=${SALA}`;

const rpc = async (fn, body) => (await fetch(RPC + fn, {
  method: 'POST',
  headers: { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
})).json();

const erros = [];
const ok = (m) => console.log('  ok   ' + m);
const falha = (m) => { console.log(' FALHA ' + m); erros.push(m); };
const shot = async (p, nome) => { if (SHOTS) await p.screenshot({ path: `${SHOTS}/${PRE}-tbl-${nome}.png`, fullPage: false }); };
const confere = (cond, m) => (cond ? ok(m) : falha(m));
const espera = async (p, fn, arg, m, timeout = 15000) => {
  try { await p.waitForFunction(fn, arg, { timeout }); ok(m); }
  catch { falha(m); }
};

const inicial = await rpc('hubtbl_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'descartar' });
if (!inicial.ok) { console.error('não foi possível falar com a sala:', inicial.erro || inicial); process.exit(1); }
ok(`sala ${SALA} zerada para o teste (${inicial.total_questoes} questões carregadas)`);

const browser = await chromium.launch();
try {
  const painelCtx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const painel = await painelCtx.newPage();
  painel.on('dialog', (d) => d.accept());
  await painel.goto(BASE + `${PRE}-painel.html${PADRAO}`);
  await painel.fill('#token', TOKEN);
  await painel.click('#form-token button');
  await espera(painel, () => !document.querySelector('#painel').hidden, null, 'painel autenticado');
  await espera(painel, () => document.querySelector('#projecao').textContent.includes('Caso em projeção'), null, 'painel projeta o caso no lobby');
  confere(await painel.locator('#qr-alvo img, #qr-alvo canvas').count() > 0, 'painel desenha o código QR');
  await shot(painel, 'painel-lobby');

  const alunos = [];
  for (const nome of ['Teste TBL A', 'Teste TBL B']) {
    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const p = await ctx.newPage();
    await p.goto(BASE + `${PRE}-tbl.html${PADRAO}`);
    await p.fill('#nome', nome);
    await p.click('#form-entrada button');
    await espera(p, () => !document.querySelector('#tela-sala').hidden, null, `${nome} entrou na sala`);
    alunos.push(p);
  }
  await espera(alunos[0], () => document.querySelector('#conteudo').textContent.includes('Leia o caso com atenção'), null, 'aluno lê o caso no lobby');
  confere(!(await alunos[0].locator('button.opcao').count()), 'lobby não mostra alternativas ao aluno');
  await shot(alunos[0], 'aluno-lobby');

  const fase = (p, texto) => espera(p, (t) => document.querySelector('#selo-fase').textContent.startsWith(t), texto, `aluno em "${texto}"`);
  const decidir = async (p, escolha, texto) => {
    await p.locator(`button.opcao[data-escolha="${escolha}"]`).click();
    await p.fill('#justificativa', texto);
    await p.click('#registrar');
    await espera(p, () => document.querySelector('#recado').textContent.startsWith('Decisão registrada'), null, `decisão ${'ABCD'[escolha]} registrada`);
  };
  const acao = async (a) => {
    await painel.click(`[data-acao="${a}"]`);
    await painel.waitForFunction(() => !document.querySelector('#recado').textContent.startsWith('Atualizando'), null, { timeout: 15000 });
  };

  // Questão 1, ciclo completo.
  await acao('avancar');
  await fase(alunos[0], 'Primeira decisão · questão 1');
  confere(await alunos[0].locator('button.opcao').count() === 4, 'questão 1 mostra quatro táticas');
  confere(!(await alunos[0].locator('text=Dado novo').count()), 'primeira decisão não mostra dado novo');
  await decidir(alunos[0], 0, 'cenário com medida torna o requisito testável');
  await decidir(alunos[1], 1, 'tabela deixa a precedência explícita');
  await shot(alunos[0], 'aluno-voto1');
  await espera(painel, () => document.querySelector('#decidiram').textContent === '2', null, 'painel conta 2 decisões');

  await acao('avancar');
  await fase(alunos[1], 'Discussão');
  await espera(alunos[1], () => document.querySelector('#conteudo').textContent.includes('Perguntas que organizam a discussão'), null, 'discussão mostra o roteiro');
  await espera(alunos[1], () => document.querySelector('#conteudo').textContent.includes('tabela deixa a precedência'), null, 'justificativas circulam na discussão');
  await shot(alunos[1], 'aluno-discussao');
  await shot(painel, 'painel-discussao');

  await acao('avancar');
  await fase(alunos[0], 'Segunda decisão');
  await decidir(alunos[0], 3, 'mudei: o incidente real define o critério');
  await decidir(alunos[1], 1, 'mantive a tabela depois da discussão');

  await acao('avancar');
  await fase(alunos[0], 'Síntese');
  await espera(alunos[0], () => document.querySelector('#conteudo').textContent.includes('mudaram a decisão'), null, 'síntese mostra quem mudou');
  await espera(alunos[0], () => document.querySelector('#conteudo').textContent.includes('A → D'), null, 'síntese mostra a trajetória A → D');
  await shot(alunos[0], 'aluno-sintese');

  // Percorre as demais questões conferindo o corte do dado novo.
  let viuDadoNovo = false;
  const total = inicial.total_questoes;
  for (let q = 2; q <= total; q++) {
    await acao('avancar');
    await fase(alunos[0], `Primeira decisão · questão ${q}`);
    const antes = await alunos[0].locator('text=Dado novo').count();
    confere(antes === 0, `questão ${q}: dado novo oculto na primeira decisão`);
    await decidir(alunos[0], (q + 1) % 4, `decisão de teste na questão ${q}`);
    await acao('avancar');
    await fase(alunos[0], 'Discussão');
    await alunos[0].waitForTimeout(800);
    const reservado = await painel.evaluate(() => !document.querySelector('#reservado').hidden);
    if (reservado) {
      await espera(alunos[0], () => document.querySelector('#conteudo').textContent.includes('Evidências apuradas'), null, `questão ${q}: dado novo liberado na discussão`);
      viuDadoNovo = true;
      await shot(alunos[0], `aluno-dado-novo-q${q}`);
    }
    await acao('avancar');
    await fase(alunos[0], 'Segunda decisão');
    if (reservado) {
      await espera(alunos[0], () => document.querySelector('label[for=justificativa]').textContent.includes('sobrevive ao dado novo'), null, `questão ${q}: segunda decisão pergunta sobre o dado novo`);
    }
    await acao('avancar');
    await fase(alunos[0], 'Síntese');
  }
  confere(viuDadoNovo, 'pelo menos uma questão liberou dado novo');

  await acao('avancar');
  await fase(alunos[0], 'Fechamento');
  await espera(alunos[0], () => document.querySelector('#conteudo').textContent.includes('Cinco decisões sobre o mesmo produto'), null, 'aluno vê o fechamento');
  await espera(painel, () => document.querySelectorAll('#projecao h3').length >= 5, null, 'painel projeta o consolidado das questões');
  await shot(alunos[0], 'aluno-fechamento');
  await shot(painel, 'painel-fechamento');
} finally {
  await browser.close();
  const fim = await rpc('hubtbl_host', { p_slug: SALA, p_token: TOKEN, p_acao: 'descartar' });
  console.log(fim.ok && fim.fase === 'lobby' && fim.inscritos === 0
    ? '  ok   sala descartada e de volta ao lobby'
    : ' FALHA não foi possível descartar a sala: ' + JSON.stringify(fim).slice(0, 200));
}

console.log(erros.length ? `\n${erros.length} falha(s).` : '\nTBL validado de ponta a ponta.');
process.exit(erros.length ? 1 : 0);
