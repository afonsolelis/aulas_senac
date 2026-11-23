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
  const TAMANHO_PARTE = 8 * 1024 * 1024;

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
      // O PDF vai em partes de 8 MB, uma por vez (hubdeposito_subir_parte): um corpo
      // único de 150 MB em base64 estouraria o tempo do proxy em conexão lenta.
      // opcoes.aoProgresso(enviadas, total) avisa a página a cada parte.
      async upload(caminho, arquivo, opcoes) {
        const aoProgresso = (opcoes && opcoes.aoProgresso) || function () {};
        const total = Math.max(1, Math.ceil(arquivo.size / TAMANHO_PARTE));
        let data = null;
        for (let parte = 1; parte <= total; parte++) {
          const pedaco = arquivo.slice((parte - 1) * TAMANHO_PARTE, parte * TAMANHO_PARTE);
          let conteudo;
          try { conteudo = await base64(pedaco); } catch (e) { return { data: null, error: { message: e.message } }; }
          const args = { p_caminho: caminho, p_parte: parte, p_total: total, p_conteudo: conteudo };
          let resp = await rpc('hubdeposito_subir_parte', args);
          // Falha de rede ou do servidor (sem status ou 5xx): tenta a mesma parte mais uma vez.
          if (resp.error && !(resp.error.status >= 400 && resp.error.status < 500)) {
            resp = await rpc('hubdeposito_subir_parte', args);
          }
          if (resp.error) return { data: null, error: resp.error };
          data = resp.data;
          aoProgresso(parte, total);
        }
        if (!data || !data.completo) return { data: null, error: { message: 'O PDF não chegou inteiro. Envie de novo.' } };
        return { data: { path: data.caminho }, error: null };
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
