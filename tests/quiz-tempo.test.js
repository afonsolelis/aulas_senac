/**
 * Tempo por pergunta calibrado no painel do professor.
 *
 * O campo "Tempo" do painel chama POST /api/v1/senac/quiz/<sala>/tempo, que
 * troca o tempo das questões da sala. Quem exige o token, limita a faixa e
 * recusa a troca com a pergunta aberta é o app (testes dele e o ponta a ponta
 * em aulas-projeto/e2e); aqui se guarda o lado da página: todo painel tem o
 * controle e o texto do lobby acompanha o valor.
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

  test.each(paineis)('%s tem o campo Tempo e chama a rota tempo', (arquivo) => {
    const html = fs.readFileSync(path.join(DIR, arquivo), 'utf-8');
    const doc = new JSDOM(html).window.document;

    const campo = doc.querySelector('footer form#form-tempo input#tempo-segundos[type="number"]');
    expect(campo).not.toBeNull();
    expect(campo.getAttribute('min')).toBe('10');
    expect(campo.getAttribute('max')).toBe('600');
    expect(doc.querySelector('form#form-tempo button#btn-tempo[type="submit"]')).not.toBeNull();

    // o lobby não pode prometer 90 s fixos se o professor calibrou outro valor
    expect(doc.querySelector('#lobby-segundos')).not.toBeNull();
    expect(html).toMatch(/api\.post\('quiz', SLUG, 'tempo'/);
    expect(html).toMatch(/el\('btn-tempo'\)\.disabled\s*=\s*d\.estado === 'pergunta'/);
  });
});
