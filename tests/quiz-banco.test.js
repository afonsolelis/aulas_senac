/**
 * Banco público de questões e relatórios.
 *
 * O que se protege aqui é a promessa da página: ela é pública (sem token) e
 * não mostra desempenho individual. Uma chamada a `relatorio` ou `gabarito`
 * colada nela por engano — as duas rotas existem no mesmo app e devolvem nomes
 * ou o gabarito de sala não publicada — passaria despercebida sem este teste.
 * O que as rotas públicas devolvem (só sala publicada, sem nome de aluno) é
 * conferido nos testes do app.
 */
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const PAGINA = 'pages/qualidade2/quiz/banco.html';

const ler = (p) => fs.readFileSync(path.join(ROOT, p), 'utf-8');

describe('banco.html (leitura pública do quiz)', () => {
  let html;
  let doc;

  beforeAll(() => {
    html = ler(PAGINA);
    doc = new JSDOM(html).window.document;
  });

  test('está ligado por um botão na home da disciplina', () => {
    const home = new JSDOM(ler('pages/home_qualidade_2026_2.html')).window.document;
    const link = home.querySelector('a[href="qualidade2/quiz/banco.html"]');
    expect(link).not.toBeNull();
    expect(link.textContent).toMatch(/banco/i);
  });

  test('não chama nenhuma rota que exija token do professor', () => {
    for (const acao of ['relatorio', 'gabarito', 'host', 'publicar', 'tempo']) {
      expect(html).not.toMatch(new RegExp(`api\\.(get|post)\\([^)]*'${acao}'`));
    }
  });

  test('não pede nem guarda token', () => {
    expect(doc.querySelector('#token')).toBeNull();
    expect(html).not.toMatch(/localStorage/);
    expect(html).not.toMatch(/Authorization|token\s*:/);
  });

  test('só lê pelas duas rotas públicas do banco', () => {
    const chamadas = [...html.matchAll(/api\.(?:get|post)\(\s*'quiz',\s*\w+,\s*'([a-z-]+)'/g)].map((m) => m[1]);
    expect(new Set(chamadas)).toEqual(new Set(['banco']));
    const diretas = [...html.matchAll(/fetch\(\s*'([^']+)'/g)].map((m) => m[1]);
    expect(diretas).toEqual(['/api/v1/senac/quiz-banco']);
  });

  test('avisa, na própria página, que não há resultado individual', () => {
    expect(doc.body.textContent).toMatch(/sem resultado individual/i);
  });
});
