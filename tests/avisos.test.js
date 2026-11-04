const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

/**
 * Quadro de avisos — invariantes do widget global.
 *
 * O botão flutuante existe porque TODA página carrega js/avisos.js. Uma página
 * nova sem a tag simplesmente não teria o quadro, sem erro nenhum em tempo de
 * execução — por isso a garantia mora aqui.
 */
describe('Quadro de avisos', () => {
  const rootDir = path.resolve(__dirname, '..');

  function getAllHtmlFiles(dir, fileList = []) {
    for (const file of fs.readdirSync(dir)) {
      if (file === 'node_modules' || file.startsWith('.')) continue;
      const filePath = path.join(dir, file);
      if (fs.statSync(filePath).isDirectory()) getAllHtmlFiles(filePath, fileList);
      else if (file.endsWith('.html')) fileList.push(filePath);
    }
    return fileList;
  }

  const htmlFiles = getAllHtmlFiles(rootDir);
  const TAG = /<script src="([^"]*js\/avisos\.js)"[^>]*><\/script>/;

  test('Deve encontrar arquivos HTML para testar', () => {
    expect(htmlFiles.length).toBeGreaterThan(0);
  });

  describe.each(htmlFiles)('Página: %s', (filePath) => {
    const relativePath = path.relative(rootDir, filePath);
    const html = fs.readFileSync(filePath, 'utf-8');

    test('Deve carregar js/avisos.js', () => {
      if (!TAG.test(html)) {
        throw new Error(
          `❌ ${relativePath} não carrega o quadro de avisos!\n` +
          `Adicione <script src="<caminho>/js/avisos.js" defer></script> antes de </body>.`
        );
      }
    });

    test('O caminho até js/avisos.js deve resolver no disco', () => {
      const match = html.match(TAG);
      if (!match) return; // o teste anterior já falhou
      const alvo = path.resolve(path.dirname(filePath), match[1]);
      expect(fs.existsSync(alvo)).toBe(true);
    });
  });

  describe('Credenciais', () => {
    const widget = fs.readFileSync(path.join(rootDir, 'js', 'avisos.js'), 'utf-8');

    test('A senha do professor não pode viver no JavaScript público', () => {
      // Quem confere a senha é avisos_login, no Postgres. Qualquer comparação
      // de senha no cliente seria contornável pelo DevTools de qualquer aluno.
      expect(widget).toMatch(/avisos_login/);
      expect(widget).not.toMatch(/senha\s*(===|==)\s*['"]/);
      expect(widget).not.toMatch(/\bsenha\s*:\s*['"][^'"]+['"]/);
    });

    test('O seed da conta não pode versionar a senha real', () => {
      const seed = fs.readFileSync(
        path.join(rootDir, 'supabase', 'avisos-admin.sql'), 'utf-8');
      expect(seed).toMatch(/SENHA-AQUI/);
    });
  });

  describe('Indicador global da semana', () => {
    test('aparece mesmo quando a página desativa o quadro de avisos', () => {
      const dom = new JSDOM(
        '<!doctype html><html><head></head><body data-sem-avisos>' +
        '<script src="http://localhost/js/avisos.js"></script></body></html>',
        { runScripts: 'outside-only', url: 'http://localhost/' }
      );
      const widget = fs.readFileSync(path.join(rootDir, 'js', 'avisos.js'), 'utf-8');

      dom.window.eval(widget);
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));

      const indicador = dom.window.document.querySelector('#hbav-semana');
      expect(indicador).not.toBeNull();
      expect(indicador.textContent).toMatch(/^\d{1,2}$/);
      expect(indicador.getAttribute('datetime')).toMatch(/^\d{4}-W\d{2}$/);
      expect(indicador.getAttribute('tabindex')).toBe('0');
      expect(indicador.getAttribute('aria-label')).toMatch(/^Estamos na semana \d{1,2} do ano$/);
      expect(dom.window.document.querySelector('.hbav-fab')).toBeNull();
      dom.window.close();
    });
  });
});
