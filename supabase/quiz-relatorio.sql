-- =====================================================================
-- Relatório do quiz — agregação por questão, por tema e por estudante
--
-- Acrescenta a cada questão o tema e a seção do material a que ela
-- corresponde, para que o relatório aponte o que reforçar no estudo e
-- não apenas quantas respostas erradas houve.
--
-- Rodar depois de quiz-schema.sql. Não destrói dado algum: pode ser
-- aplicado com uma sessão em andamento.
-- =====================================================================

alter table quiz_questions add column if not exists tema  text;
alter table quiz_questions add column if not exists secao text;

-- Relatório completo. Exige o token: os dados são da turma inteira.
create or replace function quiz_relatorio(p_slug text, p_token text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ok bool; v_out jsonb; v_total int; v_jogadores int;
begin
  select exists (select 1 from quiz_host_tokens
                  where session_slug = p_slug and token = p_token) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  select count(*) into v_total     from quiz_questions where session_slug = p_slug;
  select count(*) into v_jogadores from quiz_players   where session_slug = p_slug;

  v_out := jsonb_build_object(
    'ok', true, 'total', v_total, 'jogadores', v_jogadores,
    'titulo', (select titulo from quiz_sessions where slug = p_slug),
    'gerado_em', now()
  );

  -- Por questão: taxa de acerto, distribuição das escolhas e tempo médio.
  -- O distrator mais escolhido é o que revela a concepção equivocada.
  v_out := v_out || jsonb_build_object('questoes', coalesce((
    select jsonb_agg(x order by (x->>'taxa')::numeric nulls last) from (
      select jsonb_build_object(
        'ordem', q.ordem, 'tema', q.tema, 'secao', q.secao,
        'enunciado', q.enunciado, 'alternativas', q.alternativas,
        'correta', k.correta,
        'respostas', count(a.*) filter (where a.player_id is not null),
        'acertos',   count(a.*) filter (where a.correta),
        'taxa', case when count(a.*) filter (where a.player_id is not null) = 0 then null
                     else round(100.0 * count(a.*) filter (where a.correta)
                                / count(a.*) filter (where a.player_id is not null), 1) end,
        'sem_resposta', v_jogadores - count(a.*) filter (where a.player_id is not null),
        'distribuicao', coalesce((select jsonb_object_agg(e::text, n) from (
            select escolha e, count(*)::int n from quiz_answers
             where question_id = q.id group by escolha) d), '{}'::jsonb),
        'segundos_acerto', round((avg(a.ms) filter (where a.correta)) / 1000.0, 1),
        'segundos_erro',   round((avg(a.ms) filter (where not a.correta)) / 1000.0, 1)
      ) as x
      from quiz_questions q
      join quiz_answer_key k on k.question_id = q.id
      left join quiz_answers a on a.question_id = q.id
      where q.session_slug = p_slug
      group by q.id, q.ordem, q.tema, q.secao, q.enunciado, q.alternativas, k.correta
    ) s), '[]'::jsonb));

  -- Por tema: é o recorte que orienta o que revisar com a turma.
  v_out := v_out || jsonb_build_object('temas', coalesce((
    select jsonb_agg(x order by (x->>'taxa')::numeric nulls last) from (
      select jsonb_build_object(
        'tema', q.tema, 'secao', q.secao,
        'questoes', array_agg(distinct q.ordem order by q.ordem),
        'respostas', count(a.*) filter (where a.player_id is not null),
        'acertos',   count(a.*) filter (where a.correta),
        'taxa', case when count(a.*) filter (where a.player_id is not null) = 0 then null
                     else round(100.0 * count(a.*) filter (where a.correta)
                                / count(a.*) filter (where a.player_id is not null), 1) end
      ) as x
      from quiz_questions q
      left join quiz_answers a on a.question_id = q.id
      where q.session_slug = p_slug
      group by q.tema, q.secao
    ) s), '[]'::jsonb));

  -- Por estudante: onde cada um errou, e sob que tema.
  v_out := v_out || jsonb_build_object('alunos', coalesce((
    select jsonb_agg(x order by (x->>'acertos')::int desc, x->>'nome') from (
      select jsonb_build_object(
        'nome', p.nome,
        'respondidas', count(a.*) filter (where a.player_id is not null),
        'acertos', count(a.*) filter (where a.correta),
        'pontos', coalesce(sum(a.pontos), 0)::int,
        'erros', coalesce(array_agg(q.ordem order by q.ordem)
                   filter (where a.player_id is not null and not a.correta), '{}'),
        'temas_a_reforcar', coalesce(array_agg(distinct q.tema)
                   filter (where a.player_id is not null and not a.correta), '{}')
      ) as x
      from quiz_players p
      left join quiz_answers a  on a.player_id = p.id
      left join quiz_questions q on q.id = a.question_id
      where p.session_slug = p_slug
      group by p.id, p.nome
    ) s), '[]'::jsonb));

  return v_out;
end $$;

revoke all on function quiz_relatorio(text,text) from public;
grant execute on function quiz_relatorio(text,text) to anon, authenticated;
