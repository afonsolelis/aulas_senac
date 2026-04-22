# Design System — Aulas Senac

Referência única do padrão visual das disciplinas. Fonte da verdade: este documento + `config/*.json` + `css/*.css`. Agentes (`.claude/agents/`) consomem este documento.

---

## 1. Tokens por disciplina

Cada disciplina tem um arquivo `config/disciplina-<slug>.json` com tokens canônicos. Nunca hardcode cor fora dessa paleta.

| Disciplina | Slug | Primary | Secondary | Accent | Cover gradient |
|---|---|---|---|---|---|
| Introdução à Lógica | `logica` | `#1fa2ff` | `#12d8fa` | `#a6ffcb` | `#0c4a6e → #1fa2ff → #a6ffcb` |
| Qualidade de Software | `qualidade` | `#DD2476` | `#FF512F` | `#ffb199` | `#5b0f2d → #DD2476 → #FF512F` |
| TCC | `tcc` | `#833ab4` | `#fd1d1d` | `#fcb045` | `#2b0a4a → #833ab4 → #fd1d1d → #fcb045` |

Os mesmos valores são replicados em `css/base-styles.css` como `--sl-primary|secondary|accent|cover-gradient|particles|text-on-cover`, seletados por `body[data-disciplina="<slug>"]`.

Cor associada a cursos (badge/hero/home):
- Qualidade → Bootstrap `text-danger` / `bg-quality` (gradiente laranja→rosa)
- Lógica → Bootstrap `text-info` / `bg-logic` (gradiente azul→verde)
- TCC → `bg-tcc` (roxo→vermelho→laranja)

## 2. Tipografia

- **Fonte:** `Outfit` (Google Fonts, pesos 300/400/600/700).
- Importada via `@import` em `css/style.css`. Nunca adicionar outra família.
- Body: `font-family: 'Outfit', sans-serif`.

## 3. Camadas de CSS

| Arquivo | Quando carrega | Responsabilidade |
|---|---|---|
| `css/style.css` | Toda página | Base do hub: body, navbar, cards de disciplina (`.bg-*`), `.glass-card`, footer global, botões customizados. |
| `css/slides.css` | Slides | Layout de deck: `.slide-body`, `.slide-container`, `.slide`, `.glass-cover`, `.slide-footer`, `.slide-controls`, `@keyframes fadeIn`. |
| `css/base-styles.css` | Slides modernizados (importar **depois** dos anteriores) | Camada de modernização: variáveis `--sl-*` por disciplina, `.cover-bg`, `.cover-particles`, reset `body.anime-ready`. |

## 4. Componentes — Homes de disciplina

As páginas `pages/home_<disciplina>.html` seguem um único layout: navbar → hero (`bg-<disciplina>`) → `.glass-card` contendo cronograma.

### 4.1 Hero da disciplina

```html
<header class="hero-section bg-<slug> d-flex align-items-center py-3" style="min-height: 12vh;">
  <div class="container">
    <div class="d-flex align-items-center justify-content-between">
      <div>
        <span class="badge bg-white text-<color> mb-1"><Curso></span>
        <h1 class="h3 fw-bold text-white mb-0"><Nome da disciplina></h1>
      </div>
      <p class="text-white-50 mb-0 small d-none d-md-block">2026.1</p>
    </div>
  </div>
</header>
```

### 4.2 Cards de aula — variantes

Todos os cards ficam dentro de `<div class="row g-3"> > <div class="col-12">` e usam `.list-group-item` com padding `p-3` e `shadow-sm`. A diferença entre variantes é borda + background + presença de link.

| Variante | Uso | Container | Classes-chave |
|---|---|---|---|
| **Aula normal** | Aula com slide + material | `<a href="<slide>">` | `list-group-item-action border border-light bg-white` |
| **Feriado** | Sem aula por feriado | `<div>` | `border border-warning bg-warning-subtle`, badge `bg-warning` com ícone `fa-umbrella-beach` |
| **Acompanhamento de Projeto** | Semana dedicada a acompanhamento (sem slide) | `<div>` | `border border-warning bg-warning-subtle`, badge `bg-warning`, título fixo "Acompanhamento de Projeto" |
| **Avaliação** | Prova/avaliação sem slide | `<div>` | `border border-danger bg-danger-subtle`, badge `bg-danger` com `fa-exclamation-circle` |
| **Entrega do Projeto** | Dia da entrega com botão de envio | `<div>` | `border border-danger bg-danger-subtle`, badge extra `bg-danger text-white` "Entrega do Projeto", botão `btn-danger btn-sm` com `fab fa-github` |

#### Skeleton — Aula normal

```html
<a href="<slug>/slide_<tema>.html"
  class="list-group-item list-group-item-action border border-light rounded shadow-sm p-3 h-100 d-flex flex-column bg-white">
  <div class="d-flex w-100 justify-content-between mb-2">
    <h5 class="mb-1 fw-bold text-dark"><Título da aula></h5>
    <span class="badge bg-light text-dark border fw-normal">
      <i class="far fa-calendar-alt me-1"></i> DD Mmm
    </span>
  </div>
  <p class="mb-1 text-muted small">Aula NN</p>
</a>
```

