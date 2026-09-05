const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const doc = (file) => new JSDOM(read(file)).window.document;
const semester = JSON.parse(read('config/semestres.json')).semestres
  .find(({ periodo }) => periodo === '2026.2');

describe('Cronogramas de 2026.2', () => {
  test.each(semester.disciplinas)('$slug mantém as semanas em ordem, sem lacunas', (discipline) => {
    const cards = [...doc(discipline.home).querySelectorAll('.list-group-item')];
    const weeks = cards.map((card) => card.textContent.match(/Semana\s+(\d+)/))
      .filter(Boolean).map((match) => Number(match[1]));
    const { semana_inicio: start, semana_fim: end } = semester.calendario;
    expect(weeks).toEqual(Array.from({ length: end - start + 1 }, (_, i) => start + i));
  });

  test.each(semester.disciplinas)('$slug mantém a semana da capa e do material igual à home', (discipline) => {
    for (const card of doc(discipline.home).querySelectorAll('.list-group-item')) {
      const slide = card.querySelector('a[href*="/slide_"]');
      if (!slide) continue;
      const week = Number(card.textContent.match(/Semana\s+(\d+)/)[1]);
      const slidePath = path.join(path.dirname(discipline.home), slide.getAttribute('href'));
      const deck = doc(slidePath);
      const coverWeek = [...deck.querySelectorAll('.slide:first-child .badge, #slide-1 .badge')]
        .map((badge) => badge.textContent.match(/Semana\s+(\d+)/i)).find(Boolean);
      expect({ file: slidePath, week: Number(coverWeek?.[1]) }).toEqual({ file: slidePath, week });
      const material = card.querySelector('a[href*="/material/"]');
      expect(material).not.toBeNull();
      const materialPath = path.join(path.dirname(discipline.home), material.getAttribute('href'));
      const header = doc(materialPath).querySelector('header');
      const materialWeek = header?.textContent.match(/Semana\s+(\d+)/i);
      // Alguns materiais não exibem semana; quando exibem, ela precisa coincidir.
      if (materialWeek) expect({ file: materialPath, week: Number(materialWeek[1]) })
        .toEqual({ file: materialPath, week });
    }
  });

  test('Qualidade mantém JUnit → WireMock → prova, com o marco e a tabela sincronizados', () => {
    const quality = semester.disciplinas.find(({ slug }) => slug === 'qualidade2');
    const cards = [...doc(quality.home).querySelectorAll('.list-group-item')];
    const wiremock = cards.findIndex((card) => card.querySelector('a[href$="slide_wiremock-api-seguras.html"]'));
    expect(wiremock).toBeGreaterThan(0);
    expect(cards[wiremock - 1].querySelector('a[href$="slide_junit-jacoco-sonarcloud.html"]')).not.toBeNull();
    const exam = cards[wiremock + 1];
    expect(exam.querySelector('h5').textContent.trim()).toBe('Prova');
    const week = quality.marcos.prova.semana;
    expect(exam.textContent).toMatch(new RegExp(`Semana\\s+${week}\\b`));
    const intro = doc('pages/qualidade2/slide_introducao-qualidade.html');
    const examCard = [...intro.querySelectorAll('.card')].find((card) => card.textContent.includes('Prova Escrita'));
    expect(examCard.textContent).toMatch(new RegExp(`Semana\\s+${week}\\b`));
    const rows = [...doc('pages/qualidade2/especificacao-projeto.html').querySelectorAll('tr')];
    const examRow = rows.find((row) => row.textContent.includes('Prova escrita'));
    expect(Number(examRow.cells[0].textContent)).toBe(week);
    for (const [topic, offset] of [['JUnit', -2], ['WireMock', -1]]) {
      const row = rows.find((item) => item.textContent.includes(topic));
      expect(Number(row.cells[0].textContent)).toBe(week + offset);
      const summary = [...intro.querySelectorAll('.list-group-item')].find((item) => item.textContent.includes(topic));
      expect(summary.textContent).toMatch(new RegExp(`S${week + offset}\\b`));
    }
  });
});
