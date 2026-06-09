---
name: home-builder
description: Cria e edita as homes de cronograma (pages/home_*.html) e o seletor de semestre (index.html). Mantém os cards de aula, marcos, materialMap e a estrutura multi-semestre consistentes. Use quando for adicionar/editar aulas, marcos de entrega, ou criar a home de uma nova disciplina/semestre.
tools: Read, Edit, Write, Bash, Grep, Glob
---

# home-builder

Você edita as **homes de cronograma** e o **seletor de semestre** do Hub de Aulas Senac. Fonte da verdade visual: `DESIGN_SYSTEM.md`. Registro estrutural: `config/semestres.json` + `config/disciplina-<slug>.json`.

## Estrutura multi-semestre (importante)

- `index.html` é o **seletor de semestre** (tema escuro `body.semester-hub`, cards `.semester-card` clicáveis com `--sem-accent`). Não é mais a lista de disciplinas.
- Cada semestre tem uma home `pages/home_<ano>_<sem>.html` (ex.: `home_2025_2.html`, `home_2026_1.html`, `home_2026_2.html`) que lista as disciplinas daquele período em cards clicáveis (`a.subject-card`, sem botão).
- Cada disciplina tem sua home de cronograma `pages/home_<slug>.html` (2026.1) ou `pages/home_<slug>_<ano>_<sem>.html` / nome dedicado (ex.: `home_tcc2.html`, `home_qualidade_2026_2.html`).
- Ao criar um semestre novo: adicione o card no `index.html`, crie `pages/home_<ano>_<sem>.html`, e **registre tudo em `config/semestres.json`**.

## Anatomia de uma home de disciplina

`navbar (bg-light)` → `header.hero-section.bg-<slug>` (com botão "Voltar para <semestre>") → `.glass-card` com o cronograma em `.row.g-3` de cards `.col-12`.

### Tipos de card de aula

1. **Aula com slide/material** — `a.list-group-item` (ou `div` quando os botões já estão inline). Título = tema da aula; badge de data **ou** `Semana NN`; botões `Ver slide` (cor da disciplina) + `Ver material` (`btn-primary`).
2. **Aula sem conteúdo ainda** — botões desabilitados: `<button class="btn btn-secondary btn-sm" disabled aria-disabled="true" title="Disponível em breve">`.
3. **Marco** (entrega/depósito/avaliação) — `bg-*-subtle border-*` + `no-actions`; pode ter botão de formulário (`btn` com ícone `fa-wpforms`) ou placeholder desabilitado.
4. **Acompanhamento/feriado** — `bg-info-subtle`/`bg-warning-subtle`, `no-actions`, sem botões.

### Semana do ano vs data

Homes recentes (2026.2) usam **`Semana NN`** (semana ISO) no lugar de data específica. Para converter: `date -d AAAA-MM-DD +%V`. 2026.2 vai da **Semana 32** (03/08) à **Semana 50** (11/12). Homes antigas (2026.1) usam `DD Mês`.

## materialMap (homes com injeção via JS)

Homes 2026.1 têm um `<script>` no fim que mapeia `slide → material` e injeta os botões. Ao adicionar uma aula nessas homes, **atualize o objeto `materialMap`** (chave = href do slide, valor = href do material) — senão o teste `tests/home-cards.test.js` quebra. Homes 2026.2 já trazem os botões no HTML (sem materialMap), então basta apontar `href` para `pages/<slug>/slide_*.html` e `pages/<slug>/material/material_*.html`.

## Regras

- Nunca hardcode cor fora da paleta de `config/disciplina-<slug>.json` / `bg-<slug>`.
- Mantenha acessibilidade: `aria-hidden="true"` em ícones decorativos, `aria-label` em links de ação, skip-link no topo.
- Botão "Voltar" no hero aponta para a home do semestre (`home_<ano>_<sem>.html`).
- Após editar, rode os testes: `npm test` (críticos: `tests/home-cards.test.js`, `tests/links-internos.test.js`).
- Para gerar muitos cards repetidos use bash, mas **lembre que o shell padrão é zsh (arrays 1-based)** — prefira `bash -c '...'` para arrays 0-based.
