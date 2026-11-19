/* =====================================================================
   Hub de Aulas Senac — laboratórios simulados dentro dos slides
   (portado dos decks de Red Team & Blue Team, adaptado ao standard_slides.js)
   ---------------------------------------------------------------------
   Labs.register(alvo, init)  laboratório próprio: init(el) roda na 1ª
                              entrada do slide e pode devolver {enter, leave}
   Labs.vscode(alvo, cfg)     VS Code com explorador, abas, realce de sintaxe,
                              digitação ao vivo e terminal integrado. Ocupa o
                              slide inteiro (cfg.full: false desliga); o roteiro
                              (.lab-side) abre com a tecla G ou o botão Roteiro.
                              cfg.setup: [{cmd, out, file}] vira "Preparar o ambiente";
                              cfg.run: [{label, cmd, out, file, kind, clear, prompt, branch}] vira um botão por execução.
   Labs.terminal(alvo, cfg)   terminal roteirizado, passo a passo
   Labs.browser(alvo, cfg)    janela de navegador com página arbitrária
   Labs.flow(alvo, cfg)       diagrama animado por etapas
   Labs.video(alvo, cfg)      "vídeo" simulado: cenas de navegador com cursor,
                              cliques e digitação que tocam sozinhas, como um GIF
   Labs.highlight(code, lang) realce (js, json, yaml, bash, sql, gherkin, md, text)
   Tudo é simulado: nenhum comando é executado de verdade.
   ===================================================================== */
