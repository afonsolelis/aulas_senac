const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const salas = [
  { aula: '02', slug: 'qualidade-q2-a02', seed: 'quiz-seed-aula02-qualidade.sql', slide: 'slide_planejamento-casos-teste.html', material: 'material_planejamento-casos-teste.html' },
  { aula: '03', slug: 'atam-q2-a03', seed: 'quiz-seed-aula03-atam.sql', slide: 'slide_caixa-branca-preta.html', material: 'material_caixa-branca-preta.html' },
  { aula: '04', slug: 'caixa-q2-a04', seed: 'quiz-seed-aula04-caixas.sql', slide: 'slide_introducao-testes-automatizados.html', material: 'material_introducao-testes-automatizados.html' },
  { aula: '05', slug: 'atam-q2-a05', seed: 'quiz-seed-aula05-atam.sql', slide: 'slide_gestao-erros-bugs.html', material: 'material_gestao-erros-bugs.html' },
  { aula: '06', slug: 'bugs-q2-a06', seed: 'quiz-seed-aula06-bugs.sql', slide: 'slide_ci-github-actions.html', material: 'material_ci-github-actions.html' },
  { aula: '07', slug: 'ci-q2-a07', seed: 'quiz-seed-aula07-ci.sql', slide: 'slide_junit-jacoco-sonarcloud.html', material: 'material_junit-jacoco-sonarcloud.html' },
  { aula: '08', slug: 'cobertura-q2-a08', seed: 'quiz-seed-aula08-cobertura.sql', slide: 'slide_wiremock-api-seguras.html', material: 'material_wiremock-api-seguras.html' }
];

describe('quizzes de retomada de Qualidade 2026.2', () => {
  const home = new JSDOM(read('pages/home_qualidade_2026_2.html')).window.document;
  const central = read('pages/qualidade2/quiz/index.html');

  test.each(salas)('Aula $aula possui aula, acessos, material e seed integrados', ({ aula, slug, seed, slide, material }) => {
    const prefixo = `pages/qualidade2/quiz/aula${aula}`;
    for (const sufixo of ['quiz', 'painel', 'relatorio']) {
      expect(fs.existsSync(path.join(root, `${prefixo}-${sufixo}.html`))).toBe(true);
      expect(central).toContain(`aula${aula}-${sufixo}.html`);
    }

    expect(home.querySelector(`a[href="qualidade2/quiz/aula${aula}-quiz.html"]`)).not.toBeNull();
    expect(read(`pages/qualidade2/${slide}`)).toContain(`href="quiz/aula${aula}-painel.html"`);
    expect(read(`pages/qualidade2/material/${material}`)).toContain(`href="../quiz/aula${aula}-quiz.html"`);
    expect(read(`supabase/${seed}`)).toContain(`'${slug}'`);
  });

  test.each(salas.slice(0, 2))('seed da Aula $aula mantém oito questões e quatro alternativas', ({ seed }) => {
    const sql = read(`supabase/${seed}`);
    const alternativas = [...sql.matchAll(/'(\[.*?\])'::jsonb/gs)]
      .map((match) => JSON.parse(match[1].replace(/''/g, "'")));

    expect(alternativas).toHaveLength(8);
    expect(alternativas.every((lista) => lista.length === 4)).toBe(true);
    expect(sql.match(/\),\n\n|\)\n  returning/g)).toHaveLength(8);
  });
});
