-- =====================================================================
-- Quiz ao vivo — peso por questão, strike por saída da aba e as RPCs do jogo
-- Projeto: lwamaovuxcevsjfvtqhf (Supabase do Hub de Aulas Senac)
--
-- Duas regras, em vigor a partir do quiz da Aula 07 (ci-q2-a07):
--
--   peso    Cada questão multiplica a própria pontuação. O padrão é 1; o
--           seed marca 2 na última questão, que vale o dobro.
--   strike  Quem sai da aba com a pergunta aberta (troca de aba ou de app,
--           tira o foco da janela, bloqueia a tela) leva um strike e fica
--           com zero ponto naquela questão, tenha respondido antes ou depois.
--           Um strike por pergunta: sair de novo não soma.
--
-- Este arquivo é a fonte de quiz_responder, quiz_strike, quiz_estado e
-- quiz_host. Não destrói dado algum e pode ser aplicado com sala em
-- andamento: questão de peso 1 pontua como antes, e as páginas das aulas
-- 02 a 06, que não chamam quiz_strike, nunca lançam strike.
--
-- Ordem numa instalação nova: quiz-schema.sql → ESTE → quiz-relatorio.sql
-- → quiz-ingestao.sql → quiz-gabarito.sql → quiz-banco.sql → seeds.
-- Numa instalação existente: ESTE, quiz-relatorio.sql, quiz-ingestao.sql e
-- o seed da aula (quiz_linhas, em quiz-ingestao.sql, lê quiz_strikes).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Estrutura
-- ---------------------------------------------------------------------

alter table quiz_questions add column if not exists peso int not null default 1;

do $$
begin
  alter table quiz_questions
    add constraint quiz_questions_peso_faixa check (peso between 1 and 3);
exception when duplicate_object then null;
end $$;

-- A marca de quem saiu da aba. Como as respostas, não é legível pela API:
-- o placar mostra só a contagem, calculada nas funções abaixo.
create table if not exists quiz_strikes (
  player_id     uuid        not null references quiz_players(id)   on delete cascade,
  question_id   bigint      not null references quiz_questions(id) on delete cascade,
  motivo        text        not null default 'aba' check (motivo in ('aba', 'foco')),
  registrado_em timestamptz not null default now(),
  primary key (player_id, question_id)
);

alter table quiz_strikes enable row level security;
revoke all on quiz_strikes from anon, authenticated;

-- ---------------------------------------------------------------------
-- Registro da resposta. Não informa se acertou: o veredito aparece apenas
-- quando o professor revela, o que impede repassar gabarito à turma.
-- ---------------------------------------------------------------------
create or replace function quiz_responder(p_player uuid, p_escolha int)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_slug text; v_q record; v_s record;
  v_ms int; v_correta bool; v_pontos int; v_fracao numeric; v_strike bool;
begin
  select session_slug into v_slug from quiz_players where id = p_player;
  if v_slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Jogador não encontrado. Entre novamente.');
  end if;

  select * into v_s from quiz_sessions where slug = v_slug;
  if v_s.estado <> 'pergunta' then
    return jsonb_build_object('ok', false, 'erro', 'A pergunta não está aberta.');
  end if;

  select q.*, k.correta as gabarito into v_q
    from quiz_questions q join quiz_answer_key k on k.question_id = q.id
   where q.session_slug = v_slug and q.ordem = v_s.pergunta_atual;

  if v_q.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Pergunta não encontrada.');
  end if;

  if p_escolha < 0 or p_escolha >= jsonb_array_length(v_q.alternativas) then
    return jsonb_build_object('ok', false, 'erro', 'Alternativa inválida.');
  end if;

  if exists (select 1 from quiz_answers
              where player_id = p_player and question_id = v_q.id) then
    return jsonb_build_object('ok', false, 'erro', 'Você já respondeu esta pergunta.');
  end if;

  -- Relógio do servidor. O tempo informado pelo cliente é ignorado.
  v_ms := greatest(0, (extract(epoch from (now() - v_s.aberta_em)) * 1000)::int);
  v_correta := (p_escolha = v_q.gabarito);

  -- Quem já saiu da aba nesta pergunta responde, mas não pontua: o acerto
  -- continua registrado para o relatório pedagógico, o ponto não.
  v_strike := exists (select 1 from quiz_strikes
                       where player_id = p_player and question_id = v_q.id);

  if v_correta and not v_strike then
    v_fracao := greatest(0, 1 - (v_ms / 1000.0) / v_q.segundos);
    -- acerto vale 600, a rapidez soma até 400, e o peso multiplica os dois
    v_pontos := round((600 + 400 * v_fracao) * v_q.peso);
  else
    v_pontos := 0;
  end if;

  insert into quiz_answers (player_id, question_id, escolha, correta, pontos, ms)
  values (p_player, v_q.id, p_escolha, v_correta, v_pontos, v_ms);

  return jsonb_build_object('ok', true, 'registrada', true, 'ms', v_ms);
