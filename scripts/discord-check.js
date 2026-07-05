#!/usr/bin/env node
/**
 * scripts/discord-check.js
 * Diagnóstico READ-ONLY da configuração do Discord. Não altera nada.
 *   - Valida o DISCORD_BOT_TOKEN e mostra o bot
 *   - Confirma o servidor (DISCORD_GUILD_ID) e se o bot está nele
 *
 * Uso:
 *   node scripts/discord-check.js
 *   node scripts/discord-check.js --guild <GUILD_ID>
 *   npm run discord:check -- --guild 1518628878124581025
 */

'use strict';

const { loadEnv, fail, requireToken, discordRequest, explain } = require('./discord-lib');

loadEnv();

const argv = process.argv.slice(2);
let guildId = process.env.DISCORD_GUILD_ID;
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--guild' || argv[i] === '-g') guildId = argv[++i];
}
const token = requireToken();

(async () => {
  // 1) Token válido?  GET /users/@me
  const me = await discordRequest({ method: 'GET', path: '/users/@me', token });
  if (me.status !== 200) {
    console.error(`❌ Token inválido (status ${me.status}).`);
    const h = explain(me.status);
    if (h) console.error(h);
    process.exit(1);
  }
  const u = me.json || {};
  const tag = u.discriminator && u.discriminator !== '0' ? `#${u.discriminator}` : '';
  console.log(`✅ Token OK — bot: ${u.username}${tag} (id ${u.id})`);

  // 2) Guild informado?
  if (!guildId) {
    console.log('ℹ️  DISCORD_GUILD_ID não definido. Defina em .env ou passe --guild <ID>.');
    return;
  }

  // 3) O bot está nesse servidor?  GET /guilds/{id}  (retorna 404 se o bot não for membro)
  const g = await discordRequest({ method: 'GET', path: `/guilds/${guildId}`, token });
  if (g.status === 200) {
    console.log(`✅ Servidor confirmado: "${g.json.name}" (id ${g.json.id}) — o bot está nele.`);
    return;
  }
  if (g.status === 404) {
    console.error(`❌ Servidor ${guildId}: 404 — ou o ID está errado, ou o bot NÃO está nesse servidor.`);
  } else {
    console.error(`❌ GET /guilds/${guildId} → ${g.status}`);
    if (g.raw) console.error(g.raw);
    const h = explain(g.status);
    if (h) console.error(h);
  }
  process.exit(1);
})().catch((e) => fail(`Erro de rede: ${e.message}`));
