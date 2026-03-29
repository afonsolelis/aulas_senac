const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const PAGES_ROOT = path.join(ROOT, 'pages');

const EXCLUDED_SLIDES = new Set([
  'logica/slide_diretrizes-projeto-semestral.html',
  'qualidade/slide_projeto_descricao.html',
]);

function collectSlideFiles(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      collectSlideFiles(fullPath, files);
    } else if (entry.isFile() && entry.name.startsWith('slide_') && entry.name.endsWith('.html')) {
      const relative = path.relative(PAGES_ROOT, fullPath);
      if (!EXCLUDED_SLIDES.has(relative)) {
        files.push(fullPath);
      }
    }
  }
  return files;
}

const slideFiles = collectSlideFiles(PAGES_ROOT);

describe('Footer padrão consolidado (estilo Lógica)', () => {
  describe.each(slideFiles)('%s', slidePath => {
    let doc;
    let relativePath;

    beforeAll(() => {
      const html = fs.readFileSync(slidePath, 'utf-8');
      doc = new JSDOM(html).window.document;
      relativePath = path.relative(PAGES_ROOT, slidePath);
    });

    test('deve usar .slide-controls como grupo esquerdo', () => {
      expect(doc.querySelector('footer.slide-footer > .slide-controls')).not.toBeNull();
    });

    test('deve manter o contador dentro de .slide-controls', () => {
      const controls = doc.querySelector('footer.slide-footer > .slide-controls');
      const counter = controls?.querySelector('#slideCounter');
      expect(counter).not.toBeNull();
    });

    test('deve ter botão de material como link direto do footer', () => {
      const directLinks = Array.from(doc.querySelectorAll('footer.slide-footer > a[href]'));
      const materialLink = directLinks.find(link =>
        (link.getAttribute('href') || '').includes('material/')
      );
      expect(materialLink).not.toBeNull();
      expect(materialLink.textContent).toContain('Ver material escrito');
    });

    test('deve ter logo do Senac como link direto e separado no footer', () => {
      const directLinks = Array.from(doc.querySelectorAll('footer.slide-footer > a[href]'));
      const logoLink = directLinks.find(link => link.querySelector('img[alt*="Senac"], img[alt*="senac"]'));
      expect(logoLink).not.toBeNull();
    });

    test('deve ter exatamente quatro filhos diretos no footer', () => {
      const children = Array.from(doc.querySelectorAll('footer.slide-footer > *'));
      expect(children).toHaveLength(4);
    });
  });
});
