# AGENTS.md - Synkra AIOX (Codex CLI)

Este arquivo define as instrucoes do projeto para o Codex CLI.

<!-- AIOX-MANAGED-START: core -->
## Core Rules

> Este e um **site estatico** (HTML/CSS/JS puro, sem build/CI). Regras genericas do AIOX (CLI First, stories, `docs/stories/`) **nao se aplicam** aqui.

1. Fonte da verdade do projeto: `CLAUDE.md` (guia operacional) + `DESIGN_SYSTEM.md` (visual) + `STANDARDS.md` (padroes).
2. Prioridade real: **UI/conteudo** — nao ha camada CLI nem observabilidade.
3. Mantenha conteudo (`pages/`), config (`config/*.json`) e testes em sincronia manual.
4. Nao invente requisitos fora dos artefatos existentes.

<!-- AIOX-MANAGED-END: core -->

<!-- AIOX-MANAGED-START: quality -->
## Quality Gates

Rodam **localmente** antes do commit (nao ha CI). `lint`/`typecheck`/`build` **nao existem** neste repo.

- Rode `npm test` (Jest: estrutura de slides, homes, links internos, logo, `materialMap`)
- Valide slides alterados: `npm run capture` (Playwright)
- Garanta que card ↔ arquivo e slide ↔ material foram adicionados em sincronia
<!-- AIOX-MANAGED-END: quality -->

<!-- AIOX-MANAGED-START: codebase -->
## Project Map

- Seletor de semestre: `index.html`
- Paginas (homes, slides, materiais): `pages/`
- Config/registro: `config/*.json` · assets externos: `sources.json`
- Estilos: `css/` · navegacao de slides: `js/standard_slides.js`
- Testes (Jest): `tests/` + `specs/` · captura visual: `scripts/capture-slides.mjs`
- Docs: `README.md`, `CLAUDE.md`, `STANDARDS.md`, `DESIGN_SYSTEM.md`, `index.json`
- Framework AIOX (vendorizado, personas genericas): `.aiox-core/` e `.github/agents/`
<!-- AIOX-MANAGED-END: codebase -->

<!-- AIOX-MANAGED-START: commands -->
## Common Commands

- `python3 -m http.server 8000` (servir o site; sem build)
- `npm install`
- `npm test` / `npm run test:watch` / `npm run test:coverage`
- `npm run capture` (validacao visual Playwright)
<!-- AIOX-MANAGED-END: commands -->

<!-- AIOX-MANAGED-START: shortcuts -->
## Agent Shortcuts

Preferencia de ativacao no Codex CLI:
1. Use `/skills` e selecione `aiox-<agent-id>` vindo de `.codex/skills` (ex.: `aiox-architect`)
2. Se preferir, use os atalhos abaixo (`@architect`, `/architect`, etc.)

Interprete os atalhos abaixo carregando o arquivo correspondente em `.aiox-core/development/agents/` (fallback: `.codex/agents/`), renderize o greeting via `generate-greeting.js` e assuma a persona ate `*exit`:

- `@architect`, `/architect`, `/architect.md` -> `.aiox-core/development/agents/architect.md`
- `@dev`, `/dev`, `/dev.md` -> `.aiox-core/development/agents/dev.md`
- `@qa`, `/qa`, `/qa.md` -> `.aiox-core/development/agents/qa.md`
- `@pm`, `/pm`, `/pm.md` -> `.aiox-core/development/agents/pm.md`
- `@po`, `/po`, `/po.md` -> `.aiox-core/development/agents/po.md`
- `@sm`, `/sm`, `/sm.md` -> `.aiox-core/development/agents/sm.md`
- `@analyst`, `/analyst`, `/analyst.md` -> `.aiox-core/development/agents/analyst.md`
- `@devops`, `/devops`, `/devops.md` -> `.aiox-core/development/agents/devops.md`
- `@data-engineer`, `/data-engineer`, `/data-engineer.md` -> `.aiox-core/development/agents/data-engineer.md`
- `@ux-design-expert`, `/ux-design-expert`, `/ux-design-expert.md` -> `.aiox-core/development/agents/ux-design-expert.md`
- `@squad-creator`, `/squad-creator`, `/squad-creator.md` -> `.aiox-core/development/agents/squad-creator.md`
- `@aiox-master`, `/aiox-master`, `/aiox-master.md` -> `.aiox-core/development/agents/aiox-master.md`
<!-- AIOX-MANAGED-END: shortcuts -->

## Project Skills

- `proteger-dados-turmas` -> `.codex/skills/proteger-dados-turmas/SKILL.md`
  - Use obrigatoriamente ao cadastrar, importar, editar ou revisar nomes, matrículas, listas de alunos ou outros dados pessoais nas páginas de turmas.