O link deve ter entrada correspondente no `materialMap` (bloco `<script>` no final da home) para que os botões "Ver slide" / "Ver material" sejam injetados dinamicamente.

#### Skeleton — Acompanhamento de Projeto

```html
<div class="list-group-item border border-warning rounded shadow-sm p-3 h-100 d-flex flex-column bg-warning-subtle">
  <div class="d-flex w-100 justify-content-between mb-2">
    <h5 class="mb-1 fw-bold text-dark">Acompanhamento de Projeto</h5>
    <span class="badge bg-warning text-dark border fw-normal">
      <i class="far fa-calendar-alt me-1"></i> DD Mmm
    </span>
  </div>
  <p class="mb-1 text-muted small">Aula NN</p>
</div>
```

#### Skeleton — Entrega do Projeto (com botão GitHub)

```html
<div class="list-group-item border border-danger rounded shadow-sm p-3 h-100 d-flex flex-column bg-danger-subtle">
  <div class="d-flex w-100 align-items-center mb-2 gap-2">
    <h5 class="mb-0 fw-bold text-dark">Entrega do Projeto Final</h5>
    <span class="badge bg-danger text-white border fw-normal">Entrega do Projeto</span>
    <div class="ms-auto d-flex gap-2 align-items-center">
      <a href="<URL do formulário>" target="_blank" class="btn btn-danger btn-sm">
        <i class="fab fa-github me-1"></i> Envio do link do GitHub do projeto
      </a>
      <span class="badge bg-danger text-white border fw-normal">
        <i class="far fa-calendar-alt me-1"></i> DD Mmm
      </span>
    </div>
  </div>
  <p class="mb-1 text-muted small">Aula NN</p>
</div>
```

### 4.3 `materialMap` (injeção de botões)

O script no fim de cada `home_*.html` mapeia `slide → material` e injeta botões "Ver slide" (cor da disciplina) + "Ver material" (`btn-primary`) nos cards de aula normal. Regras:

- **Sempre** adicionar entrada no `materialMap` ao criar uma aula nova.
- **Sempre** remover a entrada ao apagar um slide (o teste `tests/home-cards.test.js` quebra se ficar inconsistente).
- Cards `<div>` (feriado/avaliação/acompanhamento/entrega) são ignorados pelo script porque o seletor só pega `a.list-group-item`.

## 5. Componentes — Slides

Detalhes operacionais (CDN, partículas, animMap, validação Playwright) vivem em `.claude/agents/slide-builder.md`. Este documento apenas fixa o padrão visual:

- Decks usam `body.slide-body[data-disciplina="<slug>"]`.
- Primeiro e último slide: `.slide.cover-bg` com `<svg class="cover-particles">` e `.glass-cover` contendo o conteúdo principal.
- Slides de conteúdo: `.slide` com `.slide-content` centralizado (`max-width: 1000px`).
- Footer fixo (`.slide-footer`, 10vh) com 4 filhos: `.slide-controls`, texto central, link de material, logo Senac.
- Animação: **anime.js v4** via ESM CDN. Nunca v3.

## 6. Ícones

Font Awesome 6.0 via CDN. Padrões estabelecidos:

| Contexto | Ícone |
|---|---|
| Data | `far fa-calendar-alt` |
| Feriado | `fas fa-umbrella-beach` |
| Avaliação | `fas fa-exclamation-circle` |
| Entrega GitHub | `fab fa-github` |
| "Ver slide" | `fas fa-desktop` |
| "Ver material" | `fas fa-book` |
| "Voltar ao cronograma" | `fas fa-arrow-left` |

## 7. Ativos globais

- **Logo Senac:** `https://res.cloudinary.com/dyhjjms8y/image/upload/v1759512534/logo-SENAC_k3d68v.png` (hospedado no Cloudinary). Usado em `<link rel="icon">`, navbar e footer de toda página.
- **Favicon:** mesma URL do logo.
- Nunca adicionar imagem externa sem cadastrar em `sources.json`.

## 8. Regras invariantes

1. **Snake_case em nomes de arquivo** de slides e materiais (`slide_<tema>.html`, `material_aula<NN>-<tema>.html`).
2. **Nunca** hardcode cor fora das paletas de `config/disciplina-*.json`.
3. **Nunca** remover o badge de data dos cards de home — é o único marcador temporal visível.
4. **Sempre** manter `tests/home-cards.test.js` e `tests/links-internos.test.js` verdes ao editar homes.
5. **Sempre** validar slides modificados com `node scripts/capture-slides.mjs` (ver agente `slide-builder`).

## 9. Onde cada coisa mora

```
config/
  disciplina-<slug>.json   → tokens da disciplina (paleta, nome, paths)
  standards.json           → IDs/classes estruturais dos slides
css/
  style.css                → base do hub + cards de disciplina
  slides.css               → layout de deck (.slide, .slide-footer, ...)
  base-styles.css          → camada moderna (vars --sl-*, .cover-bg, particles)
js/
  standard_slides.js       → navegação (prev/next/fullscreen/progress)
.claude/agents/
  slide-builder.md         → criação/edição de slides
  home-builder.md          → cards das homes de disciplina
DESIGN_SYSTEM.md           → este documento
```
