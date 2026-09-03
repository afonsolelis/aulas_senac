-- =====================================================================
-- Quiz ao vivo — esquema, RLS e RPCs
-- Projeto: lwamaovuxcevsjfvtqhf (Supabase do Hub de Aulas Senac)
--
-- Desenho de acesso: apenas quiz_sessions é legível pela API, porque não
-- guarda segredo algum — é o que permite ao Realtime notificar os alunos.
-- Todas as outras tabelas têm RLS habilitada e NENHUMA policy: anon e
-- authenticated não leem nem escrevem uma linha delas por chamada direta.
-- Tudo passa pelas funções SECURITY DEFINER do final, que devolvem
-- veredito e placar, nunca gabarito nem credencial de outro jogador.
--
-- Rodar inteiro no SQL Editor do painel. É idempotente: recria as tabelas do
-- quiz e apaga as respostas anteriores. A série histórica (quiz_relatorios,
-- em quiz-ingestao.sql) não é tocada aqui — ela não referencia estas tabelas
-- justamente para sobreviver a um recomeço do esquema.
-- Em seguida: quiz-relatorio.sql, quiz-ingestao.sql, quiz-gabarito.sql e o
-- seed da aula. A ação 'reiniciar' abaixo depende de quiz-ingestao.sql.
-- =====================================================================

drop table if exists quiz_answers      cascade;
drop table if exists quiz_answer_key   cascade;
drop table if exists quiz_questions    cascade;
drop table if exists quiz_players      cascade;
drop table if exists quiz_host_tokens  cascade;
drop table if exists quiz_sessions     cascade;

-- ---------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------

-- Estado da sessão. Deliberadamente sem nenhum dado sigiloso, para que
-- possa ser lida por todos e replicada pelo Realtime.
create table quiz_sessions (
  slug            text primary key,
  titulo          text        not null,
  estado          text        not null default 'lobby'
                  check (estado in ('lobby','pergunta','revelacao','encerrado')),
  pergunta_atual  int         not null default 0,
  aberta_em       timestamptz,
  criada_em       timestamptz not null default now()
);

-- Segredo do professor, isolado da tabela de estado justamente para que
-- quiz_sessions possa ser pública.
create table quiz_host_tokens (
  session_slug text primary key references quiz_sessions(slug) on delete cascade,
  token        text not null
);

create table quiz_questions (
  id           bigint generated always as identity primary key,
  session_slug text   not null references quiz_sessions(slug) on delete cascade,
  ordem        int    not null,
  enunciado    text   not null,
  alternativas jsonb  not null,
  segundos     int    not null default 40,
  tema         text,          -- assunto avaliado, usado no relatório
  secao        text,          -- seção do material de leitura correspondente
  unique (session_slug, ordem)
);

-- Gabarito. Nunca sai daqui a não ser como veredito calculado.
create table quiz_answer_key (
  question_id bigint primary key references quiz_questions(id) on delete cascade,
  correta     int  not null,
  explicacao  text
);

-- O id do jogador é a credencial dele: fica no localStorage do celular e
-- é o que autoriza responder. Por isso a tabela não é legível pela API.
create table quiz_players (
  id           uuid primary key default gen_random_uuid(),
  session_slug text not null references quiz_sessions(slug) on delete cascade,
  nome         text not null,
  criado_em    timestamptz not null default now()
);

-- Nome único por sessão, sem diferenciar maiúsculas.
create unique index quiz_players_nome_unico
  on quiz_players (session_slug, lower(nome));

create table quiz_answers (
  player_id     uuid   not null references quiz_players(id) on delete cascade,
  question_id   bigint not null references quiz_questions(id) on delete cascade,
  escolha       int    not null,
  correta       bool   not null,
  pontos        int    not null,
  ms            int    not null,
  respondida_em timestamptz not null default now(),
  primary key (player_id, question_id)   -- uma resposta por pergunta, sem troca
);

-- ---------------------------------------------------------------------
-- RLS — negar por omissão
-- ---------------------------------------------------------------------

alter table quiz_sessions    enable row level security;
alter table quiz_host_tokens enable row level security;
alter table quiz_questions   enable row level security;
alter table quiz_answer_key  enable row level security;
alter table quiz_players     enable row level security;
alter table quiz_answers     enable row level security;

-- A única policy do esquema. Sem ela o Realtime não entrega evento ao anon.
create policy sessions_leitura on quiz_sessions
  for select to anon, authenticated using (true);

-- Nenhuma policy de INSERT, UPDATE ou DELETE em tabela alguma: um aluno
-- não cria jogador, não lança ponto e não muda o estado por chamada direta.
-- Reforço explícito sobre os grants amplos que o Supabase concede ao
-- schema public — a RLS já bloquearia, isto torna a intenção inequívoca.
revoke all on quiz_answer_key  from anon, authenticated;
revoke all on quiz_host_tokens from anon, authenticated;
revoke all on quiz_players     from anon, authenticated;
revoke all on quiz_answers     from anon, authenticated;
revoke all on quiz_questions   from anon, authenticated;

