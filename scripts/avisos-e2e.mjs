#!/usr/bin/env node
/**
 * Validação ponta a ponta do quadro de avisos, contra o Supabase real.
 *
 *   node scripts/avisos-e2e.mjs <senha-do-professor> [usuario]
 *
 * Percorre login → publicar → listar → editar → remover → restaurar → remover
 * → sair, conferindo o que cada passo devolve. O aviso de teste nasce com
 * escopo 'e2e-teste', que nenhuma página do Hub pede, então ele não aparece
 * para aluno nenhum enquanto o roteiro roda; no fim ele é removido.
 *
 * Serve para confirmar que supabase/avisos-schema.sql e avisos-admin.sql foram
 * aplicados e que os grants estão como devem — inclusive a parte negativa: as
 * funções internas precisam recusar a chave publicável.
 */

const URL_BASE = 'https://lwamaovuxcevsjfvtqhf.supabase.co';
const CHAVE = 'sb_publishable_j0O_u0t7-lDCtBbmqaIz3A_8vAIGcyJ';

const senha = process.argv[2];
const usuario = process.argv[3] || 'afonsolelis';

if (!senha) {
  console.error('uso: node scripts/avisos-e2e.mjs <senha-do-professor> [usuario]');
  process.exit(2);
}

let falhas = 0;
function checar(condicao, descricao, extra) {
  console.log((condicao ? '  ✓ ' : '  ✗ ') + descricao);
  if (!condicao) { falhas++; if (extra !== undefined) console.log('    →', JSON.stringify(extra)); }
}

async function rpc(fn, args) {
  const r = await fetch(`${URL_BASE}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: CHAVE,
      Authorization: `Bearer ${CHAVE}`,
    },
    body: JSON.stringify(args || {}),
  });
  return { status: r.status, corpo: r.ok ? await r.json() : await r.text() };
}

const marca = 'e2e ' + new Date().toISOString();

console.log('\n1. Login');
const errado = await rpc('avisos_login', { p_usuario: usuario, p_senha: senha + 'x' });
checar(errado.corpo && errado.corpo.ok === false, 'senha errada é recusada', errado.corpo);

const login = await rpc('avisos_login', { p_usuario: usuario, p_senha: senha });
checar(login.corpo && login.corpo.ok === true, 'senha correta é aceita', login.corpo);
if (!login.corpo || !login.corpo.ok) {
  console.error('\nSem sessão não dá para seguir. Se a conta bloqueou, rode no SQL Editor:');
  console.error("  update avisos_admin set falhas = 0, bloqueado_ate = null where usuario = '" + usuario + "';");
  process.exit(1);
}
const token = login.corpo.token;
checar(typeof token === 'string' && token.length >= 32, 'token de sessão tem tamanho de token');

console.log('\n2. Publicação');
const pub = await rpc('avisos_publicar', {
  p_token: token,
  p_titulo: 'Aviso de validação — ' + marca,
  p_corpo: 'Publicado por scripts/avisos-e2e.mjs. Some sozinho no fim do roteiro.',
  p_escopo: 'e2e-teste',
  p_fixado: false,
  p_expira_em: null,
});
checar(pub.corpo && pub.corpo.ok === true, 'aviso publicado', pub.corpo);
const id = pub.corpo && pub.corpo.id;

const semToken = await rpc('avisos_publicar', {
  p_token: 'token-invalido', p_titulo: 'não deveria entrar',
  p_corpo: 'não deveria entrar', p_escopo: 'geral', p_fixado: false, p_expira_em: null,
});
checar(semToken.corpo && semToken.corpo.ok === false,
  'publicar sem token válido é recusado', semToken.corpo);

console.log('\n3. Leitura pública');
const doEscopo = await rpc('avisos_listar', { p_escopo: 'e2e-teste' });
checar(Array.isArray(doEscopo.corpo && doEscopo.corpo.avisos), 'avisos_listar responde uma lista');
checar((doEscopo.corpo.avisos || []).some((a) => a.id === id),
  'o aviso publicado aparece para quem pede o escopo dele');

const deOutra = await rpc('avisos_listar', { p_escopo: 'qualidade2' });
checar(!(deOutra.corpo.avisos || []).some((a) => a.id === id),
  'e NÃO aparece para outra disciplina');

console.log('\n4. Edição, remoção e restauro');
const ed = await rpc('avisos_editar', {
  p_token: token, p_id: id,
  p_titulo: 'Aviso de validação (editado) — ' + marca,
  p_corpo: 'Texto trocado pela validação.',
  p_escopo: 'e2e-teste', p_fixado: true, p_expira_em: null,
});
checar(ed.corpo && ed.corpo.ok === true, 'aviso editado', ed.corpo);

const rem = await rpc('avisos_remover', { p_token: token, p_id: id });
checar(rem.corpo && rem.corpo.ok === true, 'aviso removido', rem.corpo);

const sumiu = await rpc('avisos_listar', { p_escopo: 'e2e-teste' });
checar(!(sumiu.corpo.avisos || []).some((a) => a.id === id),
  'removido some da leitura pública');

const volta = await rpc('avisos_restaurar', { p_token: token, p_id: id });
checar(volta.corpo && volta.corpo.ok === true, 'aviso restaurado', volta.corpo);

const painel = await rpc('avisos_painel', { p_token: token });
checar(painel.corpo && painel.corpo.ok === true, 'painel do professor responde', painel.corpo);
checar((painel.corpo.avisos || []).some((a) => a.id === id),
  'o aviso restaurado aparece no painel');

await rpc('avisos_remover', { p_token: token, p_id: id });
const limpo = await rpc('avisos_listar', { p_escopo: 'e2e-teste' });
checar(!(limpo.corpo.avisos || []).some((a) => a.id === id), 'aviso de teste retirado do quadro');

console.log('\n5. Superfície de ataque (o que a chave publicável NÃO pode)');
for (const fn of ['avisos_hash', 'avisos_usuario', 'avisos_novo_token']) {
  const r = await rpc(fn, {});
  checar(r.status === 404 || r.status === 403 || r.status === 401,
    `${fn} não é executável pela API (HTTP ${r.status})`);
}
const tabela = await fetch(`${URL_BASE}/rest/v1/avisos_admin?select=*`, {
  headers: { apikey: CHAVE, Authorization: `Bearer ${CHAVE}` },
});
const linhas = tabela.ok ? await tabela.json() : null;
checar(!tabela.ok || (Array.isArray(linhas) && linhas.length === 0),
  `avisos_admin não entrega linha alguma pela API (HTTP ${tabela.status})`, linhas);

console.log('\n6. Encerramento');
const saiu = await rpc('avisos_sair', { p_token: token });
checar(saiu.corpo && saiu.corpo.ok === true, 'sessão encerrada', saiu.corpo);
const depois = await rpc('avisos_painel', { p_token: token });
checar(depois.corpo && depois.corpo.ok === false, 'token encerrado não abre mais o painel');

console.log(falhas === 0
  ? '\n✅ Quadro de avisos íntegro.\n'
  : `\n❌ ${falhas} verificação(ões) falharam.\n`);
process.exit(falhas === 0 ? 0 : 1);
