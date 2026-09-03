/**
 * Exportação do relatório do quiz em CSV.
 *
 * Usado pela página de relatório e pelo painel do professor — no painel,
 * dentro da confirmação de reinício, para que o resultado da turma saia
 * do navegador antes de a sala ser zerada.
 *
 * Recebe o objeto devolvido pela função quiz_relatorio do Supabase.
 */
(function (janela) {
  const LETRAS = ['A', 'B', 'C', 'D', 'E'];

  /* Uma linha por tema, por questão e por estudante, no mesmo arquivo:
     é o recorte que o professor lê depois da aula, sem ferramenta. */
  function linhas(dados) {
    const l = [['tipo', 'identificacao', 'acertos', 'respostas', 'taxa', 'detalhe']];
    (dados.temas || []).forEach((t) =>
      l.push(['tema', t.tema || '', t.acertos, t.respostas, t.taxa ?? '', t.secao || '']));
    (dados.questoes || []).forEach((q) =>
      l.push(['questao', `Q${q.ordem} ${q.tema || ''}`, q.acertos, q.respostas, q.taxa ?? '',
              `correta ${LETRAS[q.correta]}`]));
    (dados.alunos || []).forEach((a) =>
      l.push(['estudante', a.nome, a.acertos, a.respondidas, '',
              `errou ${a.erros.join(' ')} | reforcar: ${a.temas_a_reforcar.join('; ')}`]));
    return l;
  }

  /* BOM na frente: sem ele o Excel em português abre os acentos quebrados. */
  function texto(dados) {
    return linhas(dados)
      .map((l) => l.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(','))
      .join('\n');
  }

  function baixar(dados, slug) {
    if (!dados) return false;
    const url = URL.createObjectURL(
      new Blob(['﻿' + texto(dados)], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `relatorio-quiz-${slug}-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    return true;
  }

  janela.quizCsv = { linhas, texto, baixar };
})(window);
