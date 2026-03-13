const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

describe('Verificação do Logo do Senac', () => {
  const rootDir = path.resolve(__dirname, '..');
  
  // URLs válidas do logo do Senac
  const validLogoUrls = [
    'https://res.cloudinary.com/dyhjjms8y/image/upload/v1759512534/logo-SENAC_k3d68v.png',
    'https://www.senac.br/sites/all/themes/senac_theme/img/senac-logo.svg',
    'https://www.senac.br/sites/all/themes/senac_theme/img/senac-logo.png',
  ];

  /**
   * Obtém todos os arquivos HTML do projeto (exceto node_modules)
   */
  function getAllHtmlFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    
    for (const file of files) {
      const filePath = path.join(dir, file);
      
      if (file === 'node_modules' || file.startsWith('.')) {
        continue;
      }
      
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        getAllHtmlFiles(filePath, fileList);
      } else if (file.endsWith('.html')) {
        fileList.push(filePath);
      }
    }
    
    return fileList;
  }

  /**
   * Verifica se uma imagem é o logo do Senac
   */
  function isSenacLogo(imgSrc) {
    if (!imgSrc) return false;
    
    // Verifica URLs do logo
    if (validLogoUrls.some(url => imgSrc.includes(url))) {
      return true;
    }
    
    // Verifica se o src contém 'senac' ou 'logo'
    if (imgSrc.toLowerCase().includes('senac') && imgSrc.toLowerCase().includes('logo')) {
      return true;
    }
    
    // Verifica se é um caminho relativo para logo
    if (imgSrc.includes('logo') && imgSrc.toLowerCase().includes('senac')) {
      return true;
    }
    
    return false;
  }

  /**
   * Encontra o logo do Senac em um documento
   */
  function findSenacLogo(dom) {
    const images = dom.window.document.querySelectorAll('img');
    
    for (const img of images) {
      const src = img.getAttribute('src');
      const alt = img.getAttribute('alt');
      
      // Verifica pelo src
      if (isSenacLogo(src)) {
        return { img, src, alt };
      }
      
      // Verifica pelo alt text
      if (alt && alt.toLowerCase().includes('senac')) {
        return { img, src, alt };
      }
    }
    
    return null;
  }

  const htmlFiles = getAllHtmlFiles(rootDir);

  test('Deve encontrar arquivos HTML para testar', () => {
    expect(htmlFiles.length).toBeGreaterThan(0);
  });

  describe.each(htmlFiles)('Página: %s', (filePath) => {
    const relativePath = path.relative(rootDir, filePath);
    const htmlContent = fs.readFileSync(filePath, 'utf-8');
    const dom = new JSDOM(htmlContent);

    test('Deve ter o logo do Senac', () => {
      const logo = findSenacLogo(dom);
      
      if (!logo) {
        throw new Error(
          `❌ ${relativePath} não tem o logo do Senac!\n` +
          `Adicione uma tag <img> com o logo do Senac.`
        );
      }
      
      expect(logo).toBeDefined();
      expect(logo.src).toBeDefined();
    });

    test('Logo deve ter alt descritivo', () => {
      const logo = findSenacLogo(dom);
      
      if (!logo) {
        // Se não tem logo, o teste anterior já falhou
        return;
      }
      
      expect(logo.alt).toBeDefined();
      expect(logo.alt.toLowerCase()).toContain('senac');
    });
  });
});
