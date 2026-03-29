/**
 * SPEC: Cloudinary — Gestão de Mídias
 *
 * Regras:
 *
 * 1. SOURCES.JSON
 *    - Deve existir na raiz do projeto
 *    - Deve ser JSON válido
 *    - Todas as chaves devem seguir o padrão snake_case
 *    - Todos os valores devem ser URLs válidas do Cloudinary
 *      (https://res.cloudinary.com/<cloud_name>/...)
 *
 * 2. RASTREABILIDADE
 *    - Toda URL do Cloudinary usada em arquivos HTML deve estar
 *      registrada em sources.json como valor de alguma chave
 *
 * 3. ACESSIBILIDADE
 *    - Toda URL em sources.json deve responder HTTP 200
 *    - Toda URL externa usada em atributos de mídia (src, poster, data-src) nos HTMLs
 *      deve responder HTTP 200 (seguindo redirects) — independente de ser Cloudinary ou não
 *
 * 4. AMBIENTE
 *    - O arquivo .env.example deve existir na raiz
 *    - .env.example deve declarar as três variáveis obrigatórias:
 *        CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
 *    - O arquivo .env real NÃO deve existir no repositório (está no .gitignore)
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Como adicionar uma nova mídia
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *  1. Copie .env.example para .env e preencha as credenciais do Cloudinary.
 *
 *  2. Execute o script de upload:
 *       node scripts/upload-to-cloudinary.js <arquivo> <chave>
 *     Exemplo:
 *       node scripts/upload-to-cloudinary.js assets/logo.png senac_logo_pb
 *
 *  3. O script fará o upload e adicionará a entrada em sources.json:
 *       {
 *         "senac_logo_pb": "https://res.cloudinary.com/.../logo.png"
 *       }
 *
 *  4. Use a URL gerada no HTML (<img src>, <video src>, etc.).
 *
 *  Convenção de chaves em sources.json:
 *    - snake_case obrigatório
 *    - Padrão recomendado: <disciplina>_<tipo>_<contexto>
 *      Exemplos: logica_capa_aula01, senac_logo_pb, qualidade_banner_tdd
 * ─────────────────────────────────────────────────────────────────────────────
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const { JSDOM } = require('jsdom');

const ROOT = path.resolve(__dirname, '..');
const SOURCES_PATH = path.join(ROOT, 'sources.json');
const ENV_EXAMPLE_PATH = path.join(ROOT, '.env.example');
const ENV_PATH = path.join(ROOT, '.env');
const PAGES_DIR = path.join(ROOT, 'pages');

const CLOUDINARY_URL_RE = /^https:\/\/res\.cloudinary\.com\/[^/]+\/.+/;
const EXTERNAL_URL_RE = /^https?:\/\//;
const SNAKE_CASE_RE = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;
const REQUIRED_ENV_VARS = [
  'CLOUDINARY_CLOUD_NAME',
  'CLOUDINARY_API_KEY',
  'CLOUDINARY_API_SECRET',
];

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function loadSources() {
  const raw = fs.readFileSync(SOURCES_PATH, 'utf-8');
  return JSON.parse(raw);
}

/**
 * Coleta todas as URLs Cloudinary presentes em arquivos HTML dentro de pages/
 */
function collectCloudinaryUrlsFromHtml() {
  const urls = new Set();

  function scan(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(full);
      } else if (entry.isFile() && entry.name.endsWith('.html')) {
        const html = fs.readFileSync(full, 'utf-8');
        const dom = new JSDOM(html);
        const doc = dom.window.document;

        // Atributos que podem conter URLs de mídia
        const attrs = ['src', 'href', 'data-src', 'poster', 'content'];
        for (const attr of attrs) {
          doc.querySelectorAll(`[${attr}]`).forEach(el => {
            const val = el.getAttribute(attr) || '';
            if (CLOUDINARY_URL_RE.test(val)) {
              urls.add(val);
            }
          });
        }

        // Inline styles com url(...)
        const urlInStyle = /url\(['"]?(https:\/\/res\.cloudinary\.com\/[^'")\s]+)['"]?\)/g;
        let m;
        while ((m = urlInStyle.exec(html)) !== null) {
          urls.add(m[1]);
        }
      }
    }
  }

  scan(PAGES_DIR);
  return urls;
}

