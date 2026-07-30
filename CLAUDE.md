# CLAUDE.md

Guia operacional para o Claude Code neste repositório. Leia antes de editar.
Padrões de processo e infra ficam em [STANDARDS.md](./STANDARDS.md); a fonte da verdade visual é [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

## O que é este projeto

**Hub de Aulas Senac** — site **estático** (HTML + CSS + JS puro, Bootstrap 5/Font Awesome via CDN, fonte Outfit) que centraliza cronogramas, slides e materiais das disciplinas. **Sem build, sem bundler, sem TypeScript.** É servido cru.

> ⚠️ **Sem pipeline de CI/CD, por decisão de projeto.** Não crie `.github/workflows/`. Validação roda **localmente** antes de commitar (ver [STANDARDS.md](./STANDARDS.md)). `.github/agents/` contém só personas do framework AIOX — não há Actions.

## Comandos reais

```bash
python3 -m http.server 8000      # servir o site (http://localhost:8000) — não há build
npm install                      # instalar devDependencies (Jest, Playwright, Polly, jsdom)
npm test                         # Jest: valida estrutura de slides, links, homes, logo
npm run test:watch               # Jest em watch
npm run test:coverage            # Jest com cobertura
npm run capture                  # validação visual (Playwright) — scripts/capture-slides.mjs
node scripts/capture-slides.mjs pages/<slug>/slide_<arq>.html .tmp/shots 1280 720   # captura 1 slide
```

> ❌ **Não existem** `npm run lint`, `typecheck`, `build`, `sync:ide`, `validate:structure`, `validate:agents`. Se algum doc/agente mandar rodar isso, está errado (ver aviso sobre AGENTS.md abaixo). Os únicos scripts são `test`, `test:watch`, `test:coverage`, `capture`.

## Arquitetura (navegação em 4 níveis)

1. **`index.html`** — seletor de semestre. `body.semester-hub`, exatamente **3** cards `.semester-card` (cada um é um `<a>`), apontando para `pages/home_2025_2.html`, `pages/home_2026_1.html`, `pages/home_2026_2.html`.
2. **`pages/home_<ano>_<sem>.html`** — home do semestre: lista as disciplinas daquele período como cartões.
3. **`pages/home_<disciplina>.html`** — cronograma da disciplina (cards de aula → slides). Padrão de nome **não uniforme**: 2026.1 usa `home_<slug>.html` (`home_qualidade.html`); 2026.2 usa nome dedicado (`home_qualidade_2026_2.html`, `home_tcc2.html`).
4. **`pages/<slug>/slide_*.html`** e **`pages/<slug>/material/material_*.html`** — slides e materiais escritos, linkados nos dois sentidos.

Navegação dos slides vem de `js/standard_slides.js` (prev/next/fullscreen/progress + teclado ←/→/f). CSS sempre nesta ordem: `css/style.css` → `css/slides.css` → `css/base-styles.css`.

## Config-driven (nada é lido em runtime — é documentação/dados)

- **`config/semestres.json`** — registro-mestre: `atual`, `index`, e `semestres[]` com `{periodo, home, accent, calendario, disciplinas[]}`. Cada disciplina: `{name, slug, config, home, slides_dir, material_dir, status, turmas, marcos}`; `turmas[]` registra `{sigla, numero_aula, curso, campus, modalidade}` quando esses dados estiverem disponíveis. **Ninguém lê isso em runtime** — as homes são HTML escrito à mão; mantenha em sincronia manual.
- **`config/disciplina-<slug>.json`** (5 arquivos: `qualidade`, `qualidade2`, `logica`, `tcc`, `tcc2`) — tokens de cor/tema por disciplina (`theme.primary/secondary/accent/cover_gradient/...`, `font`, `particle_count`).
- **`config/standards.json`** — contrato estrutural dos slides (IDs/classes canônicos: `slide-container`, `slide`, `active`, `slide-footer`, `progressBar`, `prevBtn`, `nextBtn`, `fullscreenBtn`; snippets; paths de CSS/JS).
- **`sources.json`** — catálogo de URLs de mídia externa (logos Senac no Cloudinary). **Não use imagem externa sem cadastrar aqui** (specs/cloudinary.spec.js exige rastreabilidade).

### Reuso de paleta 2026.2 (crítico)

`css/base-styles.css` só define blocos `body[data-disciplina=...]` para **`logica`, `qualidade`, `tcc`** (não existe `qualidade2` nem `tcc2`). Por isso os decks de 2026.2 herdam paleta via o campo `data_disciplina` do config: **`qualidade2` → `data-disciplina="qualidade"`** e **`tcc2` → `data-disciplina="tcc"`**. Setar `data-disciplina="qualidade2"`/`"tcc2"` no `<body>` **quebra o visual silenciosamente** (perde todos os tokens `--sl-*`, sem erro de teste).

## Convenções de nomenclatura

- Slide body: `<body class="slide-body" data-disciplina="<slug-de-paleta>">`.
- 1º slide = capa (`.glass-cover`) com logo Senac + keywords; 2º slide contém "Agenda"; `footer.slide-footer` com **exatamente 4 filhos diretos**.
- **Logo Senac (Cloudinary) obrigatório em TODA página `.html`**, com `alt` contendo "senac".
- Nunca hardcode cor fora de `config/disciplina-<slug>.json`.
- Cronograma: 2026.2 usa "Semana NN" (ISO 32–50); 2026.1 usa "DD Mês".

## Invariantes que mantêm os testes verdes

Alterar conteúdo **sem** respeitar isto quebra `npm test`:

- **`index.html`**: exatamente **3** `.semester-card` com hrefs fixos → `tests/index.test.js`. Adicionar/renomear semestre exige atualizar o teste.
- **Homes 2026.1** (`home_qualidade/logica/tcc`): todo `a[href*="slide_"]` (sem `.no-actions`) precisa de entrada no objeto `materialMap` do `<script>` no fim da home → `tests/home-cards.test.js`. O regex `materialMap = {...}` **para no primeiro `}`**: não aninhe chaves, não deixe vazio.
- **Homes 2026.2**: **não têm `materialMap`** — os botões "Ver slide"/"Ver material" já vão escritos no HTML do card. Não misture os dois estilos numa mesma home.
- **Todo `slide_*.html`**: `footer.slide-footer` com **exatamente 4 filhos** (`.slide-controls` com `#slideCounter`, link "Ver material escrito" com href `material/`, link do logo Senac) → `specs/footer-layout-standard.spec.js`. Mudar o texto ou adicionar um 5º filho quebra.
- **Novo diretório de disciplina** `pages/<slug>/`: precisa entrar em `DISCIPLINE_HOME_MAP` de `specs/slide-structure.spec.js` (e no mapa de `tests/slides-footer.test.js`) — senão o teste **lança erro** "Disciplina desconhecida".
- **Todo href relativo** em qualquer `.html` deve resolver no disco → `tests/links-internos.test.js`. Adicione card e arquivo-alvo **juntos**.
- **Testes de rede** (`aulas.test.js`, `external-links.test.js`, `logo-senac.test.js`, `cloudinary.spec.js`) fazem HTTP real ao Cloudinary/LinkedIn — podem falhar **offline**. `external-links` usa cassetes Polly em `tests/cassettes/`.

Detalhe completo dos testes: ver a seção "Testes" do [STANDARDS.md](./STANDARDS.md).

## Onde vive a verdade & automação local

- **Design/visual:** [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) (paletas, tipografia, variantes de card, padrão de slides).
- **Agentes locais** (`.claude/agents/`): **`slide-builder`** (cria/edita slides e materiais, detecta disciplina pelo path, valida com Playwright) e **`home-builder`** (edita `index.html` e `pages/home_*.html`, mantém `materialMap`/marcos/testes). Preferir esses agentes para conteúdo.
- **Hook de persona:** `.claude/settings.json` injeta `.claude/persona-router.md` a cada prompt (roteia para uma persona AIOX).

## ⚠️ AGENTS.md ≠ este projeto (era boilerplate genérico)

`AGENTS.md` foi corrigido para refletir este repo. **Ignore qualquer versão antiga** que cite `bin/`, `packages/`, `docs/stories/`, `.codex/`, workflow "por stories", `CLI First`, ou os scripts `sync:ide`/`validate:structure`/`validate:agents`/`lint`/`typecheck` — **nada disso existe aqui**. Este é um site estático UI-only; os comandos válidos são os da seção "Comandos reais" acima.
