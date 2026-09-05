# AGENTS.md

Este arquivo define as instrucoes do projeto para o Codex CLI. Use este arquivo para evitar erros e acelerar o aprendizado.

## Projetos e fluxo de trabalho

**Este é um site **estático** (HTML/CSS/JS puro, Bootstrap + CDN, sem build, sem framework, sem CI/CD).** O site é servido diretamente (`python3 -m http.server`) e toda validação roda localmente.

## Comandos essenciais

- `python3 -m http.server 8000` – serve o site (http://localhost:8000)
- `npm install` – instala devDependencies (Jest, Playwright, Polly, jsdom)
- `npm test` – Jest: valida estrutura, homes, links, logo e `materialMap`
- `npm run test:watch` – Jest em watch
- `npm run test:coverage` – Jest com cobertura
- `npm run capture` – validação visual (Playwright)

## Arquitetura (navegação 4-níveis)

1. **`index.html`** – seletor de semestre (hub, `body.semester-hub`)
2. **`pages/home_<ano>_<sem>.html`** – home do semestre
3. **`pages/home_<slug>.html`** – cronograma da disciplina (2026.1) ou nome dedicado (2026.2)
4. **`pages/<slug>/slide_*.html`** e **`pages/<slug>/material/material_*.html`** – slides e materiais (links nos dois sentidos)

## Configuração e invariantes

**Config como documentação:** `config/*.json` é a fonte de registro — nada é lido em runtime. As páginas são HTML escrito à mão.

**Invariantes que quebram `npm test`:**
- `index.html`: exatamente 3 cards `.semester-card` com hrefs fixos
- Homes 2026.1: todo `a[href*="slide_"]` deve estar no objeto `materialMap` do `<script>` no fim da home
- Homes 2026.2: sem `materialMap` — botões "Ver slide"/"Ver material" já estão no HTML
- Todo `slide_*.html`: `footer.slide-footer` com **exatamente 4 filhos** (`.slide-controls` com `#slideCounter`, link "Ver material escrito" com href `material/`, logo Senac)
- Cada disciplina nova: adicione em `DISCIPLINE_HOME_MAP` de `specs/slide-structure.spec.js`
- Todo href relativo resolve no disco (adicione card e arquivo-alvo juntos)
- Logo Senac obrigatório em toda página `.html` (`<img>` com `alt` contendo "senac")

## Pesquisas e fontes de verdade

**Fontes primárias (ler primeiro):**
- `README*`, manifests raiz, package.json, config/*.json
- build/test/lint/config (ex.: `scripts/capture-slides.mjs`, `js/standard_slides.js`)
- CI/workflows (aqui não há CI/CD)
- existing instruction files (`.claude/agents/*`, `CLAUDE.md`, `STANDARDS.md`, `DESIGN_SYSTEM.md`)

**Fontes secundárias (se necessário):**
- `pages/`, `css/`, `specs/`, `tests/` — leia para verificar arquitetura e fluxos reais de execution

**Arquitetura de verdade:**
- Frontend estático; quizzes usam RPCs e Realtime do Supabase (SQL em `supabase/`). Scripts Discord são ferramentas locais de operação, não parte do frontend.
- URLs de mídia estão em `sources.json` e `specs/cloudinary.spec.js` valida rastreabilidade
- CSS na ordem: `css/style.css` → `css/slides.css` → `css/base-styles.css`

## Como evitar falhas comuns

- **Não invente `lint`/`typecheck`/`build`** — estes scripts não existem, use Jest + Playwright
- **Navegação de slides**: use `js/standard_slides.js` (prev/next/fullscreen/progress, teclado ←/→/f)
- **Paleta 2026.2**: herda via `data-disciplina` (`qualidade2`→`qualidade`, `tcc2`→`tcc`). Setar `data-disciplina="qualidade2"`/`"tcc2"` no `<body>` quebra o visual silenciosamente
- **Logo Senac**: obrigatório em toda página `.html` → `tests/logo-senac.test.js`
- **Cor de slide**: nunca hardcode fora da paleta do `config/disciplina-<slug>.json`

## Project Skills

- `proteger-dados-turmas` -> `.codex/skills/proteger-dados-turmas/SKILL.md`
  - Use obrigatoriamente ao cadastrar, importar, editar ou revisar nomes, matrículas, listas de alunos ou outros dados pessoais nas páginas de turmas (`pages/turmas/`).

## Agentes e atalhos

**Agentes locais (preferir para conteúdo):**
- **`slide-builder`** – cria/edita slides e materiais escritos, detecta disciplina pelo path, valida com Playwright
- **`home-builder`** – edita `index.html` e `pages/home_*.html`, mantém variantes de card, marcos, `materialMap`, estrutura multi-semestre e testes consistentes

**Hook de persona:** `.claude/settings.json` injeta `.claude/persona-router.md` a cada prompt (roteia para persona AIOX).

**Executar persona:**
1. Use `/skills` → `aiox-<agent-id>` (ex.: `aiox-architect`)
2. OU use `@architect`, `/architect`, `/architect.md` → `.aiox-core/development/agents/architect.md`
3. Outras personas: `@dev`, `/dev`, `/dev.md`, `@qa`, `/qa`, `/qa.md`, `@pm`, `/pm`, `/pm.md`, `@po`, `/po`, `/po.md`, `@sm`, `/sm`, `/sm.md`, `@analyst`, `/analyst`, `/analyst.md`, `@devops`, `/devops`, `/devops.md`, `@data-engineer`, `/data-engineer`, `/data-engineer.md`, `@ux-design-expert`, `/ux-design-expert`, `/ux-design-expert.md`, `@squad-creator`, `/squad-creator`, `/squad-creator.md`, `@aiox-master`, `/aiox-master`, `/aiox-master.md`

## Testes

**Runner:** Jest (package.json: `testMatch` = `tests/**/*.test.js` + `specs/**/*.spec.js`)

**Críticos para alterações no cronograma:**
- `tests/home-cards.test.js` – homes 2026.1 **hardcoded**; `materialMap` consistente (regex para no 1º `}`)
- `tests/cronograma-2026-2.test.js` – semanas das aulas e marcos em sincronia entre config, homes, slides e materiais
- `tests/links-internos.test.js` – todo href interno resolve no disco
- `tests/index.test.js` – exatamente 3 cards de semestre com hrefs fixos
- `specs/slide-structure.spec.js` – 1º slide (logo+keywords), 2º slide ("Agenda"), `DISCIPLINE_HOME_MAP` obrigatório
- `specs/footer-layout-standard.spec.js` – footer com **exatamente 4 filhos** e texto "Ver material escrito"

**Dependentes de rede (flaky offline):** `aulas.test.js`, `external-links.test.js`, `logo-senac.test.js`, `cloudinary.spec.js`

## Generação de índice

`index.json` (raiz) mantém a árvore navegável (`.aiox-core` aparece resumido; `.git`/`node_modules` omitidos). Regenerar após mudanças estruturais grandes.
