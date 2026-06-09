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
│   ├── disciplina-<slug>.json      # tokens por disciplina (qualidade, logica, tcc, tcc2)
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
- **Qualidade de Software** (TADS) — em construção.
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
