-- =====================================================================
-- TBL ao vivo — tabelas, RLS e Realtime
-- Projeto: lwamaovuxcevsjfvtqhf (COMPARTILHADO com o projeto Einstein)
--
-- Dinâmica de aprendizagem baseada em equipes (Team-Based Learning) sobre
-- um caso único, percorrido por uma sequência de questões. Cada questão
-- apresenta quatro táticas com ganho e custo declarados. Nenhuma é
-- correta: o que se mede é o deslocamento das escolhas entre a decisão
-- individual e a decisão posterior à discussão.
--
-- Portado de ~/repos/aulas (supabase/tbl-schema.sql), com duas mudanças
-- obrigatórias por este banco ser compartilhado:
--   1. Prefixo hubtbl_. O prefixo tbl_ pertence ao Einstein
--      (tbl_sessions, tbl_participants, tbl_votes, tbl_host, ...).
--   2. Nenhum drop. O original começava por "drop table ... cascade";
--      aqui tudo é "if not exists", e o arquivo pode ser reaplicado sem
--      destruir sala, votos ou histórico. Ver
--      .claude/skills/supabase-compartilhado/SKILL.md.
--
-- Cada questão percorre as fases voto1 → discussao → voto2 → sintese.
-- Uma questão pode trazer um dado novo, liberado só quando a discussão
-- é aberta pelo professor.
--
-- Desenho de acesso:
--   hubtbl_sessions   legível pela API: guarda apenas fase, questão e prazo.
--                     É o que permite ao Realtime virar a tela da turma.
--   demais tabelas    RLS habilitada e nenhuma policy; tudo passa pelas
--                     funções security definer de hubtbl-funcoes.sql, que
--                     entregam só a questão corrente e só liberam o dado
--                     novo a partir da discussão.
--
-- Ordem de aplicação:
--   hubtbl-schema.sql → hubtbl-funcoes.sql → hubtbl-seed-<aula>.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------

-- Estado da sala. Sem enunciado e sem alternativas, para poder ser lida
-- por todos e replicada pelo Realtime sem antecipar conteúdo.
--   lobby     sala aberta, leitura do caso liberada, votação fechada
--   voto1     decisão individual, sem informação sobre a turma
--   discussao distribuição e justificativas à vista; libera o dado novo
--   voto2     segunda decisão, após a discussão
--   sintese   fechamento da questão, com as duas distribuições
--   revelacao consolidado de todas as questões
create table if not exists hubtbl_sessions (
  slug            text primary key,
  titulo          text not null,
  fase            text not null default 'lobby'
                  check (fase in ('lobby','voto1','discussao','voto2','sintese','revelacao')),
  questao         smallint not null default 1 check (questao >= 1),
  -- O prazo fecha a votação, mas não avança a fase: a passagem é sempre
  -- ato do professor, para a discussão presencial não ser atropelada.
  fase_termina_em timestamptz,
  aberta_em       timestamptz,
  criada_em       timestamptz not null default now()
);

-- Segredo do professor, fora da tabela de estado para que ela possa ser
-- pública. O valor é o mesmo token dos painéis de quiz.
create table if not exists hubtbl_host_tokens (
  session_slug text primary key references hubtbl_sessions(slug) on delete cascade,
  token        text not null
);

-- Contexto comum do caso, válido para todas as questões da sala.
create table if not exists hubtbl_casos (
  session_slug  text primary key references hubtbl_sessions(slug) on delete cascade,
  caso_titulo   text  not null,
  caso_texto    text  not null,
  contexto      jsonb not null default '[]'::jsonb   -- indicadores projetados
);

-- Cada alternativa: {letra, titulo, tatica, texto, ganho, custo}.
-- O dado novo: {titulo, texto, evidencias[], pergunta}.
create table if not exists hubtbl_questoes (
  session_slug  text     not null references hubtbl_sessions(slug) on delete cascade,
  ordem         smallint not null check (ordem >= 1),
  categoria     text     not null,
  titulo        text     not null,
  pergunta      text     not null,
  alternativas  jsonb    not null
                check (jsonb_typeof(alternativas) = 'array'
                       and jsonb_array_length(alternativas) = 4),
  dado_novo     jsonb,
  primary key (session_slug, ordem)
);

