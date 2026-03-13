const fs = require('fs');
const path = require('path');

describe('Verificação de Links Internos', () => {
  const rootDir = path.resolve(__dirname, '..');
  
  /**
   * Obtém todos os arquivos HTML do projeto
   */
  function getAllHtmlFiles(dir, fileList = []) {
    const files = fs.readdirSync(dir);
    
    for (const file of files) {
      const filePath = path.join(dir, file);
      
      // Pula node_modules e diretórios ocultos
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
   * Extrai todos os links href de um arquivo HTML
   */
  function extractLinks(htmlContent) {
    const linkRegex = /href=["']([^"']+)["']/gi;
    const links = [];
    let match;
    
    while ((match = linkRegex.exec(htmlContent)) !== null) {
      links.push(match[1]);
    }
    
    return links;
  }

  /**
   * Verifica se um link interno existe
   */
  function linkExists(link, baseFile) {
    // Ignora links externos, âncoras, mailto, javascript
    if (link.startsWith('http') || 
        link.startsWith('mailto:') || 
        link.startsWith('javascript:') ||
        link.startsWith('#') ||
        link === '') {
      return true;
    }

    const baseDir = path.dirname(baseFile);
    const resolvedPath = path.resolve(baseDir, link);
    
    return fs.existsSync(resolvedPath);
  }

  const htmlFiles = getAllHtmlFiles(rootDir);

  test('Deve encontrar arquivos HTML', () => {
    expect(htmlFiles.length).toBeGreaterThan(0);
  });

  describe.each(htmlFiles)('Arquivo: %s', (filePath) => {
    const relativePath = path.relative(rootDir, filePath);
    const htmlContent = fs.readFileSync(filePath, 'utf-8');
    const links = extractLinks(htmlContent);

    if (links.length > 0) {
      test.each(links)('Link "%s" deve existir', (link) => {
        const exists = linkExists(link, filePath);
        
        if (!exists) {
          const baseDir = path.dirname(filePath);
          const resolvedPath = path.resolve(baseDir, link);
          const relativeTarget = path.relative(rootDir, resolvedPath);
          
          throw new Error(
            `Link quebrado em ${relativePath}: "${link}"\n` +
            `Caminho resolvido: ${relativeTarget}`
          );
        }
        
        expect(exists).toBe(true);
      });
    } else {
      test('Não possui links para verificar', () => {
        expect(true).toBe(true);
      });
    }
  });
});
