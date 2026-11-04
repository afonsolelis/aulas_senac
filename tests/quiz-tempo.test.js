/**
 * Tempo por pergunta calibrado no painel do professor.
 *
 * O campo "Tempo" do painel chama quiz_tempo, que troca quiz_questions.segundos
 * da sala. Nenhuma suíte exercita o painel contra o Supabase (isso é o
 * scripts/quiz-e2e.mjs), então aqui se guarda o contrato dos dois lados: todo
 * painel tem o controle e o texto do lobby acompanha o valor; a função exige
 * token, limita a faixa e recusa a troca com a pergunta aberta.
 */
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const DIR = path.join(ROOT, 'pages/qualidade2/quiz');
const paineis = fs.readdirSync(DIR).filter((f) => /^aula\d+-painel\.html$/.test(f)).sort();

describe('painéis do quiz: controle de tempo', () => {
  test('existem painéis para validar', () => {
    expect(paineis.length).toBeGreaterThan(0);
  });

  test.each(paineis)('%s tem o campo Tempo e chama quiz_tempo', (arquivo) => {
    const html = fs.readFileSync(path.join(DIR, arquivo), 'utf-8');
    const doc = new JSDOM(html).window.document;

    const campo = doc.querySelector('footer form#form-tempo input#tempo-segundos[type="number"]');
    expect(campo).not.toBeNull();
    expect(campo.getAttribute('min')).toBe('10');
    expect(campo.getAttribute('max')).toBe('600');
    expect(doc.querySelector('form#form-tempo button#btn-tempo[type="submit"]')).not.toBeNull();

    // o lobby não pode prometer 90 s fixos se o professor calibrou outro valor
    expect(doc.querySelector('#lobby-segundos')).not.toBeNull();
    expect(html).toMatch(/db\.rpc\('quiz_tempo'/);
    expect(html).toMatch(/el\('btn-tempo'\)\.disabled\s*=\s*d\.estado === 'pergunta'/);
  });
});

describe('quiz-tempo.sql', () => {
  const sql = fs.readFileSync(path.join(ROOT, 'supabase/quiz-tempo.sql'), 'utf-8');

  test('cria só quiz_tempo, sem destruir nem alterar objeto existente', () => {
    const funcoes = [...sql.matchAll(/create or replace function (\w+)/g)].map((m) => m[1]);
    expect(funcoes).toEqual(['quiz_tempo']);
    expect(sql).not.toMatch(/^\s*(drop|truncate|alter|delete)\b/im);
  });

  test('exige o token do professor', () => {
    expect(sql).toMatch(/quiz_host_tokens[\s\S]{0,300}Token do professor inválido/);
  });

  test('limita a faixa e recusa a troca com a pergunta aberta', () => {
    expect(sql).toMatch(/p_segundos not between 10 and 600/);
    expect(sql).toMatch(/v_estado = 'pergunta'[\s\S]{0,200}'ok', false/);
  });

  test('só mexe nas questões da própria sala', () => {
    expect(sql).toMatch(/update quiz_questions set segundos = p_segundos where session_slug = p_slug;/);
  });
});
