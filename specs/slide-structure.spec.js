/**
 * SPEC: Estrutura Obrigatória de Slides
 *
 * Regras aplicadas a todos os arquivos slide_*.html:
 *
 * 1. SLIDE DE TÍTULO (primeiro slide)
 *    - Deve ser o primeiro slide
 *    - Deve conter palavras-chave sobre a aula (elemento .slide-keywords com ao menos 1 .keyword,
 *      OU <meta name="keywords"> com conteúdo não vazio)
 *    - Deve conter a logo do Senac (img com alt contendo "senac" ou src do Cloudinary)
 *
 * 2. SLIDE DE AGENDA (segundo slide)
 *    - Deve ser o segundo slide
 *    - Deve conter a palavra "Agenda" no conteúdo (case-insensitive)
 *
 * 3. NAVEGAÇÃO
 *    - Deve ter botão/link de voltar para a home da disciplina
 *    - Deve ter botão/link para o material correspondente
 *
 */

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');

// Mapeamento de disciplinas para home pages
const DISCIPLINE_HOME_MAP = {
  qualidade: 'home_qualidade.html',
  qualidade2: 'home_qualidade_2026_2.html',
  logica: 'home_logica.html',
  tcc: 'home_tcc.html',
  tcc2: 'home_tcc2.html',
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function loadSlide(filePath) {
  const html = fs.readFileSync(filePath, 'utf-8');
  const dom = new JSDOM(html);
  return { doc: dom.window.document, html };
}

/**
 * Obtém o primeiro slide (título) dependendo do formato
 */
function getTitleSlide(doc) {
  // Reveal.js: primeira <section> dentro de .slides
  const revealSlides = doc.querySelector('.reveal .slides');
  if (revealSlides) {
    return revealSlides.querySelector('section');
  }
  // Legado: primeiro .slide ou .slide.active
  return doc.querySelector('.slide.active') || doc.querySelector('.slide');
}

/**
 * Obtém o segundo slide (agenda) dependendo do formato
 */
function getAgendaSlide(doc) {
  // Reveal.js
  const revealSlides = doc.querySelector('.reveal .slides');
  if (revealSlides) {
    const sections = revealSlides.querySelectorAll(':scope > section');
    return sections[1] || null;
  }
  // Legado: segundo elemento .slide
  const slides = doc.querySelectorAll('.slide');
  return slides[1] || null;
}

/**
 * Verifica se a logo do Senac está presente no slide de título.
 * Busca no slide de título primeiro; se não encontrar, busca no documento inteiro
 * (cobre layouts onde o logo fica em navbar/header fora do primeiro slide).
 */
function hasSenacLogo(titleSlide, doc) {
  const containers = titleSlide ? [titleSlide, doc] : [doc];
  for (const container of containers) {
    const imgs = Array.from(container.querySelectorAll('img'));
    const found = imgs.find(img => {
      const alt = (img.getAttribute('alt') || '').toLowerCase();
      const src = (img.getAttribute('src') || '').toLowerCase();
      return (
        alt.includes('senac') ||
        src.includes('cloudinary.com') ||
        src.includes('senac')
      );
    });
    if (found) return true;
  }
  return false;
}

/**
 * Verifica se existem keywords no slide de título
 * Aceita:
 *   - .slide-keywords contendo ao menos 1 .keyword (em qualquer container)
 *   - <meta name="keywords"> com conteúdo não vazio
 */
function hasKeywords(titleSlide, doc) {
  // Meta tag no <head>
  const meta = doc.querySelector('meta[name="keywords"]');
  if (meta && meta.getAttribute('content') && meta.getAttribute('content').trim() !== '') {
    return true;
  }

  // Elemento .slide-keywords no slide de título ou no documento
  const containers = titleSlide ? [titleSlide, doc] : [doc];
  for (const container of containers) {
    const keywordsEl = container.querySelector('.slide-keywords');
    if (keywordsEl && keywordsEl.querySelectorAll('.keyword').length > 0) return true;
  }

  return false;
}

/**
 * Verifica se o slide de agenda contém a palavra "Agenda"
 */
function hasAgendaContent(agendaSlide) {
  if (!agendaSlide) return false;
  return /agenda/i.test(agendaSlide.textContent);
}

/**
 * Verifica botão de voltar para home da disciplina.
 * Exige um <a href> real apontando para a home da disciplina — não aceita texto solto.
 * Falha explicitamente para disciplinas não mapeadas.
 */
function hasHomeButton(doc, html, discipline) {
  const homePage = DISCIPLINE_HOME_MAP[discipline];
  if (!homePage) {
    throw new Error(
      `Disciplina desconhecida: "${discipline}". Adicione-a em DISCIPLINE_HOME_MAP.`
    );
  }

  const links = Array.from(doc.querySelectorAll('a[href]'));
  return links.some(a => {
    const href = a.getAttribute('href') || '';
    return href.includes(`home_${discipline}`) || href.includes(homePage);
  });
}

/**
 * Verifica botão de ir para o material.
 * Exige um <a href> real apontando para um arquivo material_.
 * O href deve começar com "material_" ou conter "/material/material_".
 */
function hasMaterialButton(doc) {
  const links = Array.from(doc.querySelectorAll('a[href]'));
  return links.some(a => {
    const href = a.getAttribute('href') || '';
    return (
      /(?:^|\/)material_[^/]+\.html/.test(href) ||
      href.includes('/material/')
    );
  });
}

// ─────────────────────────────────────────────
// Coleta de arquivos
// ─────────────────────────────────────────────

// Files excluded from structure checks (legacy slides not subject to these rules)
const EXCLUDED_SLIDES = [
  'slide_algebrabooleanaeportaslogicas.html',
];

function collectSlideFiles(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      collectSlideFiles(fullPath, files);
    } else if (entry.isFile() && entry.name.startsWith('slide_') && entry.name.endsWith('.html')) {
      if (!EXCLUDED_SLIDES.includes(entry.name)) {
        files.push(fullPath);
      }
    }
  }
  return files;
}

