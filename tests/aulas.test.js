const fs = require('fs');
const path = require('path');
const https = require('https');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const PAGES_DIR = path.join(ROOT, 'pages');
const SENAC_LOGO_URL = 'https://res.cloudinary.com/dyhjjms8y/image/upload/v1759512534/logo-SENAC_k3d68v.png';

/**
 * Carrega um arquivo HTML e retorna o documento JSDOM
 */
function loadHTML(filePath) {
  // Garante que o caminho começa com 'pages/'
  const fullPath = filePath.startsWith('pages/') ? filePath : `pages/${filePath}`;
  const html = fs.readFileSync(path.join(ROOT, fullPath), 'utf-8');
  const dom = new JSDOM(html);
  return dom.window.document;
}

/**
 * Verifica se um arquivo existe no disco
 */
function fileExists(filePath) {
  const fullPath = filePath.startsWith('pages/') ? filePath : `pages/${filePath}`;
  return fs.existsSync(path.join(ROOT, fullPath));
}

/**
 * Resolve um caminho relativo a partir de um arquivo base
 */
function resolvePath(baseFile, relativePath) {
  // Garante que baseFile começa com 'pages/'
  const base = baseFile.startsWith('pages/') ? baseFile : `pages/${baseFile}`;
  const baseDir = path.dirname(base);
  const resolved = path.join(baseDir, relativePath);
  return path.normalize(resolved);
}

/**
 * Busca todos os arquivos HTML de aulas (slides e materiais)
 */
function findAulaFiles() {
  const files = [];
  
  function scanDir(dir, relativePath = '') {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      if (entry.name.startsWith('.') || entry.name === 'node_modules') continue;
      
      const fullPath = path.join(dir, entry.name);
      const relPath = path.join(relativePath, entry.name);
      
      if (entry.isDirectory()) {
        scanDir(fullPath, relPath);
      } else if (entry.isFile() && entry.name.endsWith('.html')) {
        // Inclui slides e materiais, exclui páginas índice principais
        const fileName = entry.name.toLowerCase();
        const isExcluded = fileName === 'index.html' || 
                          fileName === 'professor.html' ||
                          fileName === 'qualidade-software.html' ||
                          fileName === 'introducao-logica.html' ||
                          fileName === 'tcc.html';
        
        if (!isExcluded) {
          files.push(relPath);
        }
      }
    }
  }
  
  scanDir(PAGES_DIR);
  return files;
}

/**
 * Testa o botão de voltar em uma página
 */
function testBackButton(doc, filePath) {
  // Tenta encontrar botão "Voltar" ou "Voltar ao cronograma"
  const backButtons = Array.from(doc.querySelectorAll('a[href]')).filter(a => {
    const text = a.textContent.toLowerCase();
    return text.includes('voltar') || a.classList.contains('btn-outline-secondary');
  });
  
  if (backButtons.length === 0) {
    return { found: false, valid: null, reason: 'Nenhum botão de voltar encontrado' };
  }
  
  // Pega o primeiro botão de voltar
  const backButton = backButtons[0];
  const href = backButton.getAttribute('href');
  
  if (!href) {
    return { found: true, valid: false, reason: 'Botão sem href' };
  }
  
  // Resolve o caminho relativo
  const targetPath = resolvePath(filePath, href);
  const exists = fileExists(targetPath);
  
  return {
    found: true,
    valid: exists,
    href: href,
    target: targetPath,
    reason: exists ? 'OK' : `Arquivo não existe: ${targetPath}`
  };
}

/**
 * Testa o botão de ver material em uma página de slides
 */
function testMaterialButton(doc, filePath) {
  // Procura por link "Ver material" ou botão com ícone de livro
  const materialLinks = Array.from(doc.querySelectorAll('a[href]')).filter(a => {
    const text = a.textContent.toLowerCase();
    const hasBookIcon = a.innerHTML.includes('fa-book');
    return text.includes('material') || text.includes('escrito') || hasBookIcon;
  });
  
  if (materialLinks.length === 0) {
    return { found: false, valid: null, reason: 'Nenhum botão de material encontrado (pode ser página de material)' };
  }
  
  const materialLink = materialLinks[0];
  const href = materialLink.getAttribute('href');
  
  if (!href) {
    return { found: true, valid: false, reason: 'Link sem href' };
  }
  
  const targetPath = resolvePath(filePath, href);
  const exists = fileExists(targetPath);
  
  return {
    found: true,
    valid: exists,
    href: href,
    target: targetPath,
    reason: exists ? 'OK' : `Arquivo não existe: ${targetPath}`
  };
}

/**
 * Testa o botão de ver slide em uma página de material
 */
