const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');

function loadHTML(filePath) {
  const html = fs.readFileSync(path.join(ROOT, filePath), 'utf-8');
  const dom = new JSDOM(html);
  return dom.window.document;
}

describe('index.html', () => {
  let doc;

  beforeAll(() => {
    doc = loadHTML('index.html');
  });

  // --- HEAD ---
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
      const meta = doc.querySelector('meta[name="viewport"]');
      expect(meta).not.toBeNull();
    });

    test('<title> contém "Hub de Aulas"', () => {
      expect(doc.title).toContain('Hub de Aulas');
    });

    test('carrega CSS do Bootstrap via CDN', () => {
      const links = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      const bootstrap = links.find(l => l.href.includes('bootstrap'));
      expect(bootstrap).toBeDefined();
    });

    test('carrega o CSS customizado (css/style.css)', () => {
      const links = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      const custom = links.find(l => l.getAttribute('href') === 'css/style.css');
      expect(custom).toBeDefined();
    });
  });

  // --- NAVBAR ---
  describe('Navbar', () => {
    test('existe uma <nav> com classe navbar', () => {
      const nav = doc.querySelector('nav.navbar');
      expect(nav).not.toBeNull();
    });

    test('navbar tem logo do Senac com alt text', () => {
      const nav = doc.querySelector('nav.navbar');
      const img = nav.querySelector('img');
      expect(img).not.toBeNull();
      expect(img.alt.toLowerCase()).toContain('senac');
    });

    test('navbar tem link para a página do Professor', () => {
      const nav = doc.querySelector('nav.navbar');
      const links = Array.from(nav.querySelectorAll('a'));
      const professor = links.find(l => l.getAttribute('href') === 'pages/professor.html');
      expect(professor).toBeDefined();
    });
  });

  // --- SEÇÃO DISCIPLINAS ---
  describe('Seção #disciplinas', () => {
    test('existe a seção com id "disciplinas"', () => {
      const section = doc.querySelector('#disciplinas');
      expect(section).not.toBeNull();
    });

    test('tem exatamente 4 cards de disciplinas', () => {
      const cards = doc.querySelectorAll('#disciplinas .card');
      expect(cards.length).toBe(4);
    });

    test('card de Qualidade tem link para pages/qualidade-software.html', () => {
      const links = Array.from(doc.querySelectorAll('#disciplinas a'));
      const link = links.find(l => l.getAttribute('href') === 'pages/qualidade-software.html');
      expect(link).toBeDefined();
    });

    test('card de Lógica tem link para pages/introducao-logica.html', () => {
      const links = Array.from(doc.querySelectorAll('#disciplinas a'));
      const link = links.find(l => l.getAttribute('href') === 'pages/introducao-logica.html');
      expect(link).toBeDefined();
    });

    test('card de TCC tem link para pages/tcc.html', () => {
      const links = Array.from(doc.querySelectorAll('#disciplinas a'));
      const link = links.find(l => l.getAttribute('href') === 'pages/tcc.html');
      expect(link).toBeDefined();
    });

    test('card do Professor tem link para pages/professor.html', () => {
      const links = Array.from(doc.querySelectorAll('#disciplinas a'));
      const link = links.find(l => l.getAttribute('href') === 'pages/professor.html');
      expect(link).toBeDefined();
    });

    test('todos os links de "Acessar" apontam para arquivos que existem', () => {
      const links = Array.from(doc.querySelectorAll('#disciplinas a[href]'));
      links.forEach(link => {
        const href = link.getAttribute('href');
        const filePath = path.join(ROOT, href);
        expect(fs.existsSync(filePath)).toBe(true);
      });
    });
  });

  // --- FOOTER ---
  describe('Footer', () => {
    test('existe um <footer>', () => {
      const footer = doc.querySelector('footer');
      expect(footer).not.toBeNull();
    });

    test('footer tem logo do Senac', () => {
      const footer = doc.querySelector('footer');
      const img = footer.querySelector('img');
      expect(img).not.toBeNull();
    });

    test('footer tem texto de copyright com "Senac"', () => {
      const footer = doc.querySelector('footer');
      expect(footer.textContent).toContain('Senac');
    });
  });

  // --- SCRIPTS ---
  describe('Scripts', () => {
    test('carrega JS do Bootstrap via CDN', () => {
      const scripts = Array.from(doc.querySelectorAll('script[src]'));
      const bootstrap = scripts.find(s => s.src.includes('bootstrap'));
      expect(bootstrap).toBeDefined();
    });
  });
});