const slideFiles = collectSlideFiles(path.join(ROOT, 'pages'));

// ─────────────────────────────────────────────
// TESTES
// ─────────────────────────────────────────────

describe('Estrutura Obrigatória dos Slides', () => {
  test(`Deve encontrar arquivos slide_ para testar (${slideFiles.length} encontrados)`, () => {
    expect(slideFiles.length).toBeGreaterThan(0);
  });

  describe.each(slideFiles)('%s', slidePath => {
    let doc, html, titleSlide, agendaSlide, discipline;

    beforeAll(() => {
      ({ doc, html } = loadSlide(slidePath));
      titleSlide = getTitleSlide(doc);
      agendaSlide = getAgendaSlide(doc);
      discipline = path.relative(path.join(ROOT, 'pages'), slidePath).split(path.sep)[0];
    });

    // ── 1. Slide de Título ──────────────────────────────────────

    describe('Slide de Título (1º slide)', () => {
      test('deve existir um primeiro slide (slide de título)', () => {
        expect(titleSlide).not.toBeNull();
      });

      test('deve conter a logo do Senac', () => {
        expect(hasSenacLogo(titleSlide, doc)).toBe(true);
      });

      test('deve conter palavras-chave da aula (.slide-keywords > .keyword ou <meta name="keywords">)', () => {
        expect(hasKeywords(titleSlide, doc)).toBe(true);
      });
    });

    // ── 2. Slide de Agenda ──────────────────────────────────────

    describe('Slide de Agenda (2º slide)', () => {
      test('deve existir um segundo slide (slide de agenda)', () => {
        expect(agendaSlide).not.toBeNull();
      });

      test('deve conter a palavra "Agenda" no conteúdo', () => {
        expect(hasAgendaContent(agendaSlide)).toBe(true);
      });
    });

    // ── 3. Navegação ────────────────────────────────────────────

    describe('Navegação', () => {
      test('IDs dos slides devem ser únicos e sequenciais para os controles', () => {
        const slides = [...doc.querySelectorAll('.slide')];
        expect(slides.map((slide) => slide.id)).toEqual(
          slides.map((_, index) => `slide-${index + 1}`)
        );
      });
      test('deve ter botão/link de voltar para a home da disciplina', () => {
        expect(hasHomeButton(doc, html, discipline)).toBe(true);
      });

      test('deve ter botão/link para o material da aula', () => {
        expect(hasMaterialButton(doc)).toBe(true);
      });
    });
  });
});
