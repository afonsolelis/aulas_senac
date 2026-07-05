#!/usr/bin/env node
/**
 * scripts/discord-post.js
 * Posta uma mensagem num canal do Discord via REST API (bot). Sem dependências.
 *
 * Uso:
 *   node scripts/discord-post.js "Sua mensagem aqui"
 *   node scripts/discord-post.js --channel <CHANNEL_ID> "Mensagem para outro canal"
 *   node scripts/discord-post.js --file lembretes/discord-boas-vindas-tcc2.md
 *   npm run discord:post -- "Sua mensagem aqui"
 *
 * Credenciais (em .env — gitignored, NUNCA comite):
 *   DISCORD_BOT_TOKEN=...            token do bot (Developer Portal -> Bot -> Reiniciar Token)
 *   DISCORD_TCC2_CHANNEL_ID=...      canal padrão de avisos (Modo Dev -> clique direito -> Copiar ID)
 */

'use strict';

const fs = require('fs');
const { loadEnv, fail, requireToken, discordRequest, explain } = require('./discord-lib');

loadEnv();

// ── Parse de argumentos ──────────────────────────────────────────────────────
const argv = process.argv.slice(2);
let channelId = process.env.DISCORD_TCC2_CHANNEL_ID;
let filePath;
const parts = [];
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--channel' || argv[i] === '-c') {
    channelId = argv[++i];
  } else if (argv[i] === '--file' || argv[i] === '-f') {
    filePath = argv[++i];
  } else {
    parts.push(argv[i]);
  }
}

let content;
if (filePath) {
  if (!fs.existsSync(filePath)) fail(`Arquivo não encontrado: ${filePath}`);
  content = fs.readFileSync(filePath, 'utf-8').trim();
} else {
  content = parts.join(' ').trim();
}

const token = requireToken();

// ── Validações ───────────────────────────────────────────────────────────────
if (!channelId) {
  fail('Canal não informado. Use --channel <ID> ou defina DISCORD_TCC2_CHANNEL_ID em .env.');
}
if (!content) {
  fail('Mensagem vazia. Uso: node scripts/discord-post.js "sua mensagem"');
}
if (content.length > 2000) {
  fail(`Mensagem tem ${content.length} caracteres; o Discord limita a 2000.`);
}

// ── POST /channels/{id}/messages ─────────────────────────────────────────────
discordRequest({
  method: 'POST',
  path: `/channels/${channelId}/messages`,
  token,
  body: { content },
})
  .then(({ status, raw }) => {
    if (status >= 200 && status < 300) {
      console.log(`✅ Mensagem postada no canal ${channelId}.`);
      return;
    }
    console.error(`❌ Discord respondeu ${status}:`);
    console.error(raw);
    const hint = explain(status);
    if (hint) console.error(hint);
    process.exit(1);
  })
  .catch((e) => fail(`Erro de rede: ${e.message}`));
