const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

describe('Cards das Home Pages - Botões Slide e Material', () => {
  const rootDir = path.resolve(__dirname, '..');
  
  // Lista de home pages para testar
  const homePages = [
    'pages/home_qualidade.html',
    'pages/home_logica.html',
    'pages/home_tcc.html'
  ];

  /**
   * Verifica se uma home page tem o script que adiciona botões dinamicamente
   */
  function hasDynamicButtonScript(htmlContent) {
    // Verifica se existe o script que adiciona botões de slide/material
    return htmlContent.includes('materialMap') && 
           htmlContent.includes('Ver slide') && 
           htmlContent.includes('Ver material');
  }

  /**
   * Extrai todos os links de slides de uma home page
   */
  function extractSlideLinks(doc, htmlContent) {
    const slideLinks = [];
    
    // Links diretos para slides
    const links = doc.querySelectorAll('a[href*="slide_"]');
    for (const link of links) {
      slideLinks.push({
        href: link.getAttribute('href'),
        hasButtons: link.parentElement.querySelector('a.btn[href*="slide_"]') !== null,
        element: link
      });
    }
    
    return slideLinks;
  }

  /**
   * Verifica se um link de slide tem material correspondente no script
   */
  function hasMaterialForSlide(slideHref, htmlContent) {
    // Verifica o materialMap no script
    const materialMapMatch = htmlContent.match(/materialMap\s*=\s*\{([^}]+)\}/s);
    if (!materialMapMatch) return false;
    
    const mapContent = materialMapMatch[1];
    return mapContent.includes(slideHref);
  }

  /**
   * Lista de slides que não têm material correspondente (páginas especiais)
   */
  const slidesWithoutMaterial = [
    'qualidade/slide_projeto_descricao.html',
    'logica/slide_diretrizes-projeto-semestral.html'
  ];

  describe.each(homePages)('Home: %s', (homePage) => {
    const filePath = path.join(rootDir, homePage);
    
    if (!fs.existsSync(filePath)) {
      test(`Arquivo existe`, () => {
        throw new Error(`Arquivo não encontrado: ${homePage}`);
      });
      return;
    }
    
    const htmlContent = fs.readFileSync(filePath, 'utf-8');
    const dom = new JSDOM(htmlContent);
    const doc = dom.window.document;
    
    const hasDynamicScript = hasDynamicButtonScript(htmlContent);
    const slideLinks = extractSlideLinks(doc, htmlContent);
    
    test(`Deve ter script de botões dinâmicos ou botões estáticos`, () => {
      expect(hasDynamicScript).toBe(true);
    });

    test(`Deve ter links para slides (${slideLinks.length} encontrados)`, () => {
      expect(slideLinks.length).toBeGreaterThan(0);
    });

    describe.each(slideLinks)('Slide: %s', (slideLink) => {
      test(`Link "${slideLink.href}" deve ter material correspondente ou ser exceção`, () => {
        // Slides especiais sem material
        if (slidesWithoutMaterial.includes(slideLink.href)) {
          return; // Skip
        }
        
        // Aulas 14 e 15 de qualidade têm botões estáticos no HTML
        if (slideLink.href.includes('aula14') || slideLink.href.includes('aula15')) {
          return; // Skip
        }
        
        const hasMaterial = hasMaterialForSlide(slideLink.href, htmlContent);
        
        if (!hasMaterial) {
          throw new Error(
            `Slide "${slideLink.href}" não tem entrada no materialMap!\n` +
            `Adicione o mapeamento para o material correspondente.`
          );
        }
        
        expect(hasMaterial).toBe(true);
      });
    });
  });
});