/**
 * Coleta todas as URLs externas de mídia (src, poster, data-src) nos HTMLs.
 * Exclui URLs de scripts/CSS/fontes — foca apenas em imagens e vídeos.
 */
function collectExternalMediaUrls() {
  const urls = new Set();
  const MEDIA_TAGS = ['img', 'video', 'audio', 'source', 'iframe'];
  const MEDIA_ATTRS = ['src', 'data-src', 'poster'];

  function scan(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === 'node_modules' || entry.name.startsWith('.')) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        scan(full);
      } else if (entry.isFile() && entry.name.endsWith('.html')) {
        const html = fs.readFileSync(full, 'utf-8');
        const dom = new JSDOM(html);
        const doc = dom.window.document;

        for (const tag of MEDIA_TAGS) {
          doc.querySelectorAll(tag).forEach(el => {
            for (const attr of MEDIA_ATTRS) {
              const val = el.getAttribute(attr) || '';
              if (EXTERNAL_URL_RE.test(val)) {
                urls.add(val);
              }
            }
          });
        }
      }
    }
  }

  scan(PAGES_DIR);
  return urls;
}

/**
 * Verifica se uma URL está acessível.
 * Tenta HEAD primeiro; se o servidor rejeitar (403/405), faz GET com abort imediato.
 * Segue redirects. Timeout de 10s por tentativa.
 */
function checkUrl(url, method = 'HEAD', maxRedirects = 5) {
  return new Promise(resolve => {
    let parsed;
    try { parsed = new URL(url); } catch { return resolve(0); }

    const lib = parsed.protocol === 'https:' ? https : require('http');
    const req = lib.request(
      {
        hostname: parsed.hostname,
        path: parsed.pathname + parsed.search,
        method,
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; aulas-senac-test/1.0)' },
      },
      res => {
        res.destroy(); // não baixa o body
        const status = res.statusCode;

        // Seguir redirect
        if (maxRedirects > 0 && status >= 300 && status < 400 && res.headers.location) {
          const next = res.headers.location.startsWith('http')
            ? res.headers.location
            : `${parsed.protocol}//${parsed.hostname}${res.headers.location}`;
          return resolve(checkUrl(next, method, maxRedirects - 1));
        }

        // Servidor não aceita HEAD → tentar GET
        if (method === 'HEAD' && (status === 403 || status === 405)) {
          return resolve(checkUrl(url, 'GET', maxRedirects));
        }

        resolve(status);
      }
    );
    req.on('error', () => resolve(0));
    req.setTimeout(10000, () => { req.destroy(); resolve(0); });
    req.end();
  });
}

// ─────────────────────────────────────────────
// TESTES
// ─────────────────────────────────────────────

// ── 1. sources.json ─────────────────────────

describe('sources.json — estrutura e validade', () => {
  test('deve existir na raiz do projeto', () => {
    expect(fs.existsSync(SOURCES_PATH)).toBe(true);
  });

  test('deve ser JSON válido e não vazio', () => {
    const sources = loadSources();
    expect(typeof sources).toBe('object');
    expect(sources).not.toBeNull();
    expect(Object.keys(sources).length).toBeGreaterThan(0);
  });

  describe('chaves', () => {
    test('todas as chaves devem seguir o padrão snake_case', () => {
      const sources = loadSources();
      const invalid = Object.keys(sources).filter(k => !SNAKE_CASE_RE.test(k));
      expect(invalid).toEqual([]);
    });
  });

  describe('valores', () => {
    test('todos os valores devem ser URLs válidas do Cloudinary', () => {
      const sources = loadSources();
      const invalid = Object.entries(sources).filter(
        ([, url]) => !CLOUDINARY_URL_RE.test(url)
      );
      if (invalid.length > 0) {
        throw new Error(
          'Entradas com URL inválida:\n' +
            invalid.map(([k, v]) => `  "${k}": "${v}"`).join('\n')
        );
      }
      expect(invalid).toEqual([]);
    });

    test('não deve ter valores duplicados (duas chaves para a mesma URL)', () => {
      const sources = loadSources();
      const urls = Object.values(sources);
      const seen = new Set();
      const duplicates = [];
      for (const url of urls) {
        if (seen.has(url)) duplicates.push(url);
        seen.add(url);
      }
      if (duplicates.length > 0) {
        throw new Error('URLs duplicadas em sources.json:\n' + duplicates.map(u => `  ${u}`).join('\n'));
      }
      expect(duplicates).toEqual([]);
    });
  });
});

