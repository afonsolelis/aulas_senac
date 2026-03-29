# Repository Guidelines

## Project Structure & Module Organization
This repository is a static teaching hub. Root files such as `index.html` and `sources.json` drive the main entry points and shared media references. Shared frontend assets live in `css/`, `js/`, `assets/`, and `config/`. Course content is organized under `pages/` by discipline: `pages/qualidade/`, `pages/logica/`, and `pages/tcc/`, with matching `material/` subfolders for written lesson notes. Tests are split between `tests/` for site-wide checks and `specs/` for stricter content rules such as slide structure and Cloudinary asset validation.

## Build, Test, and Development Commands
There is no build step for the site itself; files are served as static HTML.

- `npm test`: runs the full Jest suite.
- `npm run test:watch`: reruns tests during local editing.
- `npm run test:coverage`: generates coverage output for the Jest suite.
- `python3 -m http.server 8000`: quick local preview from the repository root.

Run tests after editing slides, home pages, shared CSS/JS, or `sources.json`.

## Coding Style & Naming Conventions
Follow the existing style: 2-space indentation in JavaScript, semicolons enabled, and single quotes by default. Keep HTML, CSS, and JSON formatted consistently with nearby files. Use descriptive lowercase file names with hyphenated or compact lesson slugs already established in the repo, for example `pages/qualidade/slide_jest.html` and `pages/logica/material/material_aula08-loops-funcoes.html`. Preserve shared IDs and classes from `config/standards.json` and `js/standard_slides.js` when editing slide navigation.

## Testing Guidelines
Jest is configured in `package.json` and picks up `tests/**/*.test.js` plus `specs/**/*.spec.js`. Add or update tests when changing navigation, footer controls, internal links, Senac branding, or slide structure. New tests should follow the existing naming pattern, such as `tests/external-links.test.js` or `specs/slide-structure.spec.js`.

## Commit & Pull Request Guidelines
Recent history is mixed, but contributors should prefer short, imperative Conventional Commit prefixes such as `feat:`, `fix:`, `refactor:`, and `chore:`. Keep each commit scoped to one teaching unit or one infrastructure change. Pull requests should explain what changed, list affected paths or disciplines, reference related issues when applicable, and include screenshots for visible HTML/CSS updates.
