# Hub de Aulas Senac

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?logo=html5&logoColor=white)
![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3-7952B3?logo=bootstrap&logoColor=white)

Site estático que centraliza as aulas das disciplinas que leciono no SENAC. Cada disciplina tem seu próprio cronograma, slides e materiais de apoio.

## Estrutura

```
aulas_senac/
├── index.html                      # Seletor de semestre (2025.2 / 2026.1 / 2026.2)
├── pages/
│   ├── home_2025_2.html            # Disciplinas de 2025.2 (placeholders)
│   ├── home_2026_1.html            # Disciplinas de 2026.1
│   ├── home_2026_2.html            # Disciplinas de 2026.2 (Qualidade + TCC2)
│   ├── home_qualidade.html         # Cronograma — Qualidade de Software (2026.1)
│   ├── home_logica.html            # Cronograma — Introdução à Lógica (2026.1)
│   ├── home_tcc.html               # Cronograma — TCC1 (2026.1)
│   ├── home_qualidade_2026_2.html  # Cronograma — Qualidade de Software (2026.2)
│   ├── home_tcc2.html              # Cronograma — TCC2 (2026.2)
│   ├── professor.html
│   ├── qualidade/  logica/  tcc/   # slides + material/ de 2026.1
│   ├── qualidade2/                 # slides + material/ de Qualidade (2026.2)
│   └── tcc2/                       # slides + material/ de TCC2 (2026.2)
├── css/                            # style.css, slides.css, base-styles.css
├── js/standard_slides.js           # navegação prev/next/fullscreen/progress
├── config/
│   ├── disciplina-<slug>.json      # tokens por disciplina (qualidade, qualidade2, logica, tcc, tcc2)
│   ├── semestres.json              # registro dos semestres e suas disciplinas
│   └── standards.json              # padrão estrutural de slides
├── scripts/capture-slides.mjs      # validação visual (Playwright)
├── tests/ + specs/                 # Jest
└── DESIGN_SYSTEM.md                # fonte da verdade do design
```

> O `index.html` é um **seletor de semestre**: cada cartão leva a uma home `pages/home_<ano>_<sem>.html` que lista as disciplinas daquele período. O registro completo (semestres, disciplinas, marcos, calendário) vive em `config/semestres.json`.

## Disciplinas

**2026.1**
- **Qualidade de Software** (TADS) — GitHub Actions, testes unitários, TDD, BDD, VCR, JMeter.
- **Introdução à Lógica** (Redes) — algoritmos e Python.
- **TCC1** (CC) — planejamento, execução, documentação e apresentação.

**2026.2** (início 03/08 → 11/12, cronograma por semana ISO 32–50)
- **Qualidade de Software** (TADS) — 17 aulas com slides e materiais, usando Foot Fanatics como case de aula e Organização de Recursos como projeto avaliado. JUnit na semana 38, WireMock na 39 e prova escrita na 40; entrega na 46 e prova oral na 47.
- **TCC2** (CC) — desenvolvimento, entrega parcial (semana 38), depósito (semana 48) e apresentação (semana 50).

**2025.2** — placeholders (Testes de Software, TCC2, Lógica da Computação).

## Rodando localmente

Servidor estático, sem build:

```bash
python3 -m http.server 8000
# http://localhost:8000
```

## Testes

Jest cobre estrutura de slides, links internos/externos, logo Senac e consistência do `materialMap` das homes.

```bash
npm install
npm test
```

Os testes críticos pra alterações no cronograma são `tests/home-cards.test.js` e `tests/links-internos.test.js`.

A consistência de semanas, marcos e materiais de 2026.2 é verificada por `tests/cronograma-2026-2.test.js`. Testes de mídia e links externos precisam de rede; falhas de DNS não confirmam que a URL está quebrada.

Para capturar um deck inteiro e verificar overflow (os dois argumentos são obrigatórios):

```bash
npm run capture -- pages/qualidade2/slide_wiremock-api-seguras.html .tmp/shots-wiremock 1280 720
```

## Quizzes e integrações

O frontend é estático; os quizzes ao vivo usam RPCs e Realtime do Supabase. Páginas em `pages/qualidade2/quiz/`, instalação SQL e operação em [supabase/README.md](supabase/README.md). Os quizzes cadastrados são das aulas 04 e 05, semanas 35 e 36.

`scripts/discord-*.js` são ferramentas locais de administração e envio de mensagens, com scripts `discord:check`, `discord:post`, `discord:channel` e `discord:welcome` no `package.json`. Consulte o cabeçalho de uso de cada arquivo antes de operar; não fazem parte dos testes nem executam no site. `discord:post` trata texto livre como mensagem, inclusive `--help`.

Ao reorganizar aulas, atualize a home, `config/semestres.json`, os resumos dos slides, os materiais e a tabela do projeto. Confira também quizzes e seeds quando suas aulas forem afetadas. As páginas são escritas à mão: o config não atualiza o HTML automaticamente.

## Design system

Toda regra visual (paleta por disciplina, tipografia, variantes de card das homes, padrão de slides, ícones) vive em [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md).

## Agentes (Claude Code)

Em `.claude/agents/`:

- **`slide-builder`** — cria e edita slides HTML (`pages/<slug>/slide_*.html`) e materiais. Detecta disciplina pelo path (inclui `tcc2`), usa paleta do config, valida com Playwright.
- **`home-builder`** — edita o seletor de semestre (`index.html`) e as homes (`pages/home_*.html`). Mantém variantes de card, marcos, `materialMap`, a estrutura multi-semestre e os testes consistentes.

> Os agentes consomem `config/semestres.json`, `config/disciplina-<slug>.json` e `DESIGN_SYSTEM.md`. (Os agentes do framework AIOX em `.github/agents/` e `.aiox-core/` são personas genéricas de dev — não dependem da estrutura de disciplinas.)

## Commits

Convenção: `feat:`, `fix:`, `refactor:`, `chore:`. Um commit por unidade de ensino ou mudança de infra.

## Autor

Professor Afonso — SENAC (TADS, Redes de Computadores, Ciência da Computação).
