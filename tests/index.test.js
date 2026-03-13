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

  describe('HEAD', () => {
    test('tem <html lang="pt-br">', () => {
      const lang = doc.documentElement.lang;

      expect(lang).toBe('pt-br');
    });

    test('tem <meta charset="UTF-8">', () => {
      const meta = doc.querySelector('meta[charset]');
      const charset = meta?.getAttribute('charset').toUpperCase();

      expect(meta).not.toBeNull();
      expect(charset).toBe('UTF-8');
    });

    test('tem <meta name="viewport">', () => {
      const meta = doc.querySelector('meta[name="viewport"]');

      expect(meta).not.toBeNull();
    });

    test('<title> contém "Hub de Aulas"', () => {
      const title = doc.title;

      expect(title).toContain('Hub de Aulas');
    });

    test('carrega CSS do Bootstrap via CDN', () => {
      const stylesheets = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      const bootstrapCSS = stylesheets.find(l => l.href.includes('bootstrap'));

      expect(bootstrapCSS).toBeDefined();
    });

    test('carrega o CSS customizado (css/style.css)', () => {
      const stylesheets = Array.from(doc.querySelectorAll('link[rel="stylesheet"]'));
      const customCSS = stylesheets.find(l => l.getAttribute('href') === 'css/style.css');

      expect(customCSS).toBeDefined();
    });
  });

  describe('Navbar', () => {
    test('existe uma <nav> com classe navbar', () => {
      const navbar = doc.querySelector('nav.navbar');

      expect(navbar).not.toBeNull();
    });

    test('navbar tem logo do Senac com alt text', () => {
      const navbar = doc.querySelector('nav.navbar');
      const logo = navbar.querySelector('img');
      const alt = logo?.alt.toLowerCase();

      expect(logo).not.toBeNull();
      expect(alt).toContain('senac');
    });

    test('navbar tem link para a página do Professor', () => {
      const navLinks = Array.from(doc.querySelectorAll('nav.navbar a'));
      const professorLink = navLinks.find(l => l.getAttribute('href') === 'pages/professor.html');

      expect(professorLink).toBeDefined();
    });
  });

  describe('Seção #disciplinas', () => {
    test('existe a seção com id "disciplinas"', () => {
      const section = doc.querySelector('#disciplinas');

      expect(section).not.toBeNull();
    });

    test('tem exatamente 4 cards de disciplinas', () => {
      const cards = doc.querySelectorAll('#disciplinas .card');

      expect(cards.length).toBe(4);
    });

    test('card de Qualidade tem link para pages/home_qualidade.html', () => {
      const disciplinaLinks = Array.from(doc.querySelectorAll('#disciplinas a'));
      const qualidadeLink = disciplinaLinks.find(l => l.getAttribute('href') === 'pages/home_qualidade.html');

      expect(qualidadeLink).toBeDefined();
    });

    test('card de Lógica tem link para pages/home_logica.html', () => {
      const disciplinaLinks = Array.from(doc.querySelectorAll('#disciplinas a'));
      const logicaLink = disciplinaLinks.find(l => l.getAttribute('href') === 'pages/home_logica.html');

      expect(logicaLink).toBeDefined();
    });

    test('card de TCC tem link para pages/home_tcc.html', () => {
      const disciplinaLinks = Array.from(doc.querySelectorAll('#disciplinas a'));
      const tccLink = disciplinaLinks.find(l => l.getAttribute('href') === 'pages/home_tcc.html');

      expect(tccLink).toBeDefined();
    });

    test('card do Professor tem link para pages/professor.html', () => {
      const disciplinaLinks = Array.from(doc.querySelectorAll('#disciplinas a'));
      const professorLink = disciplinaLinks.find(l => l.getAttribute('href') === 'pages/professor.html');

      expect(professorLink).toBeDefined();
    });

    test('todos os links de "Acessar" apontam para arquivos que existem no disco', () => {
      const disciplinaLinks = Array.from(doc.querySelectorAll('#disciplinas a[href]'));
      const hrefs = disciplinaLinks.map(l => l.getAttribute('href'));
      const filePaths = hrefs.map(href => path.join(ROOT, href));

      filePaths.forEach(filePath => expect(fs.existsSync(filePath)).toBe(true));
    });
  });

  describe('Footer', () => {
    test('existe um <footer>', () => {
      const footer = doc.querySelector('footer');

      expect(footer).not.toBeNull();
    });

    test('footer tem logo do Senac', () => {
      const footer = doc.querySelector('footer');
      const logo = footer.querySelector('img');

      expect(logo).not.toBeNull();
    });

    test('footer tem texto de copyright com "Senac"', () => {
      const footer = doc.querySelector('footer');
      const footerText = footer.textContent;

      expect(footerText).toContain('Senac');
    });
  });

  describe('Scripts', () => {
    test('carrega JS do Bootstrap via CDN', () => {
      const scripts = Array.from(doc.querySelectorAll('script[src]'));
      const bootstrapJS = scripts.find(s => s.src.includes('bootstrap'));

      expect(bootstrapJS).toBeDefined();
    });
  });
});