(function () {
  'use strict';

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const $ = (sel, root) => (typeof sel === 'string' ? (root || document).querySelector(sel) : sel);
  const h = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };

  /* ------------------------------------------------------------------
     Ciclo de vida: o standard_slides.js dispara "slide-change" na janela.
     O laboratório inicia na primeira entrada do slide e pausa ao sair.
     ------------------------------------------------------------------ */
  const boxes = [];
  window.addEventListener('slide-change', (ev) => {
    const atual = ev.detail && ev.detail.slide;
    boxes.forEach((b) => (b.slide === atual ? b.enter() : b.active && b.leave()));
  });
  function register(sel, init) {
    const el = $(sel);
    if (!el) { console.warn('[Labs] alvo não encontrado:', sel); return null; }
    const slide = el.closest('.slide');
    const box = { ctl: null, active: false, slide };
    box.enter = () => {
      if (box.active) return;
      box.active = true;
      if (!box.ctl) { try { box.ctl = init(el) || {}; } catch (e) { console.error('[Labs]', e); box.ctl = {}; } }
      box.ctl.enter && box.ctl.enter();
    };
    box.leave = () => { box.active = false; box.ctl && box.ctl.leave && box.ctl.leave(); };
    boxes.push(box);
    if (!slide || slide.classList.contains('active')) box.enter();
    return box;
  }

  /* ------------------------------------------------------------------
     Realce de sintaxe (por linha)
     ------------------------------------------------------------------ */
  const words = (s) => new Set(s.split(/\s+/).filter(Boolean));
  const STR = String.raw`"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'`;
  const NUM = String.raw`\b\d+(?:\.\d+)?%?`;
  const LANGS = {
    python: { c: '#.*$', kw: words('def class return if elif else for while in not and or import from as with try except finally raise lambda yield pass break continue is async await global assert'), bi: words('print len range dict list set tuple int float str sorted sum min max open enumerate zip any all round abs isinstance map filter json re datetime timedelta Counter defaultdict math hashlib csv Path'), k2: words('None True False self'), extra: String.raw`@[\w.]+` },
    yaml: { c: '#.*$', yk: true, kw: words(''), bi: words(''), k2: words('true false null yes no') },
    json: { jk: true, kw: words(''), bi: words(''), k2: words('true false null') },
    bash: { c: '#.*$', vars: true, kw: words('if then fi for do done while case esac function return in else elif'), bi: words('sudo cd ls cat grep awk sed echo export curl jq python3 python git docker systemctl journalctl tail head wc sort uniq find chmod whois dig host nslookup openssl ssh ping traceroute nmap tcpdump zeek suricata yara sigma auditctl ausearch'), k2: words('') },
    ps: { c: '#.*$', vars: true, ps: true, kw: words('if else foreach function return param in'), bi: words(''), k2: words('$true $false $null') },
    sql: { c: '--.*$', ci: true, kw: words('SELECT FROM WHERE GROUP BY ORDER HAVING JOIN LEFT RIGHT INNER OUTER ON AS AND OR NOT IN DISTINCT LIMIT CASE WHEN THEN ELSE END WITH DESC ASC BETWEEN LIKE IS NULL UNION ALL OVER PARTITION INSERT INTO VALUES CREATE TABLE PRIMARY KEY FOREIGN REFERENCES UNIQUE CHECK CONSTRAINT EXCLUDE USING INDEX ALTER DROP ADD COLUMN DEFAULT UPDATE DELETE SET BEGIN COMMIT ROLLBACK TRUNCATE CASCADE RESTRICT RETURNING IF EXISTS CONFLICT DO NOTHING'), bi: words('COUNT SUM AVG MIN MAX ROUND COALESCE DATE_TRUNC NOW INTERVAL LAG SERIAL BIGSERIAL INT INTEGER BIGINT TEXT VARCHAR CHAR BOOLEAN DATE TIMESTAMPTZ NUMERIC TSTZRANGE GIST'), k2: words('') },
    kql: { c: '//.*$', kw: words('where project summarize by extend join on let sort order take top render union parse kind asc desc and or not in between'), bi: words('count dcount countif sum avg min max bin ago now datetime timespan make_set make_list has contains startswith endswith strcat tostring toint arg_max distinct iff isnotempty'), k2: words('true false') },
    spl: { c: '`.*?`', kw: words('index sourcetype source host search where by as AND OR NOT OVER'), bi: words('stats count dc values earliest latest eval table sort head tail tstats rename dedup timechart bin span transaction lookup iplocation if case round'), k2: words('') },
    js: { c: '//.*$', kw: words('const let var function return if else for of in new class import from export await async while switch case break default try catch throw typeof extends static get set'), bi: words('console Math JSON Date Object Array Promise setTimeout document window process assert describe it test before after beforeEach afterEach mock expect fetch Error Number String Map Set URL AbortSignal'), k2: words('true false null undefined this') },
    gherkin: { c: '#.*$', kw: words(''), bi: words(''), k2: words(''), extra: String.raw`^\s*(?:Funcionalidade|Esquema do Cenário|Cenário|Contexto|Exemplos|Dado|Quando|Então|E|Mas)(?=[:\s])|<[\w ]+>|@[\w-]+|\|` },
    md: { c: '^#.*$', kw: words(''), bi: words(''), k2: words(''), extra: String.raw`\x60[^\x60]+\x60|^\s*[-*] |\*\*[^*]+\*\*` },
    text: { kw: words(''), bi: words(''), k2: words('') }
  };
  LANGS.feature = LANGS.gherkin; LANGS.markdown = LANGS.md; LANGS.py = LANGS.python; LANGS.yml = LANGS.yaml; LANGS.sh = LANGS.bash; LANGS.powershell = LANGS.ps; LANGS.sigma = LANGS.yaml;
  for (const k in LANGS) {
    const L = LANGS[k]; if (L.re) continue;
    const parts = [];
    if (L.c) parts.push('(?<c>' + L.c + ')');
    if (L.yk) parts.push(String.raw`(?<yk>^\s*-?\s*[\w.\-/|]+(?=\s*:(?:\s|$)))`);
    if (L.jk) parts.push(String.raw`(?<jk>"(?:[^"\\]|\\.)*"(?=\s*:))`);
    parts.push('(?<s>' + STR + ')');
    if (L.vars) parts.push(String.raw`(?<v>\$\{[^}]+\}|\$[\w:]+)`);
    if (L.ps) parts.push(String.raw`(?<f2>\b[A-Z][a-zA-Z]+-[A-Z][A-Za-z]+\b)|(?<v2>(?<=\s)-[A-Za-z]\w*)`);
    if (L.extra) parts.push('(?<d>' + L.extra + ')');
    parts.push('(?<n>' + NUM + ')');
    parts.push(String.raw`(?<w>[A-Za-z_][\w]*)`);
    L.re = new RegExp(parts.join('|'), 'g');
  }
  function hlLine(line, L) {
    let out = '', last = 0, m;
    L.re.lastIndex = 0;
    while ((m = L.re.exec(line))) {
      if (!m[0].length) { L.re.lastIndex++; continue; }
      out += esc(line.slice(last, m.index));
      const g = m.groups, t = m[0];
      let cls = '';
      if (g.c) cls = 'c'; else if (g.yk || g.jk) cls = 'v'; else if (g.s) cls = 's'; else if (g.v || g.v2) cls = 'v';
      else if (g.f2) cls = 'f'; else if (g.d) cls = 'd'; else if (g.n) cls = 'n';
      else if (g.w) {
        const w = L.ci ? t.toUpperCase() : t;
        if (L.kw.has(w)) cls = 'k'; else if (L.k2.has(t)) cls = 'p'; else if (L.bi.has(w)) cls = 'b';
        else if (/^\s*\(/.test(line.slice(L.re.lastIndex))) cls = 'f';
      }
      out += cls ? '<span class="tk-' + cls + '">' + esc(t) + '</span>' : esc(t);
      last = L.re.lastIndex;
    }
    return out + esc(line.slice(last));
  }
  function highlight(code, lang) {
    const L = LANGS[lang] || LANGS.text;
    return String(code).split('\n').map((l) => hlLine(l, L));
  }
  const EXT = { py: 'python', yml: 'yaml', yaml: 'yaml', json: 'json', sh: 'bash', ps1: 'ps', sql: 'sql', kql: 'kql', spl: 'spl', js: 'js', mjs: 'js', cjs: 'js', feature: 'gherkin', md: 'md', gitignore: 'bash', dockerfile: 'bash', txt: 'text', csv: 'text', log: 'text', conf: 'bash', toml: 'bash', rules: 'bash', env: 'bash' };
  const ICO = { python: ['py', '#4B8BBE'], yaml: ['!', '#CB171E'], json: ['{}', '#F2CB0A'], bash: ['$', '#89E051'], ps: ['>_', '#5391FE'], sql: ['db', '#E38C00'], kql: ['K', '#00B1D2'], spl: ['S', '#65A637'], js: ['JS', '#F7DF1E'], gherkin: ['🥒', '#5DAA2B'], md: ['M↓', '#519ABA'], text: ['≡', '#9DA5B4'] };
  const langOf = (f) => f.lang || EXT[(f.path.split('.').pop() || '').toLowerCase()] || 'text';

  /* Saída: "[ok] texto", "[warn]", "[err]", "[info]", "[mute]", "[hi]", "[red]", "[blue]", "[purple]" ou {t, c, d} */
  function outLine(line) {
    let t = line, c = '', d = null;
    if (line && typeof line === 'object') { t = line.t || ''; c = line.c || ''; d = line.d; }
    if (!c) { const m = /^\[(ok|warn|err|info|mute|hi|red|blue|purple)\]\s?/.exec(t || ''); if (m) { c = m[1]; t = t.slice(m[0].length); } }
    return { html: c ? '<span class="o-' + c + '">' + esc(t) + '</span>' : esc(t), d };
  }
  async function stream(target, lines, scroller, token, speed) {
    for (const l of lines) {
      if (token && token.cancel) return;
      const o = outLine(l);
      target.insertAdjacentHTML('beforeend', o.html + '\n');
      scroller.scrollTop = scroller.scrollHeight;
      await sleep(o.d != null ? o.d : (speed || 45));
    }
  }

  /* ------------------------------------------------------------------
     VS Code
     ------------------------------------------------------------------ */
  function vscode(sel, cfg) {
    return register(sel, (el) => {
      const theme = cfg.team ? ' ' + cfg.team + '-team' : '';
      const root = h('div', 'vsc' + theme);
      root.innerHTML =
        '<div class="vsc-title"><i></i><i></i><i></i><span>' + esc(cfg.title || (cfg.folder || 'lab') + ' — Visual Studio Code') + '</span></div>' +
        '<div class="vsc-body"><div class="vsc-activity"><b></b><b></b><b></b><b></b></div>' +
        '<div class="vsc-explorer"><h4>EXPLORADOR</h4><div class="vsc-folder">▾ ' + esc(cfg.folder || 'lab') + '</div><div class="vsc-tree"></div></div>' +
        '<div class="vsc-main"><div class="vsc-tabs"></div><div class="vsc-crumbs"></div><div class="vsc-editor"><pre class="vsc-code"></pre></div>' +
        '<div class="vsc-panel"><div class="vsc-panel-tabs"><span>PROBLEMAS</span><span>SAÍDA</span><span class="on">TERMINAL</span><span class="sp"></span></div><div class="vsc-term"></div></div></div></div>' +
        '<div class="vsc-status"><span>⎇ ' + esc(cfg.branch || 'main') + '</span><span>' + esc(cfg.status || '') + '</span><span class="sp"></span><button type="button" class="vsc-guia" title="Mostrar ou esconder o roteiro do laboratório (tecla G)">☰ Roteiro</button><span class="vsc-lang"></span><span>UTF-8</span><span>LF</span></div>';
      el.appendChild(root);
      // Tela cheia: o VS Code ocupa o slide inteiro; o roteiro (Objetivo, Faça, Observe, Conclusão)
      // vira um painel sobreposto, aberto pelo botão "Roteiro" da barra de status ou pela tecla G.
      const slideEl = el.closest('.slide');
      const guia = root.querySelector('.vsc-guia');
      if (slideEl && cfg.full !== false) {
        slideEl.classList.add('vsc-full');
        const alterna = () => slideEl.classList.toggle('show-side');
        guia.addEventListener('click', alterna);
        document.addEventListener('keydown', (e) => {
          if ((e.key === 'g' || e.key === 'G') && slideEl.classList.contains('active') && !e.ctrlKey && !e.metaKey && !e.altKey && !/^(INPUT|TEXTAREA|SELECT)$/.test((e.target.tagName || ''))) alterna();
        });
        if (!slideEl.querySelector('.lab-side')) guia.remove();
      } else guia.remove();
      const tree = root.querySelector('.vsc-tree'), tabs = root.querySelector('.vsc-tabs'), crumbs = root.querySelector('.vsc-crumbs');
      const codeEl = root.querySelector('.vsc-code'), editor = root.querySelector('.vsc-editor'), term = root.querySelector('.vsc-term');
      const ptabs = root.querySelector('.vsc-panel-tabs'), langEl = root.querySelector('.vsc-lang');
      if (cfg.panelHeight) root.querySelector('.vsc-panel').style.flexBasis = cfg.panelHeight;
      const files = cfg.files || [];
      const opened = [];
      let current = null, typing = null;

      // árvore de arquivos
      let lastDirs = [];
      files.slice().sort((a, b) => a.path.localeCompare(b.path)).forEach((f) => {
        const parts = f.path.split('/'); const dirs = parts.slice(0, -1);
        dirs.forEach((d, k) => {
          if (lastDirs[k] !== d) { const b = h('div', 'vsc-file', '▾ ' + esc(d)); b.style.setProperty('--depth', k); b.style.fontWeight = 600; tree.appendChild(b); lastDirs = dirs.slice(0, k + 1); }
        });
        lastDirs = dirs;
        const lang = langOf(f), ic = ICO[lang] || ICO.text;
        const b = h('button', 'vsc-file', esc(parts[parts.length - 1]));
        b.dataset.ico = ic[0]; b.style.setProperty('--ico', ic[1]); b.style.setProperty('--depth', dirs.length);
        b.addEventListener('click', () => open(f.path));
        f._btn = b; tree.appendChild(b);
      });

      function render(f, upto) {
        const lines = highlight(upto == null ? f.code : f.code.slice(0, upto), langOf(f));
        const hl = new Set(f.hl || []);
        codeEl.innerHTML = lines.map((l, k) => '<span class="ln' + (hl.has(k + 1) && upto == null ? ' hl' : '') + '">' + (l || ' ') + (upto != null && k === lines.length - 1 ? '<span class="caret"></span>' : '') + '</span>').join('');
      }
      function drawTabs() {
        tabs.innerHTML = '';
        opened.forEach((p) => {
          const f = files.find((x) => x.path === p); const ic = ICO[langOf(f)] || ICO.text;
          const t = h('button', 'vsc-tab' + (p === current.path ? ' is-active' : ''), '<span style="color:' + ic[1] + ';font-weight:700;font-size:10px">' + esc(ic[0]) + '</span> ' + esc(p.split('/').pop()));
          t.addEventListener('click', () => open(p)); tabs.appendChild(t);
        });
      }
      function open(path) {
        const f = files.find((x) => x.path === path); if (!f) return;
        if (typing) typing.cancel = true;
        current = f;
        if (!opened.includes(path)) opened.push(path);
        files.forEach((x) => x._btn && x._btn.classList.toggle('is-open', x === f));
        drawTabs();
        crumbs.textContent = (cfg.folder || 'lab') + ' › ' + path.split('/').join(' › ');
        langEl.textContent = { python: 'Python', yaml: 'YAML', json: 'JSON', bash: 'Shell Script', ps: 'PowerShell', sql: 'SQL', kql: 'KQL', spl: 'SPL', js: 'JavaScript', gherkin: 'Gherkin', md: 'Markdown', text: 'Texto sem formatação' }[langOf(f)] || '';
        render(f); editor.scrollTop = 0;
        if (f.scrollTo) editor.scrollTop = Math.max(0, (f.scrollTo - 3) * 21.7);
      }
      async function typeOut(f) {
        if (typing) typing.cancel = true;
        const tok = typing = { cancel: false };
        const total = f.code.length; const steps = Math.min(140, total);
        for (let s = 1; s <= steps; s++) {
          if (tok.cancel) return;
          render(f, Math.round(total * s / steps)); editor.scrollTop = editor.scrollHeight;
          await sleep(cfg.typeDelay || 28);
        }
        render(f); typing = null;
      }
      let prompt = cfg.prompt || (cfg.shell === 'pwsh' ? 'PS C:\\lab\\' + (cfg.folder || 'lab') + '> ' : 'aluno@lab:~/' + (cfg.folder || 'lab') + '$ ');
      let running = null;
      async function exec(cmd, out, speed) {
        // reaproveita o prompt que ficou no fim do terminal (execuções com clear: false)
        const ult = term.lastChild;
        const jaTemPrompt = ult && ult.nodeType === 1 && ult.classList.contains('o-ok') && ult.textContent === prompt;
        if (!jaTemPrompt) term.insertAdjacentHTML('beforeend', '<span class="o-ok">' + esc(prompt) + '</span>');
        for (const ch of cmd) { term.insertAdjacentText('beforeend', ch); await sleep(14); }
        term.insertAdjacentText('beforeend', '\n'); term.scrollTop = term.scrollHeight; await sleep(250);
        const lines = typeof out === 'function' ? out() : (out || []);
        await stream(term, lines, term, running, speed);
      }
      const travar = (v) => ptabs.querySelectorAll('.lab-btn').forEach((b) => (b.disabled = v));
      async function run(k) {
        const r = cfg.run[k]; if (!r || running) return;
        running = { cancel: false };
        travar(true);
        if (r.file) open(r.file);
        if (r.clear !== false) term.innerHTML = '';
        await exec(r.cmd, r.out, r.speed);
        // r.prompt troca o prompt depois do comando (ex.: git switch); r.branch atualiza a barra de status
        if (r.prompt) prompt = r.prompt;
        if (r.branch) root.querySelector('.vsc-status span').textContent = '⎇ ' + r.branch;
        term.insertAdjacentHTML('beforeend', '<span class="o-ok">' + esc(prompt) + '</span>');
        travar(false);
        running = null;
        cfg.onRun && cfg.onRun(k, api);
      }
      // Preparação do ambiente: cfg.setup = [{ cmd, out, speed, file }], executados em sequência no
      // mesmo terminal (versão do interpretador, ambiente virtual, instalação de pacotes e programas).
      let pronto = false, bSetup = null;
      async function setup() {
        if (!cfg.setup || running) return;
        running = { cancel: false };
        travar(true);
        term.innerHTML = '';
        for (const st of cfg.setup) {
          if (st.file) open(st.file);
          await exec(st.cmd, st.out, st.speed);
          if (st.venv) prompt = '(' + (st.venv === true ? '.venv' : st.venv) + ') ' + prompt;   // ambiente virtual ativado
          if (st.prompt) prompt = st.prompt;
          await sleep(350);
        }
        term.insertAdjacentHTML('beforeend', '<span class="o-ok">' + esc(prompt) + '</span>');
        term.scrollTop = term.scrollHeight;
        travar(false);
        running = null; pronto = true;
        if (bSetup) { bSetup.classList.add('feito'); bSetup.textContent = '✓ ' + (cfg.setupLabel || 'Ambiente pronto'); }
      }
      if (cfg.setup && cfg.setup.length) {
        bSetup = h('button', 'lab-btn setup', '⬇ ' + esc(cfg.setupLabel || 'Preparar o ambiente'));
        bSetup.addEventListener('click', setup); ptabs.appendChild(bSetup);
      }
      (cfg.run || []).forEach((r, k) => {
        const b = h('button', 'lab-btn' + (r.kind ? ' ' + r.kind : ''), '▶ ' + esc(r.label || r.cmd));
        b.addEventListener('click', () => run(k)); ptabs.appendChild(b);
      });
      // Digitação manual simulada: desligada por padrão, porque nas aulas o código vem do agente.
      if (cfg.typing) {
        const bt = h('button', 'lab-btn ghost', '⌨ Digitar ao vivo');
        bt.addEventListener('click', () => current && typeOut(current)); ptabs.appendChild(bt);
      }
      term.innerHTML = cfg.intro ? cfg.intro.map((l) => outLine(l).html).join('\n') + '\n' : '';
      term.insertAdjacentHTML('beforeend', '<span class="o-ok">' + esc(prompt) + '</span>');
      open(cfg.open || (files[0] && files[0].path));
      let first = true;
      const api = {
        open, run, setup, term, get pronto() { return pronto; }, setCode(path, code) { const f = files.find((x) => x.path === path); if (f) { f.code = code; if (current === f) render(f); } },
        enter() { if (first && cfg.typeOnEnter && current) typeOut(current); first = false; },
        leave() { if (typing) typing.cancel = true; }
      };
      return api;
    });
  }

  /* ------------------------------------------------------------------
     Terminal roteirizado
     ------------------------------------------------------------------ */
  function terminal(sel, cfg) {
    return register(sel, (el) => {
      const root = h('div', 'term ' + (cfg.theme || ''));
      root.innerHTML = '<div class="term-bar"><i></i><i></i><i></i><span>' + esc(cfg.title || 'terminal') + '</span></div><div class="term-body"></div>' +
        '<div class="term-ctrl"><button class="lab-btn">▶ Próximo comando</button><button class="lab-btn ghost">⏭ Executar tudo</button><button class="lab-btn ghost">⟲ Reiniciar</button><span class="note"></span></div>';
      el.appendChild(root);
      const body = root.querySelector('.term-body'), note = root.querySelector('.note');
      const [bNext, bAll, bReset] = root.querySelectorAll('.term-ctrl button');
      let prompt = cfg.prompt || (cfg.theme === 'windows' ? 'PS C:\\Users\\analista> ' : 'analista@lab:~$ ');
      let k = 0, busy = false, tok = { cancel: false };
      function reset() {
        tok.cancel = true; tok = { cancel: false }; k = 0; busy = false;
        body.innerHTML = (cfg.intro || []).map((l) => outLine(l).html).join('\n') + (cfg.intro ? '\n' : '');
        body.insertAdjacentHTML('beforeend', '<span class="pr">' + esc(prompt) + '</span>');
        note.textContent = cfg.hint || 'Clique em "Próximo comando" para executar o roteiro passo a passo.';
        bNext.disabled = false;
      }
      async function step() {
        if (busy || k >= cfg.steps.length) return;
        busy = true; const s = cfg.steps[k++]; const my = tok;
        note.innerHTML = s.note ? esc(s.note) : '';
        const span = h('span', 'cm'); body.appendChild(span);
        const delay = Math.max(6, Math.min(30, 900 / (s.cmd.length || 1)));
        for (const ch of s.cmd) { if (my.cancel) return; span.textContent += ch; body.scrollTop = body.scrollHeight; await sleep(delay); }
        body.insertAdjacentText('beforeend', '\n'); await sleep(s.wait || 300);
        await stream(body, s.out || [], body, my, s.speed || cfg.speed);
        if (my.cancel) return;
        body.insertAdjacentHTML('beforeend', '<span class="pr">' + esc(s.prompt || prompt) + '</span>');
        body.scrollTop = body.scrollHeight;
        busy = false;
        if (k >= cfg.steps.length) { bNext.disabled = true; if (cfg.done) note.textContent = cfg.done; }
        cfg.onStep && cfg.onStep(k - 1);
      }
      async function all() { while (k < cfg.steps.length) { if (busy) { await sleep(120); continue; } await step(); } }
      bNext.addEventListener('click', step); bAll.addEventListener('click', all); bReset.addEventListener('click', reset);
      reset();
      return { step, reset, leave() {} };
    });
  }

  /* ------------------------------------------------------------------
     Navegador
     ------------------------------------------------------------------ */
  function browser(sel, cfg) {
    return register(sel, (el) => {
      const root = h('div', 'brw');
      root.innerHTML = '<div class="brw-bar"><i></i><i></i><i></i><div class="brw-url"><span class="lock"></span><span class="u"></span></div></div><div class="brw-page"></div>';
      el.appendChild(root);
      const page = root.querySelector('.brw-page'), url = root.querySelector('.brw-url');
      function go(u, html, secure) {
        url.querySelector('.u').textContent = u;
        url.querySelector('.lock').textContent = secure === false ? '⚠' : '🔒';
        url.classList.toggle('danger', secure === false);
        page.innerHTML = html; page.scrollTop = 0;
        cfg.onReady && cfg.onReady(page, api);
      }
      const api = { go, page };
      go(cfg.url || 'about:blank', cfg.html || '', cfg.secure);
      return api;
    });
  }

  /* ------------------------------------------------------------------
     Diagrama animado por etapas
     nodes: [{id, x, y, label, sub, icon, k, w, h}]  (x, y = centro)
     links: [{from, to, label, dashed, curve}]
     steps: [{title, text, on:[ids], bad:[ids], links:[[de, para, cor]], dim}]
     ------------------------------------------------------------------ */
  function flow(sel, cfg) {
    return register(sel, (el) => {
      const W = cfg.w || 1000, H = cfg.h || 480;
      const root = h('div', 'flow');
      root.innerHTML = '<div class="flow-stage"></div><div class="flow-cap"><button class="lab-btn ghost">◀</button><button class="lab-btn">▶ Avançar</button><button class="lab-btn ghost">⏯ Auto</button><div class="txt"></div><span class="cnt"></span></div>';
      el.appendChild(root);
      const stage = root.querySelector('.flow-stage'), txt = root.querySelector('.txt'), cnt = root.querySelector('.cnt');
      const [bPrev, bNext, bAuto] = root.querySelectorAll('.flow-cap button');
      const NS = 'http://www.w3.org/2000/svg';
      const svg = document.createElementNS(NS, 'svg');
      svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H); svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
      stage.appendChild(svg);
      const byId = {}; (cfg.nodes || []).forEach((n) => (byId[n.id] = n));
      const path = (a, b, curve) => {
        if (!curve) return 'M' + a.x + ',' + a.y + ' L' + b.x + ',' + b.y;
        const mx = (a.x + b.x) / 2 + curve, my = (a.y + b.y) / 2 - curve;
        return 'M' + a.x + ',' + a.y + ' Q' + mx + ',' + my + ' ' + b.x + ',' + b.y;
      };
      const linkEls = {};
      (cfg.links || []).forEach((l) => {
        const a = byId[l.from], b = byId[l.to]; if (!a || !b) return;
        const p = document.createElementNS(NS, 'path');
        p.setAttribute('d', path(a, b, l.curve)); p.setAttribute('class', 'flow-link' + (l.dashed ? ' dashed' : ''));
        svg.appendChild(p); linkEls[l.from + '>' + l.to] = p; linkEls[l.to + '>' + l.from] = linkEls[l.to + '>' + l.from] || p;
        if (l.label) {
          const t = document.createElementNS(NS, 'text'); t.setAttribute('class', 'flow-link-lbl');
          t.setAttribute('x', (a.x + b.x) / 2 + (l.dx || 0)); t.setAttribute('y', (a.y + b.y) / 2 - 6 + (l.dy || 0)); t.setAttribute('text-anchor', 'middle');
          t.textContent = l.label; svg.appendChild(t);
        }
      });
      const nodeEls = {};
      (cfg.nodes || []).forEach((n) => {
        const w = n.w || 170, hh = n.h || 66;
        const g = document.createElementNS(NS, 'g'); g.setAttribute('class', 'flow-node' + (n.k ? ' k-' + n.k : ''));
        g.innerHTML = '<rect x="' + (n.x - w / 2) + '" y="' + (n.y - hh / 2) + '" width="' + w + '" height="' + hh + '" rx="12"/>' +
          (n.icon ? '<text class="ico" x="' + (n.x - w / 2 + 14) + '" y="' + (n.y + 9) + '">' + esc(n.icon) + '</text>' : '') +
          '<text class="lbl" x="' + (n.x + (n.icon ? 16 : 0)) + '" y="' + (n.y + (n.sub ? -3 : 5)) + '" text-anchor="middle">' + esc(n.label) + '</text>' +
          (n.sub ? '<text class="sub" x="' + (n.x + (n.icon ? 16 : 0)) + '" y="' + (n.y + 15) + '" text-anchor="middle">' + esc(n.sub) + '</text>' : '');
        svg.appendChild(g); nodeEls[n.id] = g;
      });
      // pacotes passam por baixo dos nós: a camada fica entre as ligações e os nós
      const pktLayer = document.createElementNS(NS, 'g');
      const firstNode = svg.querySelector('.flow-node'); svg.insertBefore(pktLayer, firstNode);
      // Ajuste de texto: só dá para medir com o slide visível
      let fitted = false;
      function fit() {
        if (fitted) return;
        const probe = svg.querySelector('.flow-node .lbl');
        if (!probe || !probe.getBBox().width) return;
        fitted = true;
        const rects = [];
        (cfg.nodes || []).forEach((n) => {
          const w = n.w || 170, hh = n.h || 66, g = nodeEls[n.id];
          rects.push({ x0: n.x - w / 2, x1: n.x + w / 2, y0: n.y - hh / 2, y1: n.y + hh / 2 });
          const ico = g.querySelector('.ico');
          let left = n.x - w / 2 + 10;
          if (ico) { const ib = ico.getBBox(); left = ib.x + ib.width + 8; }
          const right = n.x + w / 2 - 10, avail = right - left, cx = (left + right) / 2;
          g.querySelectorAll('.lbl, .sub').forEach((tx) => {
            tx.setAttribute('x', cx);
            const bw = tx.getBBox().width;
            if (bw > avail) {
              const fs = parseFloat(getComputedStyle(tx).fontSize) || 14;
              tx.style.fontSize = Math.max(9, fs * avail / bw).toFixed(1) + 'px';
            }
          });
        });
        // rótulos das ligações: afasta dos nós
        svg.querySelectorAll('.flow-link-lbl').forEach((tx) => {
          for (let tries = 0; tries < 6; tries++) {
            const b = tx.getBBox();
            const hit = rects.some((r) => !(b.x + b.width < r.x0 - 2 || b.x > r.x1 + 2 || b.y + b.height < r.y0 - 2 || b.y > r.y1 + 2));
            if (!hit) break;
            tx.setAttribute('y', +tx.getAttribute('y') - 12);
          }
        });
      }
      let k = 0, pkts = [], raf = null, auto = null, active = false;
      function apply() {
        const s = (cfg.steps || [])[k] || {};
        const on = new Set(s.on || []), bad = new Set(s.bad || []);
        Object.entries(nodeEls).forEach(([id, g]) => {
          g.classList.toggle('is-on', on.has(id)); g.classList.toggle('is-bad', bad.has(id));
          g.classList.toggle('is-dim', !!s.dim && !on.has(id) && !bad.has(id));
        });
        Object.values(linkEls).forEach((p) => p.setAttribute('class', p.getAttribute('class').replace(/ is-on.*$/, '')));
        pktLayer.innerHTML = ''; pkts = [];
        (s.links || []).forEach(([a, b, c], j) => {
          const p = linkEls[a + '>' + b]; const A = byId[a], B = byId[b];
          if (p) p.setAttribute('class', p.getAttribute('class') + ' is-on ' + (c || ''));
          if (!A || !B) return;
          for (let q = 0; q < 2; q++) {
            const dot = document.createElementNS(NS, 'circle'); dot.setAttribute('r', 7); dot.setAttribute('class', 'flow-pkt ' + (c || ''));
            pktLayer.appendChild(dot);
            const l = (cfg.links || []).find((x) => (x.from === a && x.to === b) || (x.from === b && x.to === a));
            const L0 = l ? byId[l.from] : A, L1 = l ? byId[l.to] : B;
            pkts.push({ dot, L0, L1, curve: (l && l.curve) || 0, dir: !l || l.from === a ? 1 : -1, off: q * 0.5 + j * 0.13 });
          }
        });
        txt.innerHTML = (s.title ? '<b>' + esc(s.title) + '</b>' : '') + '<span>' + (s.text || '') + '</span>';
        cnt.textContent = (k + 1) + ' / ' + (cfg.steps || []).length;
        bPrev.disabled = k === 0; bNext.disabled = k >= (cfg.steps || []).length - 1;
        cfg.onStep && cfg.onStep(k, s);
      }
      function frame(t) {
        pkts.forEach((p) => {
          const u = ((t / 1600) + p.off) % 1;
          const uu = p.dir > 0 ? u : 1 - u, a0 = p.L0, b0 = p.L1;
          const mx = (a0.x + b0.x) / 2 + p.curve, my = (a0.y + b0.y) / 2 - p.curve;
          const x = (1 - uu) * (1 - uu) * a0.x + 2 * (1 - uu) * uu * mx + uu * uu * b0.x;
          const y = (1 - uu) * (1 - uu) * a0.y + 2 * (1 - uu) * uu * my + uu * uu * b0.y;
          p.dot.setAttribute('cx', x); p.dot.setAttribute('cy', y);
        });
        if (active) raf = requestAnimationFrame(frame);
      }
      const go = (n) => { k = Math.max(0, Math.min((cfg.steps || []).length - 1, n)); apply(); };
      bPrev.addEventListener('click', () => { stopAuto(); go(k - 1); });
      bNext.addEventListener('click', () => { stopAuto(); go(k + 1); });
      function stopAuto() { clearInterval(auto); auto = null; bAuto.classList.add('ghost'); }
      bAuto.addEventListener('click', () => {
        if (auto) return stopAuto();
        bAuto.classList.remove('ghost');
        auto = setInterval(() => { if (k >= (cfg.steps || []).length - 1) { if (cfg.loop === false) return stopAuto(); go(0); } else go(k + 1); }, cfg.interval || 3800);
      });
      apply();
      return {
        go, get step() { return k; },
        enter() { active = true; requestAnimationFrame(fit); cancelAnimationFrame(raf); raf = requestAnimationFrame(frame); },
        leave() { active = false; cancelAnimationFrame(raf); stopAuto(); }
      };
    });
  }

  /* ------------------------------------------------------------------
     Vídeo simulado (substitui um GIF gravado): uma sequência de cenas
     num navegador, com cursor que anda, clica e digita sozinho.
     cfg.scenes: [{ url, html, caption, steps: [ação…] }]
     ações: {to: sel} move o cursor · {click: sel} move e clica
            {type: sel, text} digita · {lines: sel, out: [...]} imprime linhas
            {show: sel} / {hide: sel} · {add: [sel, classe]} · {wait: ms}
     ------------------------------------------------------------------ */
  function video(sel, cfg) {
    return register(sel, (el) => {
      const root = h('div', 'vid');
      root.innerHTML = '<div class="brw vid-brw"><div class="brw-bar"><i></i><i></i><i></i><div class="brw-url"><span class="lock">🔒</span><span class="u"></span></div></div>' +
        '<div class="brw-page vid-page"></div><div class="vid-cursor" aria-hidden="true"></div></div>' +
        '<div class="vid-ctrl"><button type="button" class="lab-btn vid-play">⏸ Pausar</button><button type="button" class="lab-btn ghost vid-prev">⏮</button><button type="button" class="lab-btn ghost vid-next">⏭</button>' +
        '<div class="vid-bar"><i></i></div><span class="vid-cnt"></span></div><div class="vid-cap" aria-live="polite"></div>';
      el.appendChild(root);
      const page = root.querySelector('.vid-page'), url = root.querySelector('.u'), cur = root.querySelector('.vid-cursor');
      const frame = root.querySelector('.vid-brw'), cap = root.querySelector('.vid-cap'), cnt = root.querySelector('.vid-cnt');
      const bar = root.querySelector('.vid-bar i'), bPlay = root.querySelector('.vid-play');
      const scenes = cfg.scenes || [];
      let k = 0, tok = { cancel: false }, paused = false, active = false;
      const q = (s) => page.querySelector(s);
      async function wait(ms, my) {
        let t = 0;
        while (t < ms) { if (my.cancel) throw 0; await sleep(80); if (!paused) t += 80; }
      }
      function moveTo(s) {
        const alvo = q(s); if (!alvo) return;
        const fr = frame.getBoundingClientRect(), r = alvo.getBoundingClientRect();
        const z = parseFloat(getComputedStyle(root).zoom) || 1;
        alvo.scrollIntoView({ block: 'nearest' });
        cur.style.left = ((r.left - fr.left) / z + Math.min(r.width / z / 2, 60)) + 'px';
        cur.style.top = ((r.top - fr.top) / z + r.height / z / 2) + 'px';
      }
      async function play(n) {
        tok.cancel = true; const my = tok = { cancel: false };
        k = (n + scenes.length) % scenes.length;
        const sc = scenes[k];
        url.textContent = sc.url || '';
        page.innerHTML = sc.html || '';
        cap.innerHTML = sc.caption || '';
        cnt.textContent = (k + 1) + ' / ' + scenes.length;
        bar.style.width = ((k + 1) / scenes.length * 100) + '%';
        try {
          await wait(500, my);
          for (const a of sc.steps || []) {
            if (a.to) { moveTo(a.to); await wait(a.wait || 700, my); }
            else if (a.click) {
              moveTo(a.click); await wait(650, my);
              cur.classList.add('clk'); const alvo = q(a.click); if (alvo) alvo.classList.add('vid-hit');
              await wait(260, my); cur.classList.remove('clk');
              await wait(a.wait || 350, my);
            } else if (a.type) {
              const alvo = q(a.type); if (!alvo) continue;
              moveTo(a.type);
              for (const ch of a.text) { if (my.cancel) throw 0; alvo.textContent += ch; await wait(a.speed || 45, my); }
              await wait(a.wait || 400, my);
            } else if (a.lines) {
              const alvo = q(a.lines); if (!alvo) continue;
              for (const l of a.out || []) {
                const o = outLine(l); alvo.insertAdjacentHTML('beforeend', o.html + '\n'); alvo.scrollTop = alvo.scrollHeight;
                await wait(o.d != null ? o.d : (a.speed || 160), my);
              }
              await wait(a.wait || 300, my);
            } else if (a.show) { const x = q(a.show); if (x) x.hidden = false; await wait(a.wait || 500, my); }
            else if (a.hide) { const x = q(a.hide); if (x) x.hidden = true; await wait(a.wait || 200, my); }
            else if (a.add) { const x = q(a.add[0]); if (x) x.classList.add(a.add[1]); await wait(a.wait || 300, my); }
            else if (a.wait) await wait(a.wait, my);
          }
          await wait(sc.hold || 2200, my);
          if (active && (k < scenes.length - 1 || cfg.loop !== false)) play(k + 1);
        } catch (e) { if (e !== 0) console.error('[Labs.video]', e); }
      }
      bPlay.addEventListener('click', () => { paused = !paused; bPlay.textContent = paused ? '▶ Continuar' : '⏸ Pausar'; });
      root.querySelector('.vid-prev').addEventListener('click', () => play(k - 1));
      root.querySelector('.vid-next').addEventListener('click', () => play(k + 1));
      return {
        play,
        enter() { active = true; play(k); },
        leave() { active = false; tok.cancel = true; }
      };
    });
  }

  window.Labs = { register, vscode, terminal, browser, flow, video, highlight, sleep, esc, h };
})();