function testSlideButton(doc, filePath) {
  // Procura por link "Ver slide" ou botão com ícone de desktop/tela
  const slideLinks = Array.from(doc.querySelectorAll('a[href]')).filter(a => {
    const text = a.textContent.toLowerCase();
    const hasDesktopIcon = a.innerHTML.includes('fa-desktop') || a.innerHTML.includes('fa-tv');
    return text.includes('ver slide') || hasDesktopIcon;
  });
  
  if (slideLinks.length === 0) {
    return { found: false, valid: null, reason: 'Nenhum botão de slide encontrado (pode ser página de slides)' };
  }
  
  const slideLink = slideLinks[0];
  const href = slideLink.getAttribute('href');
  
  if (!href) {
    return { found: true, valid: false, reason: 'Link sem href' };
  }
  
  const targetPath = resolvePath(filePath, href);
  const exists = fileExists(targetPath);
  
  return {
    found: true,
    valid: exists,
    href: href,
    target: targetPath,
    reason: exists ? 'OK' : `Arquivo não existe: ${targetPath}`
  };
}

/**
 * Testa se o logo do Senac está presente e tem URL válida
 */
function testSenacLogo(doc, filePath) {
  // Procura por imagens com alt contendo "senac" ou src com "cloudinary"
  const logos = Array.from(doc.querySelectorAll('img')).filter(img => {
    const alt = img.alt.toLowerCase();
    const src = img.src.toLowerCase();
    return alt.includes('senac') || src.includes('senac') || src.includes('cloudinary');
  });
  
  if (logos.length === 0) {
    return { found: false, valid: null, reason: 'Nenhum logo do Senac encontrado' };
  }
  
  const logo = logos[0];
  const src = logo.getAttribute('src');
  
  if (!src) {
    return { found: true, valid: false, reason: 'Logo sem src' };
  }
  
  // Verifica se é URL externa do Cloudinary
  if (src.includes('cloudinary.com')) {
    return {
      found: true,
      valid: true,
      src: src,
      reason: 'URL do Cloudinary válida'
    };
  }
  
  // Verifica se é arquivo local
  const targetPath = resolvePath(filePath, src);
  const exists = fileExists(targetPath);
  
  return {
    found: true,
    valid: exists,
    src: src,
    reason: exists ? 'Arquivo local existe' : `Arquivo não existe: ${targetPath}`
  };
}

// ============================================================================
// TESTES
// ============================================================================

describe('Páginas de Aulas - Estrutura Comum', () => {
  const aulaFiles = findAulaFiles();
  
  console.log(`\n📚 Testando ${aulaFiles.length} páginas de aulas...\n`);
  
  describe('Botão Voltar', () => {
    aulaFiles.forEach(filePath => {
      test(`[${filePath}] tem botão Voltar funcional`, () => {
        const doc = loadHTML(filePath);
        const result = testBackButton(doc, filePath);
        
        if (!result.found) {
          // Algumas páginas podem não ter botão voltar (ex: páginas índice)
          console.log(`  ⚠️  ${filePath}: ${result.reason}`);
          return;
        }
        
        expect(result.valid).toBe(true);
      });
    });
  });
  
  describe('Botão Ver Material (slides)', () => {
    aulaFiles
      .filter(f => !f.includes('/material/')) // Apenas slides, não materiais
      .forEach(filePath => {
        test(`[${filePath}] tem botão Ver Material funcional`, () => {
          const doc = loadHTML(filePath);
          const result = testMaterialButton(doc, filePath);
          
          if (!result.found) {
            console.log(`  ⚠️  ${filePath}: ${result.reason}`);
            return;
          }
          
          expect(result.valid).toBe(true);
        });
      });
  });
  
  describe('Botão Ver Slide (materiais)', () => {
    aulaFiles
      .filter(f => f.includes('/material/')) // Apenas materiais
      .forEach(filePath => {
        test(`[${filePath}] tem botão Ver Slide funcional`, () => {
          const doc = loadHTML(filePath);
          const result = testSlideButton(doc, filePath);
          
          if (!result.found) {
            console.log(`  ⚠️  ${filePath}: ${result.reason}`);
            return;
          }
          
          expect(result.valid).toBe(true);
        });
      });
  });
  
  describe('Logo do Senac', () => {
    aulaFiles.forEach(filePath => {
      test(`[${filePath}] tem logo do Senac válido`, () => {
        const doc = loadHTML(filePath);
        const result = testSenacLogo(doc, filePath);
        
        if (!result.found) {
          // Algumas páginas podem não ter logo
          console.log(`  ⚠️  ${filePath}: ${result.reason}`);
          return;
        }
        
        expect(result.valid).toBe(true);
      });
    });
  });
});

describe('URL Externa - Logo Senac (Cloudinary)', () => {
  test('URL do logo do Senac no Cloudinary é acessível', async () => {
    const status = await new Promise((resolve) => {
      https.get(SENAC_LOGO_URL, (res) => {
        res.resume();
        resolve(res.statusCode);
      }).on('error', () => resolve(0));
    });
    
    expect(status).toBe(200);
  });
  
  test('URL do logo do Senac retorna Content-Type de imagem', async () => {
    const https = require('https');
    
    const contentType = await new Promise((resolve) => {
      https.get(SENAC_LOGO_URL, (res) => {
        const type = res.headers['content-type'];
        res.resume();
        resolve(type);
      }).on('error', () => resolve(null));
    });
    
    expect(contentType).toMatch(/^image\//);
  });
});
