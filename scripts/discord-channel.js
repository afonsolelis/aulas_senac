#!/usr/bin/env node
/**
 * scripts/discord-channel.js
 * Cria um canal (ou categoria) no servidor do Discord via REST API (bot).
 *
 * Uso:
 *   node scripts/discord-channel.js "avisos"
 *   node scripts/discord-channel.js "reunioes" --type voice
 *   node scripts/discord-channel.js "TCC2" --type category
 *   node scripts/discord-channel.js "duvidas" --category <CATEGORY_ID> --topic "Tire suas dúvidas aqui"
 *   npm run discord:channel -- "avisos" --topic "Comunicados oficiais"
 *
 * Requisitos:
 *   - Permissão do bot: "Gerenciar canais" (Manage Channels)
 *   - .env com DISCORD_BOT_TOKEN e DISCORD_GUILD_ID (Modo Dev -> clique direito no
 *     nome do servidor -> Copiar ID do servidor)
 */

'use strict';

const { loadEnv, fail, requireToken, discordRequest, explain } = require('./discord-lib');

loadEnv();

// type do canal na API do Discord
const TYPES = { text: 0, voice: 2, category: 4, announcement: 5, forum: 15 };

// ── Parse de argumentos ──────────────────────────────────────────────────────
const argv = process.argv.slice(2);
let typeName = 'text';
let parentId;
let topic;
const nameParts = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--type' || a === '-t') typeName = (argv[++i] || '').toLowerCase();
  else if (a === '--category' || a === '--parent') parentId = argv[++i];
  else if (a === '--topic') topic = argv[++i];
  else nameParts.push(a);
}
const name = nameParts.join(' ').trim();
const guildId = process.env.DISCORD_GUILD_ID;
const token = requireToken();

// ── Validações ───────────────────────────────────────────────────────────────
if (!guildId) {
  fail('DISCORD_GUILD_ID ausente. Defina em .env (Modo Dev → clique direito no servidor → Copiar ID do servidor).');
}
if (!name) {
  fail('Nome do canal não informado. Uso: node scripts/discord-channel.js "nome-do-canal"');
}
if (name.length > 100) {
  fail(`Nome tem ${name.length} caracteres; o Discord limita a 100.`);
}
if (!(typeName in TYPES)) {
  fail(`Tipo inválido: "${typeName}". Use um de: ${Object.keys(TYPES).join(', ')}.`);
}

// ── POST /guilds/{guild_id}/channels ─────────────────────────────────────────
const body = { name, type: TYPES[typeName] };
if (parentId) body.parent_id = parentId;
if (topic && TYPES[typeName] === TYPES.text) body.topic = topic;

discordRequest({
  method: 'POST',
  path: `/guilds/${guildId}/channels`,
  token,
  body,
})
  .then(({ status, json, raw }) => {
    if (status >= 200 && status < 300) {
      console.log(`✅ ${typeName} "${json && json.name ? json.name : name}" criado (id: ${json ? json.id : '?'}).`);
      return;
    }
    console.error(`❌ Discord respondeu ${status}:`);
    console.error(raw);
    const hint = explain(status);
    if (hint) console.error(hint);
    if (status === 403) console.error('→ O bot precisa da permissão "Gerenciar canais" neste servidor.');
    process.exit(1);
  })
  .catch((e) => fail(`Erro de rede: ${e.message}`));
