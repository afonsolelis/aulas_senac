-- =====================================================================
-- Quiz ao vivo — tempo por pergunta calibrado pelo professor
-- Projeto: lwamaovuxcevsjfvtqhf (Supabase do Hub de Aulas Senac)
--
-- O seed grava 90 segundos em cada questão. O campo "Tempo" do painel chama
-- quiz_tempo e troca esse valor para todas as questões da sala. Como tudo que
-- conta o tempo lê quiz_questions.segundos — a pontuação por rapidez em
-- quiz_responder, o cronômetro do celular em quiz_estado e o do painel em
-- quiz_host —, nenhuma outra função nem a página do aluno precisa mudar.
--
--   quiz_tempo(slug, token)            lê o tempo atual da sala
--   quiz_tempo(slug, token, segundos)  aplica de 10 a 600 segundos
--
-- A troca é recusada com a pergunta aberta: o cronômetro já projetado e a
-- pontuação de quem respondeu seguiriam relógios diferentes. Entre perguntas
-- (lobby, revelação ou encerrada), vale a partir da próxima que abrir.
-- O valor fica na sala e atravessa o Reiniciar; rodar o seed de novo volta
-- a 90.
--
-- Rodar depois de quiz-peso-strike.sql. Cria só a função quiz_tempo; não
-- altera tabela nem outra função, e pode ser aplicado com sala em andamento.
-- =====================================================================

create or replace function quiz_tempo(p_slug text, p_token text, p_segundos int default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ok bool; v_estado text; v_segundos int;
begin
  select exists (select 1 from quiz_host_tokens
                  where session_slug = p_slug and token = p_token) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  if p_segundos is not null then
    if p_segundos not between 10 and 600 then
      return jsonb_build_object('ok', false, 'erro', 'O tempo vai de 10 a 600 segundos.');
    end if;

    select estado into v_estado from quiz_sessions where slug = p_slug;
    if v_estado = 'pergunta' then
      return jsonb_build_object('ok', false,
        'erro', 'Há uma pergunta aberta. Troque o tempo depois da revelação.');
    end if;

    update quiz_questions set segundos = p_segundos where session_slug = p_slug;
  end if;

  -- O valor mais comum entre as questões: numa sala calibrada por aqui,
  -- todas têm o mesmo.
  select segundos into v_segundos
    from quiz_questions where session_slug = p_slug
   group by segundos order by count(*) desc, segundos desc
   limit 1;

  return jsonb_build_object('ok', true, 'segundos', v_segundos,
                            'aplicado', p_segundos is not null);
end $$;

-- RPC pública por desenho: a credencial é o token, conferido lá dentro.
revoke all on function quiz_tempo(text,text,int) from public;
grant execute on function quiz_tempo(text,text,int) to anon, authenticated;