// ── 2. Rastreabilidade ───────────────────────

describe('Rastreabilidade — URLs no HTML registradas em sources.json', () => {
  let sources;
  let htmlUrls;

  beforeAll(() => {
    sources = loadSources();
    htmlUrls = collectCloudinaryUrlsFromHtml();
  });

  test('deve existir ao menos uma URL Cloudinary nos arquivos HTML', () => {
    expect(htmlUrls.size).toBeGreaterThan(0);
  });

  test('toda URL Cloudinary usada no HTML deve estar em sources.json', () => {
    const registeredUrls = new Set(Object.values(sources));
    const unregistered = [...htmlUrls].filter(url => !registeredUrls.has(url));

    if (unregistered.length > 0) {
      throw new Error(
        'URLs Cloudinary usadas no HTML mas não registradas em sources.json:\n' +
          unregistered.map(u => `  ${u}`).join('\n') +
          '\n\nAdicione cada URL acima em sources.json com uma chave snake_case descritiva.'
      );
    }

    expect(unregistered).toEqual([]);
  });
});

// ── 3. Acessibilidade — mídias externas nos HTMLs ───────────────────────────

describe('Acessibilidade — URLs externas de mídia nos HTMLs respondem HTTP 200', () => {
  const mediaUrls = collectExternalMediaUrls();

  test(`deve encontrar URLs externas de mídia para validar (${mediaUrls.size} encontradas)`, () => {
    expect(mediaUrls.size).toBeGreaterThan(0);
  });

  test.each([...mediaUrls])('%s deve responder HTTP 200', async url => {
    const status = await checkUrl(url);
    // 429 = rate limit (recurso existe, servidor throttlou a requisição) → aceito
    if (status === 429) return;
    if (status !== 200) {
      throw new Error(
        `URL de mídia quebrada: ${url}\n` +
          `Status recebido: ${status}\n` +
          `Substitua por uma URL válida ou faça upload no Cloudinary.`
      );
    }
    expect(status).toBe(200);
  });
});

// ── 4. Acessibilidade — sources.json ────────

describe('Acessibilidade — URLs em sources.json respondem HTTP 200', () => {
  let sources;

  beforeAll(() => {
    sources = loadSources();
  });

  test.each(
    (() => {
      try {
        return Object.entries(loadSources());
      } catch {
        return [];
      }
    })()
  )('"%s" → %s deve responder 200', async (key, url) => {
    const status = await checkUrl(url);
    expect(status).toBe(200);
  });
});

// ── 5. Ambiente ──────────────────────────────

describe('Ambiente — .env.example e .env', () => {
  test('.env.example deve existir na raiz', () => {
    expect(fs.existsSync(ENV_EXAMPLE_PATH)).toBe(true);
  });

  REQUIRED_ENV_VARS.forEach(varName => {
    test(`.env.example deve declarar a variável ${varName}`, () => {
      const content = fs.readFileSync(ENV_EXAMPLE_PATH, 'utf-8');
      expect(content).toContain(varName);
    });
  });

  test('.env real NÃO deve existir no repositório', () => {
    expect(fs.existsSync(ENV_PATH)).toBe(false);
  });
});
