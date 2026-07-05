'use strict';
/**
 * scripts/discord-lib.js
 * Helpers compartilhados para falar com a REST API do Discord. Sem dependências.
 * (Arquivo plano em scripts/ — não use subpasta "lib/", que é ignorada pelo .gitignore.)
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const ROOT = path.resolve(__dirname, '..');

// Carrega .env (parser minimalista). NÃO sobrescreve variáveis já definidas no
// process.env — permite forçar credenciais de teste via env inline.
function loadEnv() {
  const envPath = path.join(ROOT, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf-8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const eq = t.indexOf('=');
    if (eq === -1) continue;
    const key = t.slice(0, eq).trim();
    let val = t.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = val;
  }
}

function fail(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exit(1);
}

function requireToken() {
  const token = process.env.DISCORD_BOT_TOKEN;
  if (!token) {
    fail('DISCORD_BOT_TOKEN ausente. Copie .env.example para .env e preencha o token.');
  }
  return token;
}

// Faz uma requisição à API v10 do Discord. Resolve com { status, json, raw }.
function discordRequest({ method, path: apiPath, token, body }) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: 'discord.com',
        path: `/api/v10${apiPath}`,
        method,
        headers: {
          Authorization: `Bot ${token}`,
          'Content-Type': 'application/json',
          'User-Agent': 'aulas-senac-discord/1.0',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let json = null;
          try { json = data ? JSON.parse(data) : null; } catch { /* mantém raw */ }
          resolve({ status: res.statusCode, json, raw: data });
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// Traduz códigos de erro comuns do Discord em dicas acionáveis.
function explain(status) {
  if (status === 401) return '→ Token inválido. Redefina em Bot → Reiniciar Token e atualize .env.';
  if (status === 403) return '→ Sem permissão. Confira se o bot tem a permissão necessária e acesso ao recurso.';
  if (status === 404) return '→ Recurso não encontrado. Confira o ID informado (Modo Dev → Copiar ID).';
  if (status === 429) return '→ Rate limited. Aguarde alguns segundos e tente de novo.';
  return '';
}

module.exports = { loadEnv, fail, requireToken, discordRequest, explain, ROOT };
