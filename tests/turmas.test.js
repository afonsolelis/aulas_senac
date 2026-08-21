const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

describe('Páginas das turmas de 2026.2', () => {
  const rootDir = path.resolve(__dirname, '..');
  const semestres = JSON.parse(
    fs.readFileSync(path.join(rootDir, 'config', 'semestres.json'), 'utf-8')
  );
  const semestre = semestres.semestres.find(({ periodo }) => periodo === '2026.2');
  const turmas = semestre.disciplinas.flatMap(({ turmas: lista = [] }) => lista);

  test('registra as quatro turmas com páginas próprias', () => {
    expect(turmas).toHaveLength(4);

    for (const turma of turmas) {
      expect(turma.pagina).toBeTruthy();
      expect(fs.existsSync(path.join(rootDir, turma.pagina))).toBe(true);
    }
  });

  test.each([
    ['pages/home_qualidade_2026_2.html', 3],
    ['pages/home_tcc2.html', 1],
  ])('%s exibe os botões das turmas', (home, quantidade) => {
    const html = fs.readFileSync(path.join(rootDir, home), 'utf-8');
    const dom = new JSDOM(html);
    const botoes = dom.window.document.querySelectorAll('a[href^="turmas/turma_"]');

    expect(botoes).toHaveLength(quantidade);
  });

  test.each(turmas)('$sigla possui dados e tabela placeholder', (turma) => {
    const html = fs.readFileSync(path.join(rootDir, turma.pagina), 'utf-8');
    const dom = new JSDOM(html);
    const document = dom.window.document;

    expect(document.querySelector('h1').textContent).toContain(turma.sigla);
    expect(document.body.textContent).toContain(String(turma.numero_aula));
    expect(document.querySelector('table')).not.toBeNull();
    expect(document.querySelector('thead').textContent).toContain('Nome');
    expect(document.querySelector('thead').textContent).toContain('Matrícula');
    expect(document.querySelector('thead').textContent).not.toContain('mascarada');
    expect(document.querySelector('thead').textContent).not.toContain('Observações');
    expect(document.querySelectorAll('tbody tr').length).toBeGreaterThanOrEqual(1);
    document.querySelectorAll('.matricula-mascarada').forEach((matricula) => {
      expect(matricula.textContent).toMatch(/^\*+\d{3}$/);
    });
    expect(document.body.textContent).toContain('Dia da semana');
  });

  test.each(turmas)('$sigla exibe dia, horários e salas conforme config/semestres.json', (turma) => {
    expect(turma.dia_semana).toBeTruthy();
    expect(Array.isArray(turma.horarios)).toBe(true);
    expect(turma.horarios).toHaveLength(2);

    const html = fs.readFileSync(path.join(rootDir, turma.pagina), 'utf-8');
    const dom = new JSDOM(html);
    const texto = dom.window.document.body.textContent;

    expect(texto).toContain(turma.dia_semana);
    expect(texto).not.toContain('A definir');

    for (const { inicio, fim, sala } of turma.horarios) {
      expect(sala).toBeTruthy();
      expect(texto).toContain(`${inicio}–${fim} · ${sala}`);
    }
  });
});
