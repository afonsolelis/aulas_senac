# QWEN.md - Project Context

## Project Overview

**Hub de Aulas Senac** is a static educational website for organizing and presenting course content for SENAC classes. The project provides a centralized hub connecting multiple disciplines with automatically generated HTML slide presentations for each lesson.

### Key Features
- Centralized hub interface connecting all courses
- Automatic HTML slide generation system
- Modern glassmorphism design with smooth gradients
- Fully responsive (mobile, tablet, desktop)
- Keyboard navigation for slides (arrow keys)
- 100% static site - no backend required

### Technologies
- **Frontend**: HTML5, CSS3, Bootstrap 5.3, Font Awesome 6.0
- **Testing**: Jest (JavaScript testing framework)
- **Media Hosting**: Cloudinary (for images and assets)
- **Languages**: Portuguese (content), English (technical)

## Disciplines (Courses)

| Discipline | Course | Slides | Topics |
|------------|--------|--------|--------|
| Qualidade de Software | TADS | 14 classes | Testing, QA, automation, GitHub Actions, TDD, BDD, JMeter |
| Introdução à Lógica | Redes de Computadores | 16 classes | Algorithms, Python, data structures, OOP |
| TCC1 (Trabalho de Conclusão) | Ciência da Computação | 16 weeks | Project planning, development, documentation |

## Project Structure

```
aulas_senac/
├── index.html                      # Main hub page
├── sources.json                    # Cloudinary image URLs
├── package.json                    # Node.js config (Jest testing)
├── .env.example                    # Environment variables template
├── README.md                       # Project documentation
│
├── css/
│   ├── style.css                   # Main styles (glassmorphism, gradients)
│   └── slides.css                  # Slide presentation styles
│
├── js/
│   └── standard_slides.js          # Slide navigation logic
│
├── pages/
│   ├── professor.html              # Professor profile page
│   ├── home_qualidade.html         # Quality Software discipline hub
│   ├── home_logica.html            # Logic discipline hub
│   ├── home_tcc.html               # TCC discipline hub
│   ├── qualidade/                  # Quality Software slides (14 files)
│   ├── logica/                     # Logic slides (16 files)
│   └── tcc/                        # TCC slides (16 files)
│
├── assets/                         # Local assets (images, PDFs)
│
├── tests/                          # Jest test files
│   ├── index.test.js
│   ├── home-cards.test.js
│   ├── external-links.test.js
│   └── ...
│
└── node_modules/                   # Dependencies
```

## Building and Running

### Prerequisites
- Node.js (for testing)
- Python 3.12+ (optional, for local server)
- Modern web browser

### Installation

```bash
# Install dependencies
npm install
```

### Running Locally

```bash
# Option 1: Python HTTP server
python3 -m http.server 8000

# Option 2: Any static file server
# Access at: http://localhost:8000
```

### Testing

```bash
# Run all tests
npm test

# Watch mode (auto-rerun on changes)
npm run test:watch

# With coverage report
npm run test:coverage
```

## Development Conventions

### File Naming
- **Slide files**: `slide_<topic-name>.html` (lowercase, hyphenated)
- **Home pages**: `home_<discipline>.html`
- **CSS**: Descriptive names (`style.css`, `slides.css`)

### HTML Structure
- All pages use Bootstrap 5.3 grid system
- Navbar with Senac logo (light theme)
- Hero section with discipline-specific gradient backgrounds
- Glass card styling for content containers
- Footer with copyright and Senac branding

### CSS Conventions
- **Gradients by discipline**:
  - `.bg-quality`: Red/Pink gradient (`#FF512F` → `#DD2476`)
  - `.bg-logic`: Blue/Cyan gradient (`#1fa2ff` → `#12d8fa` → `#a6ffcb`)
  - `.bg-tcc`: Purple/Orange gradient (`#833ab4` → `#fd1d1d` → `#fcb045`)
- **Font**: 'Outfit' (Google Fonts)
- **Glassmorphism**: `.glass-card` class with backdrop-filter

### JavaScript
- Vanilla JS (no frameworks)
- Slide navigation via `standard_slides.js`
- Keyboard support: `←` (prev), `→` (next), `F` (fullscreen)

### Testing Practices
- **Framework**: Jest with jsdom
- **Test files**: `*.test.js` in `/tests` directory
- **Coverage**: Tests verify HTML structure, links, and content
- **Test categories**:
  - `index.test.js` - Main page structure
  - `home-cards.test.js` - Discipline cards validation
  - `external-links.test.js` - External URL validation
  - `links-internos.test.js` - Internal link validation
  - `slides-footer.test.js` - Slide footer consistency

### Adding New Content

#### New Lesson Slide
1. Create slide file in `pages/<discipline>/slide_<topic>.html`
2. Follow the 5-slide template structure:
   - Slide 1: Cover (title, logo)
   - Slide 2: Agenda
   - Slide 3: Concepts
   - Slide 4: Deep dive
   - Slide 5: Conclusion/Q&A
3. Add link to discipline home page
4. Include navigation via `standard_slides.js`

#### New Discipline
1. Create `pages/home_<discipline>.html` based on existing templates
2. Create `pages/<discipline>/` folder for slides
3. Add card to `index.html` with appropriate gradient class
4. Update navigation links

### Media Assets (Cloudinary)
- Images hosted on Cloudinary CDN
- URLs stored in `sources.json`
- Upload script: `scripts/upload-to-cloudinary.js`
- Naming convention: `snake_case`, descriptive (e.g., `senac_logo_pb`, `banner_logica_aula01`)

### Environment Variables
- `.env` file for Cloudinary credentials (gitignored)
- Copy `.env.example` to `.env` and fill in values
- Used for media upload scripts

## Key Configuration Files

### package.json
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "jest-environment-jsdom": "^29.7.0",
    "@pollyjs/*": "^6.0.6"
  }
}
```

### Jest Configuration
- Test environment: `node`
- Test match patterns: `**/tests/**/*.test.js`, `**/specs/**/*.spec.js`

## Slide System Architecture

### Slide Template Structure
Each lesson has 5 slides generated from a template:
1. **Capa**: Title, logo, course info
2. **Agenda**: Topics list
3. **Conceitos**: Initial concepts
4. **Aprofundamento**: Technical deep dive
5. **Conclusão**: Summary and Q&A

### Navigation Controls
- Previous/Next buttons (disabled at boundaries)
- Progress bar indicator
- Slide counter (e.g., "3 / 5")
- Fullscreen toggle button
- Keyboard shortcuts

## Common Tasks

### Verify Links
```bash
npm test -- tests/external-links.test.js
npm test -- tests/links-internos.test.js
```

### Check Page Structure
```bash
npm test -- tests/index.test.js
npm test -- tests/home-cards.test.js
```

### Upload New Asset
```bash
# Copy .env.example to .env and configure Cloudinary credentials
node scripts/upload-to-cloudinary.js <file-path> <key-name>
```

## Notes
- The project is 100% static - can be hosted on GitHub Pages, Netlify, Vercel, etc.
- All content is in Portuguese (Brazilian)
- Academic year: 2026.1
- Author: Professor Afonso (SENAC)
