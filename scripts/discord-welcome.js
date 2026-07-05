#!/usr/bin/env node
/**
 * scripts/discord-welcome.js
 * Mostra (READ-ONLY) a configuração de boas-vindas do servidor:
 *   - Mensagens de sistema ("Fulano entrou"): ligadas? em qual canal?
 *   - Welcome Screen (servidores de Comunidade), se houver.
 * Não altera nada.
 *
 * Uso:
 *   node scripts/discord-welcome.js
 *   npm run discord:welcome
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
if (!guildId) fail('DISCORD_GUILD_ID ausente. Defina em .env ou passe --guild <ID>.');

// system_channel_flags — bit setado = notificação SUPRIMIDA (desligada)
const SUPPRESS_JOIN = 1 << 0; // "Fulano entrou no servidor"
const SUPPRESS_REPLIES = 1 << 3; // botão "Acene para Fulano"

(async () => {
  const g = await discordRequest({ method: 'GET', path: `/guilds/${guildId}`, token });
  if (g.status !== 200) {
    console.error(`❌ GET /guilds/${guildId} → ${g.status}`);
    const h = explain(g.status);
    if (h) console.error(h);
    process.exit(1);
  }
  const guild = g.json;
  const flags = guild.system_channel_flags || 0;
  const joinOn = !(flags & SUPPRESS_JOIN);
  const repliesOn = !(flags & SUPPRESS_REPLIES);
  const sysChan = guild.system_channel_id;

  console.log(`🏠 Servidor: "${guild.name}"`);
  console.log('');
  console.log('📨 Mensagem de boas-vindas do SISTEMA ("Fulano entrou no servidor"):');
  console.log(`   • Status:  ${joinOn ? 'LIGADA ✅' : 'DESLIGADA ❌'}`);
  console.log(`   • Canal:   ${sysChan ? `#${sysChan}` : '(nenhum canal de sistema definido)'}`);
  console.log(`   • Botão "acene para o novato": ${repliesOn ? 'ligado' : 'desligado'}`);
  console.log('   • Texto:   ALEATÓRIO (o Discord sorteia a frase; não dá pra fixar um texto próprio aqui).');
  console.log('');

  const features = guild.features || [];
  const isCommunity = features.includes('COMMUNITY');
  console.log(`🌐 Servidor de Comunidade: ${isCommunity ? 'SIM' : 'não (necessário para Welcome Screen / Onboarding)'}`);

  const ws = await discordRequest({ method: 'GET', path: `/guilds/${guildId}/welcome-screen`, token });
  if (ws.status === 200 && ws.json) {
    const chans = ws.json.welcome_channels || [];
    console.log('');
    console.log('👋 Welcome Screen (tela personalizada mostrada a quem entra):');
    console.log(`   • Descrição: ${ws.json.description || '(vazia)'}`);
    if (chans.length) {
      console.log('   • Canais em destaque:');
      for (const c of chans) {
        console.log(`     - ${c.emoji_name || '•'} #${c.channel_id} — ${c.description || ''}`);
      }
    } else {
      console.log('   • Sem canais em destaque configurados.');
    }
  } else if (ws.status === 404) {
    console.log('   • Welcome Screen: não configurada.');
  } else {
    console.log(`   • Welcome Screen: não foi possível ler (status ${ws.status}).`);
  }
})().catch((e) => fail(`Erro de rede: ${e.message}`));