end $$;

-- ---------------------------------------------------------------------
-- Strike. A página do aluno chama ao perder a aba ou o foco, em qualquer
-- estado; é aqui que se decide se havia pergunta aberta. Fora de
-- 'pergunta' nada acontece: sair no lobby ou na revelação é livre.
-- Se a resposta já tinha sido dada, o ponto dela é zerado agora.
-- ---------------------------------------------------------------------
create or replace function quiz_strike(p_player uuid, p_motivo text default 'aba')
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_slug text; v_s record; v_qid bigint; v_novo bool;
begin
  select session_slug into v_slug from quiz_players where id = p_player;
  if v_slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Jogador não encontrado.');
  end if;

  select * into v_s from quiz_sessions where slug = v_slug;
  if v_s.estado <> 'pergunta' then
    return jsonb_build_object('ok', true, 'strike', false);
  end if;

  select id into v_qid from quiz_questions
   where session_slug = v_slug and ordem = v_s.pergunta_atual;
  if v_qid is null then
    return jsonb_build_object('ok', true, 'strike', false);
  end if;

  insert into quiz_strikes (player_id, question_id, motivo)
  values (p_player, v_qid, case when p_motivo = 'foco' then 'foco' else 'aba' end)
  on conflict (player_id, question_id) do nothing;
  v_novo := found;

  update quiz_answers set pontos = 0
   where player_id = p_player and question_id = v_qid;

  return jsonb_build_object('ok', true, 'strike', true, 'novo', v_novo,
                            'ordem', v_s.pergunta_atual);
end $$;

