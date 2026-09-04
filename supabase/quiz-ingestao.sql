-- =====================================================================
-- Ingestão dos relatórios do quiz — a série histórica das turmas
--
-- Reiniciar uma sala apaga jogadores e respostas. Esta tabela guarda o
-- resultado imediatamente antes do apagamento, de modo que a série das
-- turmas se acumule sem depender de alguém lembrar de exportar o CSV.
-- A mesma sala é jogada pelas três turmas de Qualidade 2026.2 (uma por
-- dia da semana), então o histórico acumula uma linha por rodada.
--
-- Três colunas, como área de recepção:
--   ts        instante do arquivamento, em unixtime (segundos)
--   data      linhas do relatório, no grão de uma resposta por estudante
--             e questão — de onde qualquer agregação pode ser refeita
--   data_tag  origem, no padrão PERIODO-sala (2026-2-atam-q2-a05)
--
-- Rodar depois de quiz-schema.sql e quiz-relatorio.sql, e ANTES dos
-- seeds — eles gravam o período na sessão. Não destrói dado algum.
-- =====================================================================

-- Período que cursou a sessão (2026-2, 2027-1, ...). Compõe a data_tag.
alter table quiz_sessions add column if not exists periodo text;

create table if not exists quiz_relatorios (
  ts       bigint not null,
  data     jsonb  not null,
  data_tag text   not null,
  primary key (data_tag, ts)
);

comment on table quiz_relatorios is
  'Recepção dos relatórios de quiz arquivados no reinício da sala.';

-- Sem policy: o histórico não é legível pela chave publicável. Ele é lido
-- no SQL Editor do painel, onde a análise de várias turmas faz sentido.
alter table quiz_relatorios enable row level security;
revoke all on quiz_relatorios from anon, authenticated;

create index if not exists quiz_relatorios_tag on quiz_relatorios (data_tag, ts desc);

-- ---------------------------------------------------------------------
-- Montagem das linhas de uma sessão, no grão de resposta.
-- Isolada em função própria para servir tanto ao arquivamento automático
-- quanto a uma exportação avulsa no SQL Editor.
-- ---------------------------------------------------------------------
create or replace function quiz_linhas(p_slug text)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(l order by l->>'nome', (l->>'ordem')::int), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'nome', p.nome,
               'ordem', q.ordem,
               'tema', q.tema,
               'secao', q.secao,
               'enunciado', q.enunciado,
               'escolha', a.escolha,
               'correta', k.correta,
               'acertou', a.correta,
               'pontos', a.pontos,
               'ms', a.ms,
               'respondida_em', a.respondida_em
             ) as l
        from quiz_answers a
        join quiz_players p    on p.id = a.player_id
        join quiz_questions q  on q.id = a.question_id
        join quiz_answer_key k on k.question_id = q.id
       where p.session_slug = p_slug
    ) s;
$$;

-- ---------------------------------------------------------------------
-- Arquiva a sessão corrente. Devolve o número de linhas gravadas.
-- Nada grava quando não há resposta, para não poluir a série com
-- reinícios de sala vazia.
-- ---------------------------------------------------------------------
create or replace function quiz_arquivar(p_slug text)
returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_linhas jsonb; v_tag text; v_n int;
begin
  v_linhas := quiz_linhas(p_slug);
  v_n := jsonb_array_length(v_linhas);
  if v_n = 0 then return 0; end if;

  -- Padrão PERIODO-sala, p. ex. "2026-2-atam-q2-a05". O período vem da
  -- própria sessão, gravado pelo seed; o instante distingue as rodadas —
  -- e, com o dia da semana de config/semestres.json, a turma que jogou.
  select coalesce(periodo, 'sem-periodo') || '-' || p_slug into v_tag
    from quiz_sessions where slug = p_slug;

  insert into quiz_relatorios (ts, data, data_tag)
  values (extract(epoch from now())::bigint, v_linhas, v_tag)
  on conflict (data_tag, ts) do update set data = excluded.data;

  return v_n;
end $$;

-- Chamadas apenas de dentro de quiz_host: nada aqui pode ser exposto à API.
--
-- Revogar de PUBLIC não basta no Supabase: o projeto concede EXECUTE a anon e
-- authenticated por default privilege em toda função nova do schema public, e
-- esse grant sobrevive ao revoke de PUBLIC. Sem as duas linhas de baixo,
-- POST /rest/v1/rpc/quiz_linhas devolveria, com a chave publicável que está no
-- HTML, o nome de cada estudante, a escolha de cada um e o gabarito — ao vivo,
-- no meio da rodada. Estas funções são SECURITY DEFINER: quem as chama de
-- dentro de quiz_host continua podendo, porque ali o dono é o executor.
revoke all on function quiz_linhas(text)   from public, anon, authenticated;
revoke all on function quiz_arquivar(text) from public, anon, authenticated;