-- ---------------------------------------------------------------------
-- Funções — toda leitura sensível e toda escrita acontecem aqui
-- ---------------------------------------------------------------------

-- Cadastro do aluno. Devolve o uuid, que é a credencial dele daí em diante.
create or replace function quiz_entrar(p_slug text, p_nome text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_nome text; v_id uuid;
begin
  v_nome := btrim(regexp_replace(coalesce(p_nome,''), '\s+', ' ', 'g'));

  if char_length(v_nome) < 2 or char_length(v_nome) > 24 then
    return jsonb_build_object('ok', false, 'erro', 'O nome deve ter entre 2 e 24 caracteres.');
  end if;

  if not exists (select 1 from quiz_sessions where slug = p_slug) then
    return jsonb_build_object('ok', false, 'erro', 'Sessão inexistente.');
  end if;

  if exists (select 1 from quiz_players
              where session_slug = p_slug and lower(nome) = lower(v_nome)) then
    return jsonb_build_object('ok', false, 'erro', 'Esse nome já está em uso nesta sala. Escolha outro.');
  end if;

  insert into quiz_players (session_slug, nome) values (p_slug, v_nome)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'player_id', v_id, 'nome', v_nome);
end $$;

-- Registro da resposta. Não informa se acertou: o veredito aparece apenas
-- quando o professor revela, o que impede repassar gabarito à turma.
create or replace function quiz_responder(p_player uuid, p_escolha int)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_slug text; v_q record; v_s record;
  v_ms int; v_correta bool; v_pontos int; v_fracao numeric;
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

  if v_correta then
    v_fracao := greatest(0, 1 - (v_ms / 1000.0) / v_q.segundos);
    v_pontos := round(600 + 400 * v_fracao);   -- acerto vale 600, a rapidez soma até 400
  else
    v_pontos := 0;
  end if;

  insert into quiz_answers (player_id, question_id, escolha, correta, pontos, ms)
  values (p_player, v_q.id, p_escolha, v_correta, v_pontos, v_ms);

  return jsonb_build_object('ok', true, 'registrada', true, 'ms', v_ms);
end $$;

-- Visão do aluno: uma chamada devolve tudo que a tela precisa, e nada além.
-- O gabarito entra na resposta somente quando o estado é 'revelacao'.
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

  -- Enunciado e alternativas da pergunta corrente, sem o gabarito.
  if v_s.estado in ('pergunta','revelacao') then
    select q.id, q.enunciado, q.alternativas, q.segundos into v_q
      from quiz_questions q
     where q.session_slug = p_slug and q.ordem = v_s.pergunta_atual;

    v_out := v_out || jsonb_build_object('pergunta', jsonb_build_object(
      'id', v_q.id, 'enunciado', v_q.enunciado,
      'alternativas', v_q.alternativas, 'segundos', v_q.segundos));

    if p_player is not null then
      select escolha, correta, pontos into v_minha
        from quiz_answers where player_id = p_player and question_id = v_q.id;
      v_out := v_out || jsonb_build_object('respondi', v_minha.escolha is not null,
                                           'minha_escolha', v_minha.escolha);
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
               coalesce(sum(a.pontos), 0)::int                       as pontos,
               coalesce(count(a.question_id) filter (where a.correta), 0)::int  as acertos,
               (p.id = p_player)                                     as eu
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

-- Painel do professor. O token é verificado aqui dentro e nunca trafega de volta.
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
      -- Nada é gravado quando não há resposta.
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
    'respostas', coalesce((select count(*) from quiz_answers where question_id = v_qid), 0)
  );

  -- O professor vê enunciado, gabarito e distribuição para conduzir a discussão.
  if v_qid is not null then
    v_out := v_out || jsonb_build_object('pergunta', (
      select jsonb_build_object('enunciado', q.enunciado, 'alternativas', q.alternativas,
                                'segundos', q.segundos, 'correta', k.correta,
                                'explicacao', k.explicacao)
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
             coalesce(sum(a.pontos), 0)::int                      as pontos,
             coalesce(count(a.question_id) filter (where a.correta), 0)::int as acertos
        from quiz_players p
        left join quiz_answers a on a.player_id = p.id
       where p.session_slug = p_slug
       group by p.id, p.nome
       order by pontos desc, acertos desc, p.nome
       limit 50
    ) r), '[]'::jsonb));

  return v_out;
end $$;

revoke all on function quiz_entrar(text,text)       from public;
revoke all on function quiz_responder(uuid,int)     from public;
revoke all on function quiz_estado(text,uuid)       from public;
revoke all on function quiz_host(text,text,text)    from public;
grant execute on function quiz_entrar(text,text)    to anon, authenticated;
grant execute on function quiz_responder(uuid,int)  to anon, authenticated;
grant execute on function quiz_estado(text,uuid)    to anon, authenticated;
grant execute on function quiz_host(text,text,text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Realtime: o aluno recebe a virada de estado sem precisar perguntar.
-- Apenas quiz_sessions, a única tabela sem conteúdo sigiloso.
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table quiz_sessions;
exception when duplicate_object then null;
end $$;
