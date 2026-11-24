/*
 * Peças comuns das páginas de acompanhamento do TCC (pages/tcc1/acompanhamento/).
 * Depende de js/api_aulas.js. Banco: postgrest/hubtcc.sql (funções hubtcc_*).
 *
 * Todo texto vem de formulário de aluno ou professor: só textContent, nunca innerHTML.
 */
(function () {
  const db = window.aulasApi.cliente();

  // Chama a RPC e transforma { ok: false, erro } em exceção.
  async function chamar(fn, args) {
    const { data, error } = await db.rpc(fn, args || {});
    if (error) throw new Error(error.message || 'Falha ao falar com o servidor.');
    if (data && data.ok === false) throw new Error(data.erro);
    return data;
  }

  const pdf = (caminho) => window.aulasApi.urlPdf(caminho, 'hubtcc_pdf');

  const quando = (iso) => iso ? new Date(iso).toLocaleString('pt-BR', {
    timeZone: 'America/Sao_Paulo', dateStyle: 'short', timeStyle: 'short' }) : '';

  function el(tag, texto, attrs) {
    const e = document.createElement(tag);
    if (texto != null) e.textContent = texto;
    for (const [k, v] of Object.entries(attrs || {})) e.setAttribute(k, v);
    return e;
  }

  // Guarda o token no navegador (localStorage ou sessionStorage), sem quebrar em aba privada.
  function guarda(chave, sessao) {
    const area = () => (sessao ? window.sessionStorage : window.localStorage);
    return {
      ler() { try { return area().getItem(chave) || ''; } catch { return ''; } },
      gravar(v) { try { v ? area().setItem(chave, v) : area().removeItem(chave); } catch { /* sem armazenamento */ } },
    };
  }

  const AVALIACAO = {
    grave: { rotulo: 'Grave', classe: 'bg-danger' },
    esperado: { rotulo: 'Esperado', classe: 'bg-primary' },
    supera: { rotulo: 'Supera', classe: 'bg-success' },
  };

  function seloAvaliacao(av) {
    const a = AVALIACAO[av];
    return a ? el('span', a.rotulo, { class: `badge ${a.classe}` })
      : el('span', 'Sem avaliação', { class: 'badge bg-light text-dark border' });
  }

  function seloLiberacao(lib) {
    if (lib === true) return el('span', 'Liberado para a banca', { class: 'badge bg-success' });
    if (lib === false) return el('span', 'Não liberado para a banca', { class: 'badge bg-danger' });
    return el('span', 'Banca: aguardando o orientador', { class: 'badge bg-light text-dark border' });
  }

  const TIPO_VERSAO = { primeira: 'Primeira versão', nova: 'Nova versão', final: 'Versão final' };

  function listaVersoes(versoes) {
    const ul = el('ul', null, { class: 'list-unstyled mb-0 small' });
    if (!versoes || !versoes.length) { ul.append(el('li', 'Nenhum PDF ainda.', { class: 'text-muted' })); return ul; }
    for (const v of versoes) {
      const li = el('li', null, { class: 'mb-1' });
      li.append(el('a', TIPO_VERSAO[v.tipo] || 'PDF', { href: pdf(v.arquivo), target: '_blank', rel: 'noopener noreferrer' }),
        el('span', ` · ${quando(v.enviado_em)}${v.nome_arquivo ? ' · ' + v.nome_arquivo : ''}`, { class: 'text-muted' }));
      ul.append(li);
    }
    return ul;
  }

  // Histórico do orientador. aoEditar(registro, li) desenha os botões de edição, quando há.
  function listaRegistros(registros, aoEditar) {
    const ul = el('ul', null, { class: 'list-unstyled mb-0' });
    if (!registros || !registros.length) {
      ul.append(el('li', 'Nenhuma consideração registrada ainda.', { class: 'text-muted small' }));
      return ul;
    }
    for (const r of registros) {
      const li = el('li', null, { class: 'border-start border-3 ps-3 mb-3' });
      const topo = el('div', null, { class: 'd-flex gap-2 flex-wrap align-items-center small' });
      if (r.avaliacao) topo.append(seloAvaliacao(r.avaliacao));
      topo.append(el('span', `${r.professor} · ${quando(r.criado_em)}${r.atualizado_em ? ' (editado)' : ''}`, { class: 'text-muted' }));
      li.append(topo);
      if (r.texto) li.append(el('div', r.texto, { class: 'mt-1', style: 'white-space:pre-wrap' }));
      if (aoEditar) aoEditar(r, li);
      ul.append(li);
    }
    return ul;
  }

  async function copiar(texto, botao) {
    try { await navigator.clipboard.writeText(texto); } catch { return false; }
    if (botao) {
      const antes = botao.innerHTML;
      botao.textContent = 'Copiado';
      setTimeout(() => { botao.innerHTML = antes; }, 1500);
    }
    return true;
  }

  // Sobe o PDF em partes e devolve o caminho. opcoes: { edicao, token, aoProgresso }.
  async function subirPdf(arquivo, opcoes) {
    const ehPdf = arquivo && (arquivo.type === 'application/pdf' || /\.pdf$/i.test(arquivo.name));
    if (!ehPdf) throw new Error('Escolha um arquivo PDF.');
    if (arquivo.size > 100 * 1024 * 1024) throw new Error('O PDF passa de 100 MB. Comprima o arquivo e tente de novo.');
    const caminho = `${opcoes.edicao}/${crypto.randomUUID()}.pdf`;
    const r = await db.storage.from('hub-tcc').upload(caminho, arquivo, {
      token: opcoes.token, aoProgresso: opcoes.aoProgresso });
    if (r.error) throw new Error('O envio do PDF falhou: ' + r.error.message);
    return caminho;
  }

  window.HubTcc = {
    chamar, pdf, quando, el, guarda, seloAvaliacao, seloLiberacao, listaVersoes, listaRegistros,
    copiar, subirPdf, AVALIACAO,
    edicao: () => document.body.dataset.edicao,
    pagina: (nome) => new URL(nome, location.href).href,
  };
})();
