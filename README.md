# Hub de Aulas Senac

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?logo=html5&logoColor=white)
![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3-7952B3?logo=bootstrap&logoColor=white)

Site estático que centraliza as aulas das disciplinas que leciono no SENAC. Cada disciplina tem seu próprio cronograma, slides e materiais de apoio.

## Estrutura

```
aulas_senac/
├── index.html                      # Hub principal
├── pages/
│   ├── home_qualidade.html         # Cronograma — Qualidade de Software
│   ├── home_logica.html            # Cronograma — Introdução à Lógica
│   ├── home_tcc.html               # Cronograma — TCC
│   ├── professor.html
│   ├── qualidade/                  # slides + material/ de Qualidade
│   ├── logica/                     # slides + material/ de Lógica
│   └── tcc/                        # slides + material/ de TCC
├── css/                            # style.css, slides.css, base-styles.css
├── js/standard_slides.js           # navegação prev/next/fullscreen/progress
├── config/
│   ├── disciplina-<slug>.json      # tokens por disciplina
│   └── standards.json              # padrão estrutural de slides
├── scripts/capture-slides.mjs      # validação visual (Playwright)
├── tests/ + specs/                 # Jest
└── DESIGN_SYSTEM.md                # fonte da verdade do design
```

## Disciplinas

- **Qualidade de Software** (TADS) — GitHub Actions, testes unitários, TDD, BDD, VCR, JMeter.
- **Introdução à Lógica** (Redes) — algoritmos e Python.
- **TCC** (CC) — planejamento, execução, documentação e apresentação.

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

- **`slide-builder`** — cria e edita slides HTML (`pages/<slug>/slide_*.html`). Detecta disciplina pelo path, usa paleta do config, valida com Playwright.
- **`home-builder`** — edita cronogramas (`pages/home_<slug>.html`). Mantém variantes de card, `materialMap` e testes consistentes.

## Commits

Convenção: `feat:`, `fix:`, `refactor:`, `chore:`. Um commit por unidade de ensino ou mudança de infra.

## Autor

Professor Afonso — SENAC (TADS, Redes de Computadores, Ciência da Computação).