-- ---------------------------------------------------------------------
-- Visão do aluno: uma chamada devolve tudo que a tela precisa, e nada além.
-- O gabarito entra na resposta somente quando o estado é 'revelacao'.
-- ---------------------------------------------------------------------
create or replace function quiz_estado(p_slug text, p_player uuid default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_s record; v_q record; v_total int; v_out jsonb;
  v_minha record; v_nome text;
begin
  select * into v_s from quiz_sessions where slug = p_slug;
  if v_s.slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão inexistente.');
  end if;

  select count(*) into v_total from quiz_questions where session_slug = p_slug;

  if p_player is not null then
    select nome into v_nome from quiz_players
     where id = p_player and session_slug = p_slug;
  end if;

  v_out := jsonb_build_object(
    'ok', true,
    'estado', v_s.estado,
    'titulo', v_s.titulo,
    'ordem', v_s.pergunta_atual,
    'total', v_total,
    'aberta_em', v_s.aberta_em,
    'servidor_agora', now(),
    'nome', v_nome,
    'jogadores', (select count(*) from quiz_players where session_slug = p_slug)
  );

  -- Enunciado, alternativas e peso da pergunta corrente, sem o gabarito.
  if v_s.estado in ('pergunta','revelacao') then
    select q.id, q.enunciado, q.alternativas, q.segundos, q.peso into v_q
      from quiz_questions q
     where q.session_slug = p_slug and q.ordem = v_s.pergunta_atual;

    v_out := v_out || jsonb_build_object('pergunta', jsonb_build_object(
      'id', v_q.id, 'enunciado', v_q.enunciado,
      'alternativas', v_q.alternativas, 'segundos', v_q.segundos, 'peso', v_q.peso));

    if p_player is not null then
      select escolha, correta, pontos into v_minha
        from quiz_answers where player_id = p_player and question_id = v_q.id;
      v_out := v_out || jsonb_build_object(
        'respondi', v_minha.escolha is not null,
        'minha_escolha', v_minha.escolha,
        'strike', exists (select 1 from quiz_strikes
                           where player_id = p_player and question_id = v_q.id));
    end if;
  end if;

  -- Gabarito: exposto só na revelação, junto do resultado individual.
  if v_s.estado = 'revelacao' then
    v_out := v_out || jsonb_build_object('gabarito', (
      select jsonb_build_object('correta', k.correta, 'explicacao', k.explicacao)
        from quiz_answer_key k where k.question_id = v_q.id));

    if p_player is not null then
      v_out := v_out || jsonb_build_object(
        'acertei', coalesce(v_minha.correta, false),
        'pontos_rodada', coalesce(v_minha.pontos, 0),
        'total_respostas', (select count(*) from quiz_answers where question_id = v_q.id));
    end if;
  end if;

  -- Encerrada a sessão, cada um recebe os temas em que errou, para orientar
  -- a retomada do estudo. É o recorte individual do relatório do professor.
  if v_s.estado = 'encerrado' and p_player is not null then
    v_out := v_out || jsonb_build_object('meus_temas', coalesce((
      select jsonb_agg(distinct jsonb_build_object('tema', q.tema, 'secao', q.secao))
        from quiz_answers a
        join quiz_questions q on q.id = a.question_id
       where a.player_id = p_player and not a.correta and q.tema is not null),
      '[]'::jsonb));
  end if;

  -- Placar acumulado: público por natureza, e é o que se projeta na sala.
  if v_s.estado in ('revelacao','encerrado') then
    v_out := v_out || jsonb_build_object('ranking', coalesce((
      select jsonb_agg(r) from (
        select p.nome,
               coalesce(sum(a.pontos), 0)::int                                  as pontos,
               coalesce(count(a.question_id) filter (where a.correta), 0)::int  as acertos,
               (select count(*) from quiz_strikes st where st.player_id = p.id)::int as strikes,
               (p.id = p_player)                                                as eu
          from quiz_players p
          left join quiz_answers a on a.player_id = p.id
         where p.session_slug = p_slug
         group by p.id, p.nome
         order by pontos desc, acertos desc, p.nome
         limit 50
      ) r), '[]'::jsonb));
  end if;

  return v_out;
end $$;

-- ---------------------------------------------------------------------
-- Painel do professor. O token é verificado aqui dentro e nunca trafega de volta.
-- ---------------------------------------------------------------------
create or replace function quiz_host(p_slug text, p_token text, p_acao text default 'ver')
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ok bool; v_s record; v_total int; v_out jsonb; v_qid bigint;
        v_arquivadas int := 0;
begin
  select exists (select 1 from quiz_host_tokens
                  where session_slug = p_slug and token = p_token) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  select * into v_s from quiz_sessions where slug = p_slug;
  select count(*) into v_total from quiz_questions where session_slug = p_slug;

  case p_acao
    when 'ver' then
      null;   -- somente leitura

    when 'abrir' then
      -- Abre a pergunta seguinte, ou a primeira se ainda estamos no lobby.
      update quiz_sessions
         set estado = 'pergunta',
             pergunta_atual = least(greatest(v_s.pergunta_atual, 0) + 1, v_total),
             aberta_em = now()
       where slug = p_slug;

    when 'reabrir' then
      -- Reabre a pergunta corrente, para quando a rede da sala oscila.
      update quiz_sessions set estado = 'pergunta', aberta_em = now() where slug = p_slug;

    when 'revelar' then
      update quiz_sessions set estado = 'revelacao' where slug = p_slug;

    when 'encerrar' then
      update quiz_sessions set estado = 'encerrado' where slug = p_slug;

    when 'reiniciar' then
      -- Arquiva antes de apagar: o reinício deixa de destruir o resultado da
      -- turma e passa a acumulá-lo em quiz_relatorios (quiz-ingestao.sql).
      -- Nada é gravado quando não há resposta. Os strikes saem junto com os
      -- jogadores, pela cascata de quiz_strikes.
      v_arquivadas := quiz_arquivar(p_slug);

      delete from quiz_answers
       where player_id in (select id from quiz_players where session_slug = p_slug);
      delete from quiz_players where session_slug = p_slug;
      update quiz_sessions
         set estado = 'lobby', pergunta_atual = 0, aberta_em = null
       where slug = p_slug;

    when 'descartar' then
      -- Reinício sem arquivar, para a rodada que não é de turma: é o que
      -- scripts/quiz-e2e.mjs usa, para não lançar jogador de teste na série.
      delete from quiz_answers
       where player_id in (select id from quiz_players where session_slug = p_slug);
      delete from quiz_players where session_slug = p_slug;
      update quiz_sessions
         set estado = 'lobby', pergunta_atual = 0, aberta_em = null
       where slug = p_slug;

    else
      return jsonb_build_object('ok', false, 'erro', 'Ação desconhecida.');
  end case;

  select * into v_s from quiz_sessions where slug = p_slug;
  select id into v_qid from quiz_questions
   where session_slug = p_slug and ordem = v_s.pergunta_atual;

  v_out := jsonb_build_object(
    'ok', true,
    'estado', v_s.estado,
    'titulo', v_s.titulo,
    'arquivadas', v_arquivadas,
    'ordem', v_s.pergunta_atual,
    'total', v_total,
    'aberta_em', v_s.aberta_em,
    'servidor_agora', now(),
    'jogadores', (select count(*) from quiz_players where session_slug = p_slug),
    'nomes', coalesce((select jsonb_agg(nome order by criado_em desc)
                         from quiz_players where session_slug = p_slug), '[]'::jsonb),
    'respostas', coalesce((select count(*) from quiz_answers where question_id = v_qid), 0),
    'strikes', coalesce((select count(*) from quiz_strikes where question_id = v_qid), 0)
  );

  -- O professor vê enunciado, gabarito e distribuição para conduzir a discussão.
  if v_qid is not null then
    v_out := v_out || jsonb_build_object('pergunta', (
      select jsonb_build_object('enunciado', q.enunciado, 'alternativas', q.alternativas,
                                'segundos', q.segundos, 'peso', q.peso,
                                'correta', k.correta, 'explicacao', k.explicacao)
        from quiz_questions q join quiz_answer_key k on k.question_id = q.id
       where q.id = v_qid));

    v_out := v_out || jsonb_build_object('distribuicao', coalesce((
      select jsonb_object_agg(escolha::text, n) from (
        select escolha, count(*)::int as n from quiz_answers
         where question_id = v_qid group by escolha) d), '{}'::jsonb));
  end if;

  v_out := v_out || jsonb_build_object('ranking', coalesce((
    select jsonb_agg(r) from (
      select p.nome,
             coalesce(sum(a.pontos), 0)::int                                  as pontos,
             coalesce(count(a.question_id) filter (where a.correta), 0)::int  as acertos,
             (select count(*) from quiz_strikes st where st.player_id = p.id)::int as strikes
        from quiz_players p
        left join quiz_answers a on a.player_id = p.id
       where p.session_slug = p_slug
       group by p.id, p.nome
       order by pontos desc, acertos desc, p.nome
       limit 50
    ) r), '[]'::jsonb));

  return v_out;
end $$;

-- As quatro são RPCs públicas por desenho: a credencial de cada uma é o uuid
-- do jogador ou o token do professor, conferidos lá dentro.
revoke all on function quiz_responder(uuid,int)     from public;
revoke all on function quiz_strike(uuid,text)       from public;
revoke all on function quiz_estado(text,uuid)       from public;
revoke all on function quiz_host(text,text,text)    from public;
grant execute on function quiz_responder(uuid,int)  to anon, authenticated;
grant execute on function quiz_strike(uuid,text)    to anon, authenticated;
grant execute on function quiz_estado(text,uuid)    to anon, authenticated;
grant execute on function quiz_host(text,text,text) to anon, authenticated;
