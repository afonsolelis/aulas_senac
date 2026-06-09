const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');

function loadHTML(filePath) {
  const html = fs.readFileSync(path.join(ROOT, filePath), 'utf-8');
  const dom = new JSDOM(html);
  return dom.window.document;
}

describe('index.html (seletor de semestre)', () => {
  let doc;

  beforeAll(() => {
    doc = loadHTML('index.html');
  });

  describe('HEAD', () => {
    test('tem <html lang="pt-br">', () => {
      expect(doc.documentElement.lang).toBe('pt-br');
    });

    test('tem <meta charset="UTF-8">', () => {
      const meta = doc.querySelector('meta[charset]');
      expect(meta).not.toBeNull();
      expect(meta.getAttribute('charset').toUpperCase()).toBe('UTF-8');
    });

    test('tem <meta name="viewport">', () => {
      expect(doc.querySelector('meta[name="viewport"]')).not.toBeNull();
    });

    test('<title> contém "Hub de Aulas"', () => {
      expect(doc.title).toContain('Hub de Aulas');
    });

    test('carrega CSS do Bootstrap via CDN', () => {
      const stylesheets = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      expect(stylesheets.find(l => l.href.includes('bootstrap'))).toBeDefined();
    });

    test('carrega o CSS customizado (css/style.css)', () => {
      const stylesheets = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      expect(stylesheets.find(l => l.getAttribute('href') === 'css/style.css')).toBeDefined();
    });
  });

  describe('Tema do seletor', () => {
    test('body usa a classe semester-hub (tema escuro distinto)', () => {
      expect(doc.body.classList.contains('semester-hub')).toBe(true);
    });

    test('topo tem logo do Senac com alt text', () => {
      const logo = doc.querySelector('header img');
      expect(logo).not.toBeNull();
      expect((logo.getAttribute('alt') || '').toLowerCase()).toContain('senac');
    });

    test('tem link para a página do Professor', () => {
      const links = Array.from(doc.querySelectorAll('a[href]'));
      expect(links.find(l => l.getAttribute('href') === 'pages/professor.html')).toBeDefined();
    });
  });

  describe('Seção #semestres', () => {
    test('existe a seção com id "semestres"', () => {
      expect(doc.querySelector('#semestres')).not.toBeNull();
    });

    test('tem exatamente 3 cards de semestre (.semester-card)', () => {
      expect(doc.querySelectorAll('#semestres .semester-card').length).toBe(3);
    });

    test.each([
      ['2025.2', 'pages/home_2025_2.html'],
      ['2026.1', 'pages/home_2026_1.html'],
      ['2026.2', 'pages/home_2026_2.html'],
    ])('card de %s aponta para %s', (_periodo, href) => {
      const links = Array.from(doc.querySelectorAll('#semestres a.semester-card'));
      expect(links.find(l => l.getAttribute('href') === href)).toBeDefined();
    });

    test('os cards de semestre são clicáveis (o próprio card é um <a>)', () => {
      const cards = Array.from(doc.querySelectorAll('#semestres .semester-card'));
      cards.forEach(card => expect(card.tagName.toLowerCase()).toBe('a'));
    });

    test('todos os links de semestre apontam para arquivos que existem no disco', () => {
      const hrefs = Array.from(doc.querySelectorAll('#semestres a[href]')).map(l => l.getAttribute('href'));
      hrefs.forEach(href => expect(fs.existsSync(path.join(ROOT, href))).toBe(true));
    });
  });

  describe('Footer', () => {
    test('existe um <footer>', () => {
      expect(doc.querySelector('footer')).not.toBeNull();
    });

    test('footer tem texto de copyright com "Senac"', () => {
      expect(doc.querySelector('footer').textContent).toContain('Senac');
    });
  });

  describe('Scripts', () => {
    test('carrega JS do Bootstrap via CDN', () => {
      const scripts = Array.from(doc.querySelectorAll('script[src]'));
      expect(scripts.find(s => s.src.includes('bootstrap'))).toBeDefined();
    });
  });
});
