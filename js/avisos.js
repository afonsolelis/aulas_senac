/* =====================================================================
   Quadro de avisos — botão flutuante presente em todas as páginas do Hub.

   Uma única tag <script src=".../js/avisos.js" defer> por página monta o
   botão, o painel, a leitura dos avisos e a área do professor. Não depende
   de Bootstrap, Font Awesome nem supabase-js: injeta o próprio CSS, desenha
   os ícones em SVG e fala com o Supabase por fetch nas RPCs.

   Backend: supabase/avisos-schema.sql. A chave publicável abaixo é pública
   por desenho — o que ela alcança é definido pela RLS, não pelo sigilo dela.
   A senha do professor NÃO está aqui: quem a confere é avisos_login, no
   servidor, que devolve um token de sessão de 12 h.

   Para omitir o botão numa página (ex.: painel de quiz projetado na sala),
   marque <body data-sem-avisos>.
   ===================================================================== */
(function () {
  'use strict';

  if (window.HubAvisos) return;

  var SUPABASE_URL = 'https://lwamaovuxcevsjfvtqhf.supabase.co';
  var SUPABASE_KEY = 'sb_publishable_j0O_u0t7-lDCtBbmqaIz3A_8vAIGcyJ';

  var CHAVE_SESSAO = 'hub:avisos:sessao';   // token do professor neste navegador
  var CHAVE_VISTO  = 'hub:avisos:visto';    // maior id já visto, para o contador
  var CHAVE_CACHE  = 'hub:avisos:cache';    // evita refetch ao navegar entre slides
  var CACHE_MS     = 60 * 1000;

  // Raiz do repositório, deduzida do src deste próprio script — funciona
  // igual em /index.html e em /pages/<slug>/material/<arquivo>.html.
  var script = document.currentScript ||
    (function () { var s = document.getElementsByTagName('script'); return s[s.length - 1]; })();
  var RAIZ = new URL('..', script.src).href;
  var PAGINA_QUADRO = RAIZ + 'pages/avisos.html';

  var ESCOPOS = [
    { valor: 'geral',      rotulo: 'Todas as turmas' },
    { valor: 'qualidade2', rotulo: 'Qualidade de Software (2026.2)' },
    { valor: 'tcc2',       rotulo: 'TCC2 (2026.2)' },
    { valor: 'qualidade',  rotulo: 'Qualidade de Software (2026.1)' },
    { valor: 'logica',     rotulo: 'Introdução à Lógica (2026.1)' },
    { valor: 'tcc',        rotulo: 'TCC1 (2026.1)' },
    { valor: 'turmas',     rotulo: 'Administrativo das turmas' }
  ];

  /* ---------------- utilidades ---------------- */

  function el(tag, attrs, filhos) {
    var n = document.createElement(tag);
    if (attrs) Object.keys(attrs).forEach(function (k) {
      if (k === 'class') n.className = attrs[k];
      else if (k === 'html') n.innerHTML = attrs[k];
      else if (k === 'text') n.textContent = attrs[k];
      else if (k.indexOf('on') === 0) n.addEventListener(k.slice(2), attrs[k]);
      else if (attrs[k] !== null && attrs[k] !== undefined) n.setAttribute(k, attrs[k]);
    });
    (filhos || []).forEach(function (f) { if (f) n.appendChild(f); });
    return n;
  }

  function escapar(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // O corpo é escrito pelo professor, mas é escapado assim mesmo: só links e
  // quebras de linha viram HTML.
  function corpoHtml(txt) {
    return escapar(txt)
      .replace(/(https?:\/\/[^\s<]+[^\s<.,;:!?)])/g,
               '<a href="$1" target="_blank" rel="noopener">$1</a>')
      .replace(/\n/g, '<br>');
  }

  function quando(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return '';
    var dia = 86400000;
    var hoje = new Date(); hoje.setHours(0, 0, 0, 0);
    var dela = new Date(d); dela.setHours(0, 0, 0, 0);
    var diff = Math.round((hoje - dela) / dia);
    var hora = d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    if (diff === 0) return 'hoje, ' + hora;
    if (diff === 1) return 'ontem, ' + hora;
    if (diff > 1 && diff < 7) return 'há ' + diff + ' dias';
    return d.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function rotuloEscopo(v) {
    for (var i = 0; i < ESCOPOS.length; i++) if (ESCOPOS[i].valor === v) return ESCOPOS[i].rotulo;
    return v;
  }

  function guardar(chave, valor) {
    try { localStorage.setItem(chave, valor); } catch (e) { /* modo privado */ }
  }
  function ler(chave) {
    try { return localStorage.getItem(chave); } catch (e) { return null; }
  }

  // Disciplina da página, para pedir ao servidor 'geral' + a dela.
  function escopoDaPagina() {
    if (document.body && document.body.dataset.avisosEscopo) {
      return document.body.dataset.avisosEscopo;
    }
    var p = location.pathname;
    var dir = p.match(/\/pages\/([a-z0-9_-]+)\//i);
    if (dir) return dir[1].toLowerCase();
    var home = p.match(/home_([a-z0-9]+)(?:_(\d{4})_(\d))?\.html/i);
    if (home && !/^\d/.test(home[1])) {
      var slug = home[1].toLowerCase();
      if (home[2] === '2026' && home[3] === '2' && slug === 'qualidade') return 'qualidade2';
      return slug;
    }
    return null;
  }

  async function rpc(fn, args) {
    var r = await fetch(SUPABASE_URL + '/rest/v1/rpc/' + fn, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_KEY,
        Authorization: 'Bearer ' + SUPABASE_KEY
      },
      body: JSON.stringify(args || {})
    });
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  }

  /* ---------------- estado ---------------- */

  var estado = {
    escopo: null,
    avisos: [],
    carregando: false,
    erro: null,
    sessao: null,        // { token, usuario, expira_em }
    doPainel: [],        // lista completa, visão do professor
    vista: 'lista',      // lista | login | professor
    editando: null,
    aberto: false,
    vistoRef: 0          // maior id lido ANTES desta abertura (destaca os novos)
  };

  try {
    var s = JSON.parse(ler(CHAVE_SESSAO) || 'null');
    if (s && s.token && new Date(s.expira_em) > new Date()) estado.sessao = s;
  } catch (e) { estado.sessao = null; }

  function naoLidos() {
    var visto = parseInt(ler(CHAVE_VISTO) || '0', 10) || 0;
    return estado.avisos.filter(function (a) { return a.id > visto; }).length;
  }

  function marcarLidos() {
    var maior = estado.avisos.reduce(function (m, a) { return Math.max(m, a.id); }, 0);
    if (maior) guardar(CHAVE_VISTO, String(maior));
  }

  /* ---------------- CSS ---------------- */

  var CSS = [
    ':root{--hbav-cor:#2c3e50;--hbav-acento:#DD2476}',
    '.hbav-fab{position:fixed;right:18px;bottom:18px;z-index:2147483000;',
    'width:56px;height:56px;border-radius:50%;border:none;cursor:pointer;',
    'background:linear-gradient(135deg,#2c3e50,#4ca1af);color:#fff;',
    'box-shadow:0 8px 24px rgba(15,32,39,.35);display:flex;align-items:center;',
    'justify-content:center;transition:transform .2s ease,box-shadow .2s ease;padding:0}',
    '.hbav-fab:hover{transform:translateY(-3px);box-shadow:0 12px 30px rgba(15,32,39,.45)}',
    '.hbav-fab:focus-visible{outline:3px solid #4ca1af;outline-offset:3px}',
    '.hbav-fab svg{width:24px;height:24px;fill:currentColor}',
    '.hbav-fab.hbav-oculto{display:none}',
    'body.slide-body .hbav-fab{bottom:calc(10vh + 14px)}',
    '.hbav-badge{position:absolute;top:-4px;right:-4px;min-width:22px;height:22px;',
    'border-radius:11px;background:#DD2476;color:#fff;font:700 12px/22px Outfit,system-ui,sans-serif;',
    'text-align:center;padding:0 6px;box-shadow:0 2px 6px rgba(0,0,0,.3)}',
    '.hbav-fundo{position:fixed;inset:0;z-index:2147483001;background:rgba(10,15,31,.45);',
    'backdrop-filter:blur(2px);opacity:0;transition:opacity .2s ease}',
    '.hbav-fundo.hbav-on{opacity:1}',
    '.hbav-painel{position:fixed;z-index:2147483002;right:0;top:0;bottom:0;width:min(420px,100vw);',
    'background:#fff;color:#2d3436;display:flex;flex-direction:column;',
    'font-family:Outfit,system-ui,-apple-system,sans-serif;box-shadow:-12px 0 40px rgba(0,0,0,.25);',
    'transform:translateX(100%);transition:transform .25s ease}',
    '.hbav-painel.hbav-on{transform:translateX(0)}',
    '@media (max-width:520px){.hbav-painel{width:100vw}}',
    '.hbav-cab{background:linear-gradient(135deg,#0f2027,#2c5364);color:#fff;padding:18px 20px;',
    'display:flex;align-items:center;gap:12px;flex:0 0 auto}',
    '.hbav-cab h2{margin:0;font-size:1.15rem;font-weight:700;flex:1;color:#fff}',
    '.hbav-cab p{margin:2px 0 0;font-size:.78rem;opacity:.75}',
    '.hbav-x{background:rgba(255,255,255,.12);border:none;color:#fff;width:34px;height:34px;',
    'border-radius:50%;cursor:pointer;font-size:1.1rem;line-height:1}',
    '.hbav-x:hover{background:rgba(255,255,255,.25)}',
    '.hbav-corpo{flex:1 1 auto;overflow-y:auto;padding:16px;background:#f8f9fa}',
    '.hbav-rodape{flex:0 0 auto;border-top:1px solid #e9ecef;padding:10px 16px;background:#fff;',
    'display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:.8rem}',
    '.hbav-rodape a{color:#4ca1af;text-decoration:none;font-weight:600}',
    '.hbav-rodape a:hover{text-decoration:underline}',
    '.hbav-aviso{background:#fff;border:1px solid #e9ecef;border-left:4px solid #4ca1af;',
    'border-radius:12px;padding:14px 16px;margin-bottom:12px;box-shadow:0 2px 10px rgba(15,32,39,.05)}',
    '.hbav-aviso.hbav-fixado{border-left-color:#DD2476;background:#fffdfa}',
    '.hbav-aviso.hbav-inativo{opacity:.55}',
    '.hbav-aviso h3{margin:0 0 6px;font-size:1rem;font-weight:700;color:#2d3436;line-height:1.35}',
    '.hbav-aviso .hbav-txt{font-size:.9rem;line-height:1.6;color:#4a5568;word-wrap:break-word}',
    '.hbav-aviso .hbav-txt a{color:#DD2476}',
    '.hbav-meta{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-top:10px}',
    '.hbav-chip{font-size:.7rem;font-weight:600;padding:3px 9px;border-radius:20px;',
    'background:#eef2f5;color:#55606b}',
    '.hbav-chip.hbav-novo{background:#DD2476;color:#fff}',
    '.hbav-chip.hbav-pin{background:#fde8f1;color:#DD2476}',
    '.hbav-vazio{text-align:center;color:#8a94a0;padding:48px 16px;font-size:.9rem}',
    '.hbav-vazio svg{width:44px;height:44px;fill:#ccd4dc;margin-bottom:12px}',
    '.hbav-erro{background:#fff4f4;border:1px solid #ffd6d6;color:#a33;border-radius:12px;',
    'padding:14px;font-size:.85rem}',
    '.hbav-form{background:#fff;border:1px solid #e9ecef;border-radius:12px;padding:16px;margin-bottom:14px}',
    '.hbav-form h3{margin:0 0 12px;font-size:.95rem;font-weight:700}',
    '.hbav-campo{margin-bottom:10px}',
    '.hbav-campo label{display:block;font-size:.75rem;font-weight:600;color:#55606b;margin-bottom:4px}',
    '.hbav-campo input,.hbav-campo select,.hbav-campo textarea{width:100%;box-sizing:border-box;',
    'border:1px solid #d6dde4;border-radius:8px;padding:9px 11px;font:400 .88rem Outfit,system-ui,sans-serif;',
    'color:#2d3436;background:#fff}',
    '.hbav-campo textarea{min-height:110px;resize:vertical;line-height:1.5}',
    '.hbav-campo input:focus,.hbav-campo select:focus,.hbav-campo textarea:focus{',
    'outline:none;border-color:#4ca1af;box-shadow:0 0 0 3px rgba(76,161,175,.18)}',
    '.hbav-check{display:flex;align-items:center;gap:8px;font-size:.82rem;color:#55606b;margin-bottom:10px}',
    '.hbav-check input{width:auto}',
    '.hbav-btn{border:none;border-radius:24px;padding:9px 18px;font:600 .85rem Outfit,system-ui,sans-serif;',
    'cursor:pointer;background:linear-gradient(135deg,#2c3e50,#4ca1af);color:#fff}',
    '.hbav-btn:hover{filter:brightness(1.08)}',
    '.hbav-btn:disabled{opacity:.55;cursor:default;filter:none}',
    '.hbav-btn.hbav-sec{background:#eef2f5;color:#42505c}',
    '.hbav-btn.hbav-perigo{background:#fdecec;color:#c0392b}',
    '.hbav-btn.hbav-mini{padding:5px 12px;font-size:.75rem;border-radius:18px}',
    '.hbav-acoes{display:flex;gap:8px;flex-wrap:wrap;align-items:center}',
    '.hbav-msg{font-size:.8rem;margin:8px 0 0;min-height:1em}',
    '.hbav-msg.hbav-ruim{color:#c0392b}',
    '.hbav-msg.hbav-bom{color:#1e8449}',
    '.hbav-sec-titulo{font-size:.75rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;',
    'color:#8a94a0;margin:18px 0 10px}',
    '/* quadro embutido em pages/avisos.html */',
    '.hbav-inline .hbav-aviso{margin-bottom:16px}',
    '.hbav-inline .hbav-vazio{padding:32px 16px}'
  ].join('');

  /* ---------------- ícones ---------------- */

  var SINO = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-5.5-1.5-1.7V10a5.5 5.5 0 0 0-4.25-5.36V4a1.25 1.25 0 1 0-2.5 0v.64A5.5 5.5 0 0 0 6.5 10v4.8L5 16.5a1 1 0 0 0 .75 1.66h12.5A1 1 0 0 0 19 16.5Z"/></svg>';

  /* ---------------- montagem ---------------- */

  var fab, fundo, painel, corpo, badge, subtitulo, botaoProf, ultimoFoco;

  function montar() {
    var estilo = el('style', { id: 'hbav-estilo', html: CSS });
    document.head.appendChild(estilo);

    badge = el('span', { class: 'hbav-badge', hidden: 'hidden' });
    fab = el('button', {
      class: 'hbav-fab', type: 'button',
      'aria-label': 'Quadro de avisos', title: 'Quadro de avisos',
      onclick: function () { abrir('lista'); }
    });
    fab.innerHTML = SINO;
    fab.appendChild(badge);

    fundo = el('div', { class: 'hbav-fundo', hidden: 'hidden', onclick: fechar });

    subtitulo = el('p', { text: 'Recados do professor Afonso' });
    var cabecalho = el('div', { class: 'hbav-cab' }, [
      el('div', {}, [el('h2', { text: 'Quadro de avisos' }), subtitulo]),
      el('button', {
        class: 'hbav-x', type: 'button', 'aria-label': 'Fechar', html: '&times;',
        onclick: fechar
      })
    ]);

    corpo = el('div', { class: 'hbav-corpo' });

    botaoProf = el('button', {
      class: 'hbav-btn hbav-sec hbav-mini', type: 'button', id: 'hbav-prof',
      text: 'Área do professor'
    });

    var rodape = el('div', { class: 'hbav-rodape' }, [
      el('a', { href: PAGINA_QUADRO, text: 'Abrir quadro completo' }),
      botaoProf
    ]);

    painel = el('div', {
      class: 'hbav-painel', role: 'dialog', 'aria-modal': 'true',
      'aria-label': 'Quadro de avisos', hidden: 'hidden'
    }, [cabecalho, corpo, rodape]);

    document.body.appendChild(fab);
    document.body.appendChild(fundo);
    document.body.appendChild(painel);

    // Nas páginas de slide, ←/→/f navegam os slides: enquanto o foco está
    // dentro do painel, a tecla não pode vazar para esse atalho.
    document.addEventListener('keydown', function (ev) {
      if (!estado.aberto) return;
      if (ev.key === 'Escape') { fechar(); return; }
      if (painel.contains(ev.target)) ev.stopPropagation();
    }, true);

    document.addEventListener('fullscreenchange', function () {
      fab.classList.toggle('hbav-oculto', !!document.fullscreenElement);
      if (document.fullscreenElement && estado.aberto) fechar();
    });
  }

  /* ---------------- abrir / fechar ---------------- */

  function abrir(vista) {
    ultimoFoco = document.activeElement;
    estado.aberto = true;
    fundo.hidden = false;
    painel.hidden = false;
    requestAnimationFrame(function () {
      fundo.classList.add('hbav-on');
      painel.classList.add('hbav-on');
    });
    ir(vista || 'lista');
    var x = painel.querySelector('.hbav-x');
    if (x) x.focus();
  }

  function fechar() {
    estado.aberto = false;
    fundo.classList.remove('hbav-on');
    painel.classList.remove('hbav-on');
    setTimeout(function () {
      if (estado.aberto) return;
      fundo.hidden = true;
      painel.hidden = true;
    }, 250);
    if (ultimoFoco && ultimoFoco.focus) ultimoFoco.focus();
  }

  function ir(vista) {
    estado.vista = vista;
    if (vista === 'lista') {
      subtitulo.textContent = 'Recados do professor Afonso';
      // a referência do "novo" é congelada antes de marcar como lido, senão
      // o destaque some no mesmo instante em que o painel abre
      estado.vistoRef = parseInt(ler(CHAVE_VISTO) || '0', 10) || 0;
      marcarLidos();
      atualizarBadge();
      desenharLista(corpo, estado.avisos, false);
      carregar(true);
    } else if (vista === 'login') {
      subtitulo.textContent = 'Entrada do professor';
      desenharLogin();
    } else {
      subtitulo.textContent = 'Área do professor — ' + (estado.sessao ? estado.sessao.usuario : '');
      desenharProfessor();
    }
    if (botaoProf) {
      botaoProf.textContent = vista === 'lista'
        ? (estado.sessao ? 'Gerenciar avisos' : 'Área do professor')
        : 'Ver o quadro';
      botaoProf.onclick = vista === 'lista'
        ? function () { ir(estado.sessao ? 'professor' : 'login'); }
        : function () { ir('lista'); };
    }
  }

  function atualizarBadge() {
    if (!badge) return;
    var n = naoLidos();
    badge.textContent = n > 9 ? '9+' : String(n);
    badge.hidden = n === 0;
    fab.setAttribute('aria-label', n
      ? 'Quadro de avisos — ' + n + ' novo(s)'
      : 'Quadro de avisos');
  }

  /* ---------------- leitura ---------------- */

  function doCache() {
    try {
      var c = JSON.parse(sessionStorage.getItem(CHAVE_CACHE) || 'null');
      if (c && Date.now() - c.ts < CACHE_MS && c.escopo === estado.escopo) return c.avisos;
    } catch (e) { /* sem cache */ }
    return null;
  }

  async function carregar(forcar) {
    var cache = forcar ? null : doCache();
    if (cache) {
      estado.avisos = cache;
      atualizarBadge();
      if (estado.vista === 'lista' && estado.aberto) desenharLista(corpo, estado.avisos, false);
      return estado.avisos;
    }
    estado.carregando = true;
    try {
      var r = await rpc('avisos_listar', { p_escopo: estado.escopo });
      estado.avisos = (r && r.avisos) || [];
      estado.erro = null;
      try {
        sessionStorage.setItem(CHAVE_CACHE, JSON.stringify({
          ts: Date.now(), escopo: estado.escopo, avisos: estado.avisos
        }));
      } catch (e) { /* modo privado */ }
    } catch (e) {
      estado.erro = 'Não foi possível carregar os avisos agora.';
      console.error('[avisos]', e);
    } finally {
      estado.carregando = false;
    }
    atualizarBadge();
    if (estado.aberto && estado.vista === 'lista') desenharLista(corpo, estado.avisos, false);
    document.dispatchEvent(new CustomEvent('hub-avisos:atualizado', { detail: estado.avisos }));
    return estado.avisos;
  }

  /* ---------------- desenho: lista ---------------- */

  function cartao(a, opcoes) {
    var novo = a.id > estado.vistoRef;
    var classes = 'hbav-aviso' + (a.fixado ? ' hbav-fixado' : '') +
      (opcoes && opcoes.inativo ? ' hbav-inativo' : '');

    var meta = el('div', { class: 'hbav-meta' }, [
      el('span', { class: 'hbav-chip', text: quando(a.publicado_em) }),
      a.escopo && a.escopo !== 'geral'
        ? el('span', { class: 'hbav-chip', text: rotuloEscopo(a.escopo) }) : null,
      a.fixado ? el('span', { class: 'hbav-chip hbav-pin', text: '★ fixado' }) : null,
      novo && !(opcoes && opcoes.gerencia)
        ? el('span', { class: 'hbav-chip hbav-novo', text: 'novo' }) : null,
      a.expira_em && !(opcoes && opcoes.inativo)
        ? el('span', { class: 'hbav-chip', text: 'até ' + quando(a.expira_em) }) : null
    ]);

    return el('div', { class: classes }, [
      el('h3', { text: a.titulo }),
      el('div', { class: 'hbav-txt', html: corpoHtml(a.corpo) }),
      meta,
      opcoes && opcoes.acoes ? opcoes.acoes(a) : null
    ]);
  }

  function desenharLista(alvo, avisos, inline) {
    alvo.innerHTML = '';
    if (estado.erro && !avisos.length) {
      alvo.appendChild(el('div', { class: 'hbav-erro' }, [
        el('p', { text: estado.erro, style: 'margin:0 0 10px' }),
        el('button', {
          class: 'hbav-btn hbav-mini', type: 'button', text: 'Tentar de novo',
          onclick: function () { carregar(true); }
        })
      ]));
      return;
    }
    if (!avisos.length) {
      alvo.appendChild(el('div', { class: 'hbav-vazio', html: SINO }));
      alvo.querySelector('.hbav-vazio').appendChild(
        el('p', { text: estado.carregando ? 'Carregando avisos…' : 'Nenhum aviso por aqui. Bons estudos!' })
      );
      return;
    }
    avisos.forEach(function (a) { alvo.appendChild(cartao(a, null)); });
    if (!inline) {
      alvo.appendChild(el('p', {
        class: 'hbav-msg',
        style: 'color:#8a94a0;text-align:center',
        // sem escopo (index, homes de semestre) o servidor devolve tudo
        text: estado.escopo
          ? 'Mostrando avisos gerais e de ' + rotuloEscopo(estado.escopo) + '.'
          : 'Mostrando os avisos de todas as turmas.'
      }));
    }
  }

  /* ---------------- desenho: login ---------------- */

  function desenharLogin() {
    corpo.innerHTML = '';
    var usuario = el('input', { type: 'text', id: 'hbav-usuario', autocomplete: 'username' });
    var senha = el('input', { type: 'password', id: 'hbav-senha', autocomplete: 'current-password' });
    var msg = el('p', { class: 'hbav-msg' });
    var botao = el('button', { class: 'hbav-btn', type: 'submit', text: 'Entrar' });

    var form = el('form', {
      class: 'hbav-form',
      onsubmit: async function (ev) {
        ev.preventDefault();
        msg.className = 'hbav-msg';
        msg.textContent = 'Verificando…';
        botao.disabled = true;
        try {
          var r = await rpc('avisos_login', {
            p_usuario: usuario.value, p_senha: senha.value
          });
          if (!r.ok) {
            msg.className = 'hbav-msg hbav-ruim';
            msg.textContent = r.erro;
            return;
          }
          estado.sessao = { token: r.token, usuario: r.usuario, expira_em: r.expira_em };
          guardar(CHAVE_SESSAO, JSON.stringify(estado.sessao));
          ir('professor');
        } catch (e) {
          msg.className = 'hbav-msg hbav-ruim';
          msg.textContent = 'Falha de rede. Verifique a conexão.';
          console.error('[avisos]', e);
        } finally {
          botao.disabled = false;
        }
      }
    }, [
      el('h3', { text: 'Entrar para publicar avisos' }),
      el('div', { class: 'hbav-campo' }, [
        el('label', { for: 'hbav-usuario', text: 'Usuário' }), usuario
      ]),
      el('div', { class: 'hbav-campo' }, [
        el('label', { for: 'hbav-senha', text: 'Senha' }), senha
      ]),
      el('div', { class: 'hbav-acoes' }, [
        botao,
        el('button', {
          class: 'hbav-btn hbav-sec', type: 'button', text: 'Voltar',
          onclick: function () { ir('lista'); }
        })
      ]),
      msg
    ]);

    corpo.appendChild(form);
    corpo.appendChild(el('p', {
      class: 'hbav-msg',
      style: 'color:#8a94a0',
      text: 'Área restrita ao professor. A senha é conferida no servidor; ' +
            'cinco tentativas erradas bloqueiam a conta por 15 minutos.'
    }));
    usuario.focus();
  }

  /* ---------------- desenho: professor ---------------- */

  function campo(rotulo, controle, id) {
    return el('div', { class: 'hbav-campo' }, [
      el('label', { for: id, text: rotulo }), controle
    ]);
  }

  async function chamarAutenticado(fn, args) {
    args = args || {};
    args.p_token = estado.sessao ? estado.sessao.token : '';
    var r = await rpc(fn, args);
    if (r && !r.ok && /Sessão expirada/i.test(r.erro || '')) {
      estado.sessao = null;
      guardar(CHAVE_SESSAO, '');
      ir('login');
    }
    return r;
  }

  function desenharProfessor() {
    corpo.innerHTML = '';

    var ed = estado.editando;
    var titulo = el('input', { type: 'text', id: 'hbav-titulo', maxlength: '90',
                               value: ed ? ed.titulo : '' });
    var texto = el('textarea', { id: 'hbav-corpo', maxlength: '2000',
                                 placeholder: 'Escreva o recado. Links viram clicáveis automaticamente.' });
    texto.value = ed ? ed.corpo : '';

    var escopo = el('select', { id: 'hbav-escopo' });
    ESCOPOS.forEach(function (o) {
      var op = el('option', { value: o.valor, text: o.rotulo });
      if (ed ? ed.escopo === o.valor : (estado.escopo === o.valor)) op.selected = true;
      escopo.appendChild(op);
    });

    var expira = el('input', { type: 'date', id: 'hbav-expira',
      value: ed && ed.expira_em ? String(ed.expira_em).slice(0, 10) : '' });

    var fixado = el('input', { type: 'checkbox', id: 'hbav-fixado' });
    fixado.checked = !!(ed && ed.fixado);

    var msg = el('p', { class: 'hbav-msg' });
    var enviar = el('button', { class: 'hbav-btn', type: 'submit',
                                text: ed ? 'Salvar alterações' : 'Publicar aviso' });

    var form = el('form', {
      class: 'hbav-form',
      onsubmit: async function (ev) {
        ev.preventDefault();
        msg.className = 'hbav-msg';
        msg.textContent = 'Enviando…';
        enviar.disabled = true;
        try {
          var args = {
            p_titulo: titulo.value,
            p_corpo: texto.value,
            p_escopo: escopo.value,
            p_fixado: fixado.checked,
            // fim do dia escolhido, no fuso do navegador
            p_expira_em: expira.value ? new Date(expira.value + 'T23:59:59').toISOString() : null
          };
          var r;
          if (ed) { args.p_id = ed.id; r = await chamarAutenticado('avisos_editar', args); }
          else { r = await chamarAutenticado('avisos_publicar', args); }
          if (!r || !r.ok) {
            msg.className = 'hbav-msg hbav-ruim';
            msg.textContent = (r && r.erro) || 'Não foi possível salvar.';
            return;
          }
          estado.editando = null;
          try { sessionStorage.removeItem(CHAVE_CACHE); } catch (e) { /* ok */ }
          await carregar(true);
          await desenharProfessor();
        } catch (e) {
          msg.className = 'hbav-msg hbav-ruim';
          msg.textContent = 'Falha de rede. Verifique a conexão.';
          console.error('[avisos]', e);
        } finally {
          enviar.disabled = false;
        }
      }
    }, [
      el('h3', { text: ed ? 'Editando aviso' : 'Novo aviso' }),
      campo('Título', titulo, 'hbav-titulo'),
      campo('Texto', texto, 'hbav-corpo'),
      campo('Para quem', escopo, 'hbav-escopo'),
      campo('Sumir do quadro em (opcional)', expira, 'hbav-expira'),
      el('label', { class: 'hbav-check', for: 'hbav-fixado' }, [
        fixado, el('span', { text: 'Fixar no topo do quadro' })
      ]),
      el('div', { class: 'hbav-acoes' }, [
        enviar,
        ed ? el('button', {
          class: 'hbav-btn hbav-sec', type: 'button', text: 'Cancelar edição',
          onclick: function () { estado.editando = null; desenharProfessor(); }
        }) : null
      ]),
      msg
    ]);

    corpo.appendChild(form);
    corpo.appendChild(el('p', { class: 'hbav-sec-titulo', text: 'Avisos publicados' }));

    var lista = el('div', { text: 'Carregando…', class: 'hbav-msg' });
    corpo.appendChild(lista);

    corpo.appendChild(el('div', { class: 'hbav-acoes', style: 'margin-top:22px' }, [
      el('button', {
        class: 'hbav-btn hbav-sec hbav-mini', type: 'button', text: 'Trocar senha',
        onclick: desenharSenha
      }),
      el('button', {
        class: 'hbav-btn hbav-sec hbav-mini', type: 'button', text: 'Sair',
        onclick: async function () {
          try { await chamarAutenticado('avisos_sair', {}); } catch (e) { /* segue */ }
          estado.sessao = null;
          guardar(CHAVE_SESSAO, '');
          ir('lista');
        }
      })
    ]));

    return carregarPainel(lista);
  }

  async function carregarPainel(alvo) {
    try {
      var r = await chamarAutenticado('avisos_painel', {});
      if (!r || !r.ok) {
        alvo.className = 'hbav-msg hbav-ruim';
        alvo.textContent = (r && r.erro) || 'Não foi possível listar.';
        return;
      }
      estado.doPainel = r.avisos || [];
      alvo.className = '';
      alvo.innerHTML = '';
      if (!estado.doPainel.length) {
        alvo.appendChild(el('p', { class: 'hbav-msg', text: 'Nenhum aviso ainda.' }));
        return;
      }
      estado.doPainel.forEach(function (a) {
        alvo.appendChild(cartao(a, {
          gerencia: true,
          inativo: !a.vigente,
          acoes: function (av) {
            return el('div', { class: 'hbav-acoes', style: 'margin-top:10px' }, [
              av.removido_em ? null : el('button', {
                class: 'hbav-btn hbav-sec hbav-mini', type: 'button', text: 'Editar',
                onclick: function () {
                  estado.editando = av;
                  desenharProfessor();
                  corpo.scrollTop = 0;
                }
              }),
              av.removido_em ? el('button', {
                class: 'hbav-btn hbav-sec hbav-mini', type: 'button', text: 'Restaurar',
                onclick: async function () {
                  await chamarAutenticado('avisos_restaurar', { p_id: av.id });
                  try { sessionStorage.removeItem(CHAVE_CACHE); } catch (e) { /* ok */ }
                  await carregar(true);
                  desenharProfessor();
                }
              }) : el('button', {
                class: 'hbav-btn hbav-perigo hbav-mini', type: 'button', text: 'Remover',
                onclick: async function (ev) {
                  var b = ev.currentTarget;
                  if (b.dataset.confirmar !== '1') {
                    b.dataset.confirmar = '1';
                    b.textContent = 'Confirmar remoção';
                    return;
                  }
                  await chamarAutenticado('avisos_remover', { p_id: av.id });
                  try { sessionStorage.removeItem(CHAVE_CACHE); } catch (e) { /* ok */ }
                  await carregar(true);
                  desenharProfessor();
                }
              }),
              av.removido_em
                ? el('span', { class: 'hbav-chip', text: 'removido' })
                : (!av.vigente ? el('span', { class: 'hbav-chip', text: 'expirado' }) : null)
            ]);
          }
        }));
      });
    } catch (e) {
      alvo.className = 'hbav-msg hbav-ruim';
      alvo.textContent = 'Falha de rede ao listar os avisos.';
      console.error('[avisos]', e);
    }
  }

  function desenharSenha() {
    corpo.innerHTML = '';
    var atual = el('input', { type: 'password', id: 'hbav-s1', autocomplete: 'current-password' });
    var nova = el('input', { type: 'password', id: 'hbav-s2', autocomplete: 'new-password' });
    var msg = el('p', { class: 'hbav-msg' });
    var botao = el('button', { class: 'hbav-btn', type: 'submit', text: 'Trocar senha' });

    corpo.appendChild(el('form', {
      class: 'hbav-form',
      onsubmit: async function (ev) {
        ev.preventDefault();
        msg.className = 'hbav-msg';
        msg.textContent = 'Enviando…';
        botao.disabled = true;
        try {
          var r = await chamarAutenticado('avisos_trocar_senha', {
            p_atual: atual.value, p_nova: nova.value
          });
          if (!r || !r.ok) {
            msg.className = 'hbav-msg hbav-ruim';
            msg.textContent = (r && r.erro) || 'Não foi possível trocar.';
            return;
          }
          msg.className = 'hbav-msg hbav-bom';
          msg.textContent = 'Senha trocada. As outras sessões foram encerradas.';
          atual.value = nova.value = '';
        } catch (e) {
          msg.className = 'hbav-msg hbav-ruim';
          msg.textContent = 'Falha de rede. Verifique a conexão.';
          console.error('[avisos]', e);
        } finally {
          botao.disabled = false;
        }
      }
    }, [
      el('h3', { text: 'Trocar a senha do professor' }),
      campo('Senha atual', atual, 'hbav-s1'),
      campo('Nova senha (mínimo 8 caracteres)', nova, 'hbav-s2'),
      el('div', { class: 'hbav-acoes' }, [
        botao,
        el('button', {
          class: 'hbav-btn hbav-sec', type: 'button', text: 'Voltar',
          onclick: desenharProfessor
        })
      ]),
      msg
    ]));
    atual.focus();
  }

  /* ---------------- API pública ---------------- */

  window.HubAvisos = {
    abrir: abrir,
    // Entrada do professor: pula o formulário se a sessão ainda vale.
    abrirProfessor: function () { abrir(estado.sessao ? 'professor' : 'login'); },
    sessaoAtiva: function () { return !!estado.sessao; },
    fechar: fechar,
    carregar: carregar,
    listaAtual: function () { return estado.avisos.slice(); },
    escopo: function () { return estado.escopo; },
    // Usado por pages/avisos.html para desenhar o quadro na própria página.
    montarEm: function (alvo) {
      alvo.classList.add('hbav-inline');
      var pinta = function () { desenharLista(alvo, estado.avisos, true); };
      document.addEventListener('hub-avisos:atualizado', pinta);
      pinta();
      carregar(true).then(function () { pinta(); marcarLidos(); atualizarBadge(); });
      return pinta;
    },
    raiz: RAIZ
  };

  /* ---------------- início ---------------- */

  function iniciar() {
    if (!document.body || document.body.hasAttribute('data-sem-avisos')) return;
    estado.escopo = escopoDaPagina();
    estado.vistoRef = parseInt(ler(CHAVE_VISTO) || '0', 10) || 0;
    montar();
    if (document.body.hasAttribute('data-avisos-inline')) fab.classList.add('hbav-oculto');
    atualizarBadge();
    carregar(false);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
  } else {
    iniciar();
  }
})();
