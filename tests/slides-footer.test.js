const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

describe('Footer dos Slides - Elementos Obrigatórios', () => {
  const rootDir = path.resolve(__dirname, '..');
  
  // Mapeamento de disciplinas para suas home pages
  const disciplineHomeMap = {
    'qualidade': 'home_qualidade.html',
    'logica': 'home_logica.html',
    'tcc': 'home_tcc.html'
  };

  /**
   * Obtém todos os arquivos slide_ do projeto
   */
  function getAllSlideFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    
    for (const file of files) {
      const filePath = path.join(dir, file);
      
      if (file === 'node_modules' || file.startsWith('.')) {
        continue;
      }
      
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        getAllSlideFiles(filePath, fileList);
      } else if (file.startsWith('slide_') && file.endsWith('.html')) {
        fileList.push(filePath);
      }
    }
    
    return fileList;
  }

  /**
   * Verifica elementos obrigatórios no footer
   */
  function checkFooterElements(doc, htmlContent, slidePath) {
    const issues = [];
    
    // Slides especiais (páginas únicas sem navegação completa)
    const relativePath = path.relative(rootDir, slidePath);
    const isSinglePageSlide = relativePath.includes('projeto_descricao') || 
                               relativePath.includes('diretrizes-projeto-semestral');
    
    // 1. Verifica contador de slides (ex: "Slide 1 de 10" ou "1/10" ou slideCounter)
    const hasSlideCounter = 
      htmlContent.includes('slideCounter') ||
      htmlContent.includes('Slide') && htmlContent.includes('de') ||
      htmlContent.match(/\d+\s*\/\s*\d+/) ||
      doc.querySelector('[id*="slide-counter"]') ||
      doc.querySelector('.slide-counter') ||
      doc.querySelector('.page-counter');
    
    if (!hasSlideCounter) {
      issues.push('❌ Contador de slides (ex: "Slide 1 de 10")');
    }
    
    // 2. Verifica botão de slide anterior (prevBtn, prevSlide, setSlide-- etc)
    const hasPrevButton =
      doc.querySelector('#prevBtn') ||
      doc.querySelector('[onclick*="prevSlide"]') ||
      doc.querySelector('[onclick*="slide--"]') ||
      doc.querySelector('[onclick*="prev"]') ||
      doc.querySelector('.btn-prev') ||
      doc.querySelector('button[id*="prev"]') ||
      htmlContent.includes('prevBtn') ||
      htmlContent.includes('prevSlide') ||
      htmlContent.includes('slide--');

    if (!hasPrevButton && !isSinglePageSlide) {
      issues.push('❌ Botão "Slide Anterior"');
    }

    // 3. Verifica botão de próximo slide (nextBtn, nextSlide, setSlide++ etc)
    const hasNextButton =
      doc.querySelector('#nextBtn') ||
      doc.querySelector('[onclick*="nextSlide"]') ||
      doc.querySelector('[onclick*="slide++"]') ||
      doc.querySelector('[onclick*="next"]') ||
      doc.querySelector('.btn-next') ||
      doc.querySelector('button[id*="next"]') ||
      htmlContent.includes('nextBtn') ||
      htmlContent.includes('nextSlide') ||
      htmlContent.includes('slide++');

    if (!hasNextButton && !isSinglePageSlide) {
      issues.push('❌ Botão "Próximo Slide"');
    }

    // 4. Verifica botão de tela cheia
    const hasFullscreenButton =
      doc.querySelector('#fullscreenBtn') ||
      doc.querySelector('[onclick*="fullscreen"]') ||
      doc.querySelector('[onclick*="toggleFullScreen"]') ||
      doc.querySelector('.btn-fullscreen') ||
      doc.querySelector('button[onclick*="screen"]') ||
      htmlContent.includes('fullscreenBtn') ||
      htmlContent.includes('fullscreen') ||
      htmlContent.includes('toggleFullScreen');

    if (!hasFullscreenButton && !isSinglePageSlide) {
      issues.push('❌ Botão "Tela Cheia"');
    }

    // 5. Verifica botão para ir ao material
    const hasMaterialButton =
      doc.querySelector('a[href*="material"]') ||
      doc.querySelector('a[href*="/material/"]') ||
      htmlContent.includes('Ver material') ||
      htmlContent.includes('Ir para material') ||
      htmlContent.includes('material_');

    if (!hasMaterialButton && !isSinglePageSlide) {
      issues.push('❌ Botão "Ir para Material"');
    }
    
    // 6. Verifica botão/link de voltar para home da disciplina
    const discipline = relativePath.split(path.sep)[1]; // qualidade, logica, ou tcc
    const homePage = disciplineHomeMap[discipline];
    
    const hasHomeButton = 
      doc.querySelector(`a[href="../${homePage}"]`) ||
      doc.querySelector(`a[href*="${homePage}"]`) ||
      doc.querySelector(`a[href*="home_${discipline}"]`) ||
      doc.querySelector('.btn-home') ||
      doc.querySelector('[onclick*="home"]') ||
      htmlContent.includes(`../${homePage}`) ||
      htmlContent.includes(`home_${discipline}`) ||
      htmlContent.includes('Voltar para') ||
      (htmlContent.includes('Voltar') && htmlContent.includes('home'));
    
    if (!hasHomeButton) {
      issues.push(`❌ Botão "Voltar para Home" (${homePage})`);
    }
    
    return issues;
  }

  const slideFiles = getAllSlideFiles(rootDir);

  test(`Deve encontrar arquivos de slides (${slideFiles.length} encontrados)`, () => {
    expect(slideFiles.length).toBeGreaterThan(0);
  });

  describe.each(slideFiles)('Slide: %s', (slidePath) => {
    const relativePath = path.relative(rootDir, slidePath);
    
    if (!fs.existsSync(slidePath)) {
      test(`Arquivo existe`, () => {
        throw new Error(`Arquivo não encontrado: ${relativePath}`);
      });
      return;
    }
    
    const htmlContent = fs.readFileSync(slidePath, 'utf-8');
    const dom = new JSDOM(htmlContent);
    const doc = dom.window.document;
    
    test('Deve ter footer com todos os elementos obrigatórios', () => {
      const issues = checkFooterElements(doc, htmlContent, slidePath);
      
      if (issues.length > 0) {
        throw new Error(
          `Slide "${relativePath}" está sem elementos no footer:\n` +
          issues.join('\n')
        );
      }
      
      expect(issues.length).toBe(0);
    });
  });
});
