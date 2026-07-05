# STANDARDS.md — Padrões do Projeto

Padrões de engenharia e infraestrutura do **Hub de Aulas Senac**, definidos sob a ótica DevOps.
Guia operacional para agentes: [CLAUDE.md](./CLAUDE.md). Verdade visual: [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

## 1. Princípios

- **Static-first.** Site servido cru (`python3 -m http.server`). Sem build, bundler, framework ou TypeScript. Não introduza toolchain sem necessidade real.
- **Local-first, sem CI/CD (por decisão).** Não há — e não deve haver — GitHub Actions. Os quality gates rodam **na máquina**, antes do commit. `.github/` guarda apenas personas de agente.
- **Config como documentação.** `config/*.json` e `sources.json` são a fonte de registro; as páginas são HTML escrito à mão e devem ser mantidas em sincronia manual (nada é lido em runtime).
- **DESIGN_SYSTEM.md manda no visual.** Cores, tipografia, cards e padrão de slides saem de lá + `config/disciplina-*.json`. Nunca hardcode cor fora do config.

## 2. Quality gates locais (Definition of Done)

Antes de commitar qualquer mudança de conteúdo ou infra:

1. `npm test` **passa** (Jest: estrutura, homes, links internos, logo, `materialMap`).
2. Slides novos/alterados validados visualmente: `npm run capture` (ou `node scripts/capture-slides.mjs <slide>`) — sem overflow, `animMap` casando o nº de slides.
3. Links internos resolvem no disco (card e arquivo-alvo criados **juntos**).
4. Nenhum segredo commitado (ver §5).
5. Testes de rede podem falhar **offline** — rode ao menos uma vez com internet; se vermelho só por rede, registre no commit.

> Não invente `lint`/`typecheck`/`build`: não há TS (nada a checar), nem bundler (nada a buildar), nem config de linter. Os gates reais e valiosos já existem — Jest + Playwright. O padrão é **usá-los**, não criar novos.

## 3. Convenção de commits

`feat:`, `fix:`, `refactor:`, `chore:` — **um commit por unidade de ensino ou por mudança de infra**.

- `feat(2026.2): ...` para novo conteúdo de disciplina/semestre.
- `fix:` para correção de link/estrutura/teste.
- `chore:` para config, docs, tooling.
- Evite commits vazios de significado ("Ok", "ok", "wip"). A mensagem deve dizer **o quê** e **de qual disciplina/semestre**.

## 4. Fluxo de trabalho

- **Branch principal:** `main`. Como não há CI, `main` reflete o que vai ao ar — **rode os gates da §2 antes de cada push**.
- Trabalho maior/arriscado: branch curta + merge após `npm test` verde. Trabalho pontual pode ir direto em `main`, desde que os gates passem.
- **Adicionar em sincronia:** card ↔ arquivo, slide ↔ material, disciplina ↔ `config` ↔ `DISCIPLINE_HOME_MAP` dos specs. Metade quebra o teste.
- Preferir os agentes locais `.claude/agents/{slide-builder,home-builder}` para conteúdo — eles já conhecem os invariantes.

## 5. Segredos & ambiente

- `.env` **nunca** é commitado (ignorado no `.gitignore`; `specs/cloudinary.spec.js` verifica ausência). Só `.env.example` versionado.
- Chaves/certificados (`*.key`, `*.pem`) e `.env.local`/`.env.*.local` ficam fora do git.
- Credenciais do Cloudinary (`CLOUDINARY_CLOUD_NAME/API_KEY/API_SECRET`) só em `.env` local.

## 6. Mídia & assets

- Toda URL de mídia externa (imagem/vídeo) usada em `pages/*.html` deve estar registrada em **`sources.json`** — chave `snake_case`, valor URL Cloudinary, sem duplicatas. `specs/cloudinary.spec.js` falha se faltar rastreabilidade.
- **Logo Senac obrigatório em toda página `.html`** (`<img>` com `alt` contendo "senac") → `tests/logo-senac.test.js`.

## 7. Estrutura & nomenclatura (resumo)

| Item | Padrão |
|---|---|
| Seletor de semestre | `index.html` (único, `body.semester-hub`, 3 cards) |
| Home de semestre | `pages/home_<ano>_<sem>.html` |
| Home de disciplina | `pages/home_<slug>.html` (2026.1) · nome dedicado (2026.2) |
| Slides | `pages/<slug>/slide_*.html` |
| Materiais | `pages/<slug>/material/material_*.html` |
| Config de disciplina | `config/disciplina-<slug>.json` |
| Paleta 2026.2 | herdada via `data_disciplina` (`qualidade2`→`qualidade`, `tcc2`→`tcc`) |

Detalhes e armadilhas: [CLAUDE.md](./CLAUDE.md) → "Invariantes que mantêm os testes verdes".

## 8. Testes — o que cobre e o que é frágil

**Runner:** Jest (config no `package.json`; `testMatch` = `tests/**/*.test.js` + `specs/**/*.spec.js`). DOM via `jsdom` instanciado à mão; rede via `node-fetch`/Polly.

Críticos ao mexer no cronograma:

- `tests/home-cards.test.js` — homes 2026.1 **hardcoded**; exige `materialMap` consistente (regex para no 1º `}`).
- `tests/links-internos.test.js` — todo href interno resolve no disco.
- `tests/index.test.js` — exatamente 3 cards de semestre com hrefs fixos.
- `specs/slide-structure.spec.js` — 1º slide (logo+keywords), 2º slide ("Agenda"), `DISCIPLINE_HOME_MAP` obrigatório.
- `specs/footer-layout-standard.spec.js` — footer com **exatamente 4 filhos** e texto literal "Ver material escrito".

Dependentes de rede (flaky offline): `aulas.test.js`, `external-links.test.js`, `logo-senac.test.js`, `cloudinary.spec.js`.

## 9. Índice do projeto

`index.json` (raiz) mantém a árvore navegável do repositório (`.aiox-core` aparece resumido; `.git`/`node_modules` omitidos). Regenerar após mudanças estruturais grandes.