-- O id do participante é a credencial dele (fica no localStorage do
-- aparelho). Por isso a tabela não é legível.
create table if not exists hubtbl_participantes (
  id           uuid primary key default gen_random_uuid(),
  session_slug text not null references hubtbl_sessions(slug) on delete cascade,
  nome         text not null,
  entrou_em    timestamptz not null default now(),
  visto_em     timestamptz not null default now()
);

create unique index if not exists hubtbl_participantes_nome_unico
  on hubtbl_participantes (session_slug, lower(nome));

-- Uma linha por participante, questão e rodada.
create table if not exists hubtbl_votos (
  session_slug    text     not null references hubtbl_sessions(slug) on delete cascade,
  participante_id uuid     not null references hubtbl_participantes(id) on delete cascade,
  questao         smallint not null check (questao >= 1),
  rodada          smallint not null check (rodada in (1,2)),
  escolha         smallint not null check (escolha between 0 and 3),
  justificativa   text     not null default '',
  votado_em       timestamptz not null default now(),
  primary key (session_slug, participante_id, questao, rodada)
);

create index if not exists hubtbl_votos_questao on hubtbl_votos (session_slug, questao, rodada);

-- Histórico: a mesma sala é jogada por mais de uma turma. "reiniciar"
-- guarda aqui a rodada inteira (consolidado e decisões com nome e
-- justificativa) antes de apagar participantes e votos.
create table if not exists hubtbl_historico (
  id            bigint generated always as identity primary key,
  session_slug  text        not null,
  arquivado_em  timestamptz not null default now(),
  participantes int         not null,
  consolidado   jsonb       not null,
  decisoes      jsonb       not null
);

create index if not exists hubtbl_historico_sala on hubtbl_historico (session_slug, arquivado_em);

-- ---------------------------------------------------------------------
-- RLS — negar por omissão
-- ---------------------------------------------------------------------

alter table hubtbl_sessions      enable row level security;
alter table hubtbl_host_tokens   enable row level security;
alter table hubtbl_casos         enable row level security;
alter table hubtbl_questoes      enable row level security;
alter table hubtbl_participantes enable row level security;
alter table hubtbl_votos         enable row level security;
alter table hubtbl_historico     enable row level security;

-- A única policy do esquema. Sem ela o Realtime não entrega a virada de
-- fase ao anon. Criada só se ainda não existir, para o arquivo ser
-- reaplicável sem drop.
do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'hubtbl_sessions'
                    and policyname = 'hubtbl_sessions_leitura') then
    create policy hubtbl_sessions_leitura on hubtbl_sessions
      for select to anon, authenticated using (true);
  end if;
end $$;

-- Reforço sobre os grants amplos que o Supabase concede ao schema public.
revoke all on hubtbl_sessions      from anon, authenticated;
grant select on hubtbl_sessions    to anon, authenticated;
revoke all on hubtbl_host_tokens   from anon, authenticated;
revoke all on hubtbl_casos         from anon, authenticated;
revoke all on hubtbl_questoes      from anon, authenticated;
revoke all on hubtbl_participantes from anon, authenticated;
revoke all on hubtbl_votos         from anon, authenticated;
revoke all on hubtbl_historico     from anon, authenticated;

-- ---------------------------------------------------------------------
-- Realtime: só hubtbl_sessions, a única tabela sem conteúdo reservado.
-- Apenas ADICIONA a tabela à publicação; nunca remove outra.
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public'
                    and tablename = 'hubtbl_sessions') then
    alter publication supabase_realtime add table hubtbl_sessions;
  end if;
exception
  when undefined_object then null;   -- Postgres local, sem a publicação do Supabase
end $$;

-- As funções (RPCs) estão em hubtbl-funcoes.sql. Aplique-o em seguida.
