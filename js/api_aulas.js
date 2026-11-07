/*
 * Cliente das atividades interativas (quiz, TBL, entregas, depósito do TCC2).
 *
 * As páginas falam com o PostgREST do projeto aulas_senac na VPS (Coolify),
 * que substituiu o Supabase cloud em novembro de 2026. A API só expõe RPCs;
 * as tabelas ficam fechadas para o papel anon. Estrutura e operação em
 * postgrest/README.md.
 *
 * O cliente imita a parte do supabase-js que as páginas usavam:
 *   const db = window.aulasApi.cliente();
 *   const { data, error } = await db.rpc('quiz_estado', { p_slug, ... });
 *   await db.storage.from('hub-tcc2-depositos').upload(caminho, arquivoPdf);
 *   db.storage.from('hub-tcc2-depositos').getPublicUrl(caminho).data.publicUrl;
 * Não há Realtime: db.channel(...) existe só para não quebrar as páginas,
 * que consultam o estado a cada segundo.
 */
(function () {
  const URL_API = 'https://aulas-senac-api.afonsolelis.tech';

  async function rpc(fn, args) {
    try {
      const r = await fetch(URL_API + '/rpc/' + fn, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(args || {}),
      });
      const texto = await r.text();
      const corpo = texto ? JSON.parse(texto) : null;
      if (!r.ok) {
        const msg = (corpo && corpo.message) || ('Falha na chamada ' + fn + ' (' + r.status + ')');
        return { data: null, error: { message: msg, code: corpo && corpo.code, status: r.status } };
      }
      return { data: corpo, error: null };
    } catch (e) {
      return { data: null, error: { message: e.message || 'Sem conexão com o servidor.' } };
    }
  }

  function canalVazio() {
    const canal = {
      on() { return canal; },
      subscribe() { return canal; },
      unsubscribe() { return Promise.resolve('ok'); },
    };
    return canal;
  }

  // Lê o arquivo como base64 (sem o prefixo data:...;base64,).
  function base64(arquivo) {
    return new Promise((resolve, reject) => {
      const leitor = new FileReader();
      leitor.onload = () => resolve(String(leitor.result).replace(/^data:[^,]*,/, ''));
      leitor.onerror = () => reject(leitor.error || new Error('Não foi possível ler o arquivo.'));
      leitor.readAsDataURL(arquivo);
    });
  }

  // Só o bucket do depósito do TCC2 existe; os PDFs ficam no próprio Postgres.
  function balde() {
    return {
      async upload(caminho, arquivo) {
        let conteudo;
        try { conteudo = await base64(arquivo); } catch (e) { return { data: null, error: { message: e.message } }; }
        const { data, error } = await rpc('hubdeposito_subir', { p_caminho: caminho, p_conteudo: conteudo });
        return error ? { data: null, error } : { data: { path: data.caminho }, error: null };
      },
      getPublicUrl(caminho) {
        return { data: { publicUrl: urlPdf(caminho) } };
      },
    };
  }

  function urlPdf(caminho) {
    return URL_API + '/rpc/hubdeposito_pdf?p_caminho=' + encodeURIComponent(caminho);
  }

  window.AULAS_API_URL = URL_API;
  window.aulasApi = {
    url: URL_API,
    urlPdf,
    cliente() {
      return {
        rpc,
        channel: canalVazio,
        removeChannel() { return Promise.resolve('ok'); },
        storage: { from: balde },
      };
    },
  };
})();
