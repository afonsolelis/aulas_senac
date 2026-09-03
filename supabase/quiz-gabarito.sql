-- =====================================================================
-- Banco de perguntas com gabarito — leitura do professor
--
-- Serve para conferir as perguntas ANTES da aula e revisá-las depois, sem
-- precisar abrir pergunta por pergunta no painel. Exige o token: o gabarito
-- não pode sair para o aluno em nenhuma hipótese antes da revelação.
--
-- Rodar depois de quiz-schema.sql. Não altera dado algum.
-- =====================================================================

create or replace function quiz_gabarito(p_slug text, p_token text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ok bool; v_out jsonb;
begin
  select exists (select 1 from quiz_host_tokens
                  where session_slug = p_slug and token = p_token) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'titulo', (select titulo from quiz_sessions where slug = p_slug),
    'total',  (select count(*) from quiz_questions where session_slug = p_slug),
    'perguntas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ordem', q.ordem, 'enunciado', q.enunciado, 'alternativas', q.alternativas,
               'segundos', q.segundos, 'tema', q.tema, 'secao', q.secao,
               'correta', k.correta, 'explicacao', k.explicacao)
             order by q.ordem)
        from quiz_questions q
        join quiz_answer_key k on k.question_id = q.id
       where q.session_slug = p_slug), '[]'::jsonb));
end $$;

revoke all on function quiz_gabarito(text,text) from public;
grant execute on function quiz_gabarito(text,text) to anon, authenticated;
