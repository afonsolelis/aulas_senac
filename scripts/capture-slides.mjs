#!/usr/bin/env node
/**
 * capture-slides.mjs — valida e captura decks de slides do repositório.
 *
 * Uso:
 *   node scripts/capture-slides.mjs <caminho-html> <outDir> [width=1280] [height=720]
 *
 * Exemplo:
 *   node scripts/capture-slides.mjs pages/logica/slide_introducaoalogicaeferramentas.html .tmp/shots-aula01 1280 720
 *
 * Saída:
 *   - <outDir>/slide-<N>.png para cada slide
 *   - <outDir>/issues.json com problemas detectados (overflow, anime ausente, mismatch de animMap)
 *
 * Requisitos: playwright instalado (`npm i -D playwright && npx playwright install chromium`).
 */
import { chromium } from 'playwright';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');

const [, , htmlArg, outDirArg, wArg, hArg] = process.argv;

if (!htmlArg || !outDirArg) {
  console.error('Uso: node scripts/capture-slides.mjs <caminho-html> <outDir> [width=1280] [height=720]');
  process.exit(1);
}

const absHtml = resolve(REPO_ROOT, htmlArg);
const absOut = resolve(REPO_ROOT, outDirArg);
const width = Number(wArg) || 1280;
const height = Number(hArg) || 720;

await mkdir(absOut, { recursive: true });

const fileUrl = pathToFileURL(absHtml).href;
const issues = [];
const addIssue = (slide, kind, detail) => issues.push({ slide, kind, detail });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ viewport: { width, height } });
const page = await context.newPage();

const consoleErrors = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') consoleErrors.push(msg.text());
});
page.on('pageerror', (err) => consoleErrors.push(String(err)));

console.log(`[capture] opening ${fileUrl} @ ${width}x${height}`);
await page.goto(fileUrl, { waitUntil: 'load' });

// 1. Aguarda anime.js carregar (CDN ESM)
await page.waitForFunction(() => !!window.__anime, null, { timeout: 8000 }).catch(() => {
  addIssue(null, 'anime-missing', 'window.__anime não inicializou dentro de 8s (CDN falhou?)');
});

// 2. Descobre quantidade de slides e animMap.length
const stats = await page.evaluate(() => {
  const slides = document.querySelectorAll('.slide').length;
  const animMap = Array.isArray(window.animMap) ? window.animMap.length : null;
  const hasShowSlide = typeof window.showSlide === 'function';
  return { slides, animMap, hasShowSlide };
});

console.log(`[capture] slides=${stats.slides} animMap=${stats.animMap} showSlide=${stats.hasShowSlide}`);

if (stats.animMap !== null && stats.animMap !== stats.slides) {
  addIssue(null, 'animmap-mismatch', `animMap.length=${stats.animMap} mas há ${stats.slides} slides`);
}

// 3. Navega slide a slide e captura
for (let i = 1; i <= stats.slides; i++) {
  // Usa showSlide quando disponível, senão fallback por teclado
  if (stats.hasShowSlide) {
    await page.evaluate((idx) => window.showSlide(idx), i);
  } else {
    if (i > 1) await page.keyboard.press('ArrowRight');
  }
  await page.waitForTimeout(1500);

  const metrics = await page.evaluate(() => {
    const active = document.querySelector('.slide.active');
    if (!active) return null;
    const r = active.getBoundingClientRect();
    return {
      scrollW: active.scrollWidth,
      clientW: active.clientWidth,
      scrollH: active.scrollHeight,
      clientH: active.clientHeight,
      top: Math.round(r.top),
      id: active.id || null,
      isCover: active.classList.contains('cover-bg'),
      hasParticles: !!active.querySelector('.cover-particles circle'),
    };
  });

  if (metrics) {
    if (metrics.scrollW > metrics.clientW + 1) addIssue(i, 'overflow-x', `scrollW=${metrics.scrollW} > clientW=${metrics.clientW}`);
    if (metrics.scrollH > metrics.clientH + 1) addIssue(i, 'overflow-y', `scrollH=${metrics.scrollH} > clientH=${metrics.clientH}`);
    if (metrics.isCover && !metrics.hasParticles) addIssue(i, 'missing-particles', 'slide cover-bg sem .cover-particles circle');
  } else {
    addIssue(i, 'no-active-slide', 'nenhum .slide.active encontrado');
  }

  const pngPath = resolve(absOut, `slide-${String(i).padStart(2, '0')}.png`);
  await page.screenshot({ path: pngPath, fullPage: false });
  console.log(`[capture] slide ${i}/${stats.slides} -> ${basename(pngPath)}${metrics ? ` (${metrics.scrollW}x${metrics.scrollH})` : ''}`);
}

if (consoleErrors.length) {
  for (const e of consoleErrors) addIssue(null, 'console-error', e);
}

await writeFile(resolve(absOut, 'issues.json'), JSON.stringify({
  file: htmlArg,
  viewport: { width, height },
  stats,
  issues,
}, null, 2));

await browser.close();

console.log(`\n[capture] done. ${issues.length} issue(s). See ${outDirArg}/issues.json`);
process.exit(issues.length ? 1 : 0);
