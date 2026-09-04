-- =====================================================================
-- Banco de questões e relatórios — a leitura pública do quiz
--
-- É o relatório do professor menos a aba "Estudantes": as oito questões
-- com gabarito e explicação, e o desempenho de CADA RODADA em que a sala
-- foi jogada — por questão e por tema, nunca por pessoa. Nenhuma função
-- daqui devolve nome de aluno; o nome entra apenas dentro do agregado,
-- para contar participantes, e não sai.
--
-- Fonte: quiz_relatorios (a série arquivada em quiz-ingestao.sql), e não
-- as tabelas ao vivo — por isso o banco continua de pé depois que a sala
-- é zerada para a turma seguinte.
--
-- Publicação é ato explícito do professor (quiz_publicar). A mesma sala é
-- jogada pelas três turmas ao longo da semana: publicar antes da última
-- entregaria o gabarito a quem ainda vai jogar. Enquanto publicado_em for
-- nulo, quiz_banco recusa a sala.
--
-- Rodar depois de quiz-schema.sql, quiz-relatorio.sql e quiz-ingestao.sql.
-- Não destrói dado algum: pode ser aplicado com o semestre em andamento.
-- =====================================================================

-- Marca da liberação. Fica em quiz_sessions, que já é pública por desenho:
-- saber que um banco existe não revela nada — o conteúdo vem por função.
alter table quiz_sessions add column if not exists publicado_em timestamptz;

comment on column quiz_sessions.publicado_em is
  'Quando o professor liberou o banco desta sala para os alunos. Nulo = não publicado.';

-- ---------------------------------------------------------------------
-- Piso de privacidade
--
-- Numa rodada de poucos participantes, a distribuição por alternativa
-- volta a ser desempenho individual: com dois jogadores, "1 escolheu B"
-- identifica alguém. Rodadas abaixo deste piso ficam fora do banco —
-- também é o que mantém rodada de teste longe da vista dos alunos.
-- ---------------------------------------------------------------------
create or replace function quiz_banco_piso()
returns int language sql immutable as $$ select 3 $$;

-- ---------------------------------------------------------------------
-- Salas publicadas. Alimenta o seletor de aulas da página do banco.
-- ---------------------------------------------------------------------
create or replace function quiz_banco_salas()
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(x order by (x->>'publicado_em')::timestamptz desc), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'slug',         s.slug,
               'titulo',       s.titulo,
               'periodo',      s.periodo,
               'publicado_em', s.publicado_em,
               'questoes',     (select count(*) from quiz_questions q
                                 where q.session_slug = s.slug),
               'rodadas',      (select count(*) from quiz_relatorios r
                                 where r.data_tag = coalesce(s.periodo, 'sem-periodo') || '-' || s.slug
                                   and (select count(distinct l->>'nome')
                                          from jsonb_array_elements(r.data) l) >= quiz_banco_piso())
             ) as x
        from quiz_sessions s
       where s.publicado_em is not null
    ) t;
$$;

-- ---------------------------------------------------------------------
-- O banco de uma sala: perguntas com gabarito + desempenho por rodada e
-- consolidado. Sem token: o que sai daqui é o que o professor já decidiu
-- tornar público ao publicar.
-- ---------------------------------------------------------------------
create or replace function quiz_banco(p_slug text)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_s         record;
  v_tag       text;
  v_perguntas jsonb;
  v_agregado  jsonb;
begin
  select * into v_s from quiz_sessions where slug = p_slug;

  if v_s.slug is null or v_s.publicado_em is null then
    return jsonb_build_object('ok', false,
      'erro', 'Este banco ainda não foi publicado pelo professor.');
  end if;

  v_tag := coalesce(v_s.periodo, 'sem-periodo') || '-' || p_slug;

  -- As perguntas vêm das tabelas ao vivo: a sala da aula continua cadastrada
  -- depois de zerada, e é lá que estão o texto das alternativas e a
  -- explicação (o arquivo guarda a escolha, não o enunciado das opções).
  select coalesce(jsonb_agg(jsonb_build_object(
           'ordem', q.ordem, 'enunciado', q.enunciado, 'alternativas', q.alternativas,
           'correta', k.correta, 'explicacao', k.explicacao,
           'tema', q.tema, 'secao', q.secao) order by q.ordem), '[]'::jsonb)
    into v_perguntas
    from quiz_questions q
    join quiz_answer_key k on k.question_id = q.id
   where q.session_slug = p_slug;

  with bruto as (
    select r.ts, r.data from quiz_relatorios r where r.data_tag = v_tag
  ),
  -- Uma linha por resposta de todas as rodadas. O nome existe só aqui.
  lin as (
    select b.ts,
           l->>'nome'            as nome,
           (l->>'ordem')::int    as ordem,
           l->>'tema'            as tema,
           l->>'secao'           as secao,
           (l->>'escolha')::int  as escolha,
           (l->>'acertou')::bool as acertou
      from bruto b, jsonb_array_elements(b.data) l
  ),
  validas as (
    select ts from lin group by ts having count(distinct nome) >= quiz_banco_piso()
  ),
  ok as (
    select l.* from lin l join validas v on v.ts = l.ts
  ),
  dist as (
    select ts, ordem, escolha, count(*)::int as c from ok group by 1, 2, 3
  ),
  q_rod as (
    select o.ts, o.ordem,
           count(*)::int                          as respostas,
           count(*) filter (where o.acertou)::int as acertos,
           round(100.0 * count(*) filter (where o.acertou) / count(*), 1) as taxa,
           (select coalesce(jsonb_object_agg(d.escolha::text, d.c), '{}'::jsonb)
              from dist d where d.ts = o.ts and d.ordem = o.ordem) as distribuicao
      from ok o group by o.ts, o.ordem
  ),
  t_rod as (
    select o.ts, o.tema, min(o.secao) as secao,
           count(*)::int                          as respostas,
           count(*) filter (where o.acertou)::int as acertos,
           round(100.0 * count(*) filter (where o.acertou) / count(*), 1) as taxa
      from ok o group by o.ts, o.tema
  ),
  -- A numeração é a ordem em que as turmas jogaram, que é o que o carimbo
  -- de arquivamento ordena com segurança. O dia da semana não identifica a
  -- turma: o professor reinicia entre as aulas, e o reinício pode cair no
  -- dia seguinte — por isso a rodada é "Rodada N", não "turma tal".
  rod as (
    select o.ts,
           row_number() over (order by o.ts)      as n,
           count(distinct o.nome)::int            as participantes,
           count(*)::int                          as respostas,
           count(*) filter (where o.acertou)::int as acertos,
           round(100.0 * count(*) filter (where o.acertou) / count(*), 1) as taxa
      from ok o group by o.ts
  ),
  -- Consolidado de todas as rodadas: o que a disciplina inteira errou.
  dist_geral as (
    select ordem, escolha, count(*)::int as c from ok group by 1, 2
  ),
  q_geral as (
    select o.ordem,
           count(*)::int                          as respostas,
           count(*) filter (where o.acertou)::int as acertos,
           round(100.0 * count(*) filter (where o.acertou) / count(*), 1) as taxa,
           (select coalesce(jsonb_object_agg(d.escolha::text, d.c), '{}'::jsonb)
              from dist_geral d where d.ordem = o.ordem) as distribuicao
      from ok o group by o.ordem
  ),
  t_geral as (
    select o.tema, min(o.secao) as secao,
           count(*)::int                          as respostas,
           count(*) filter (where o.acertou)::int as acertos,
           round(100.0 * count(*) filter (where o.acertou) / count(*), 1) as taxa
      from ok o group by o.tema
  )
  select jsonb_build_object(
    'rodadas', coalesce((select jsonb_agg(jsonb_build_object(
        'n',             rod.n,
        'quando',        to_char(to_timestamp(rod.ts) at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
        'participantes', rod.participantes,
        'respostas',     rod.respostas,
        'acertos',       rod.acertos,
        'taxa',          rod.taxa,
        'questoes', coalesce((select jsonb_agg(jsonb_build_object(
              'ordem', q.ordem, 'respostas', q.respostas, 'acertos', q.acertos,
              'taxa', q.taxa, 'distribuicao', q.distribuicao) order by q.ordem)
            from q_rod q where q.ts = rod.ts), '[]'::jsonb),
        'temas', coalesce((select jsonb_agg(jsonb_build_object(
              'tema', t.tema, 'secao', t.secao, 'respostas', t.respostas,
              'acertos', t.acertos, 'taxa', t.taxa) order by t.taxa, t.tema)
            from t_rod t where t.ts = rod.ts), '[]'::jsonb)
      ) order by rod.n) from rod), '[]'::jsonb),

    -- Ordenados do mais errado ao mais acertado: taxa é numeric aqui, então
    -- 9,0 vem antes de 12,5 e de 100,0 — o que a ordenação por texto erra.
    'questoes', coalesce((select jsonb_agg(jsonb_build_object(
        'ordem', q.ordem, 'respostas', q.respostas, 'acertos', q.acertos,
        'taxa', q.taxa, 'distribuicao', q.distribuicao) order by q.taxa, q.ordem)
      from q_geral q), '[]'::jsonb),

    'temas', coalesce((select jsonb_agg(jsonb_build_object(
        'tema', t.tema, 'secao', t.secao, 'respostas', t.respostas,
        'acertos', t.acertos, 'taxa', t.taxa) order by t.taxa, t.tema)
      from t_geral t), '[]'::jsonb)
  ) into v_agregado;

  return jsonb_build_object(
    'ok', true,
    'slug', v_s.slug,
    'titulo', v_s.titulo,
    'periodo', v_s.periodo,
    'publicado_em', v_s.publicado_em,
    'piso', quiz_banco_piso(),
    'total_questoes', jsonb_array_length(v_perguntas),
    'perguntas', v_perguntas
  ) || v_agregado;
end $$;

-- ---------------------------------------------------------------------
-- Publicação — o único caminho para o banco ficar visível.
--
-- 'publicar' fecha a sala: arquiva a rodada corrente (a da última turma),
-- zera jogadores e respostas e libera o banco. É o gesto de fim de ciclo,
-- feito DEPOIS que as três turmas jogaram. Idempotente: se a sala já foi
-- reiniciada, não há o que arquivar e só a liberação acontece.
--
-- 'despublicar' recolhe o banco sem apagar nada da série histórica.
-- ---------------------------------------------------------------------
create or replace function quiz_publicar(p_slug text, p_token text, p_acao text default 'publicar')
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ok bool; v_n int := 0; v_tag text;
begin
  select exists (select 1 from quiz_host_tokens
                  where session_slug = p_slug and token = p_token) into v_ok;
  if not v_ok then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  if not exists (select 1 from quiz_sessions where slug = p_slug) then
    return jsonb_build_object('ok', false, 'erro', 'Sessão inexistente.');
  end if;

  if p_acao = 'despublicar' then
    update quiz_sessions set publicado_em = null where slug = p_slug;
    return jsonb_build_object('ok', true, 'publicado_em', null, 'arquivadas', 0);
  end if;

  if p_acao <> 'publicar' then
    return jsonb_build_object('ok', false, 'erro', 'Ação desconhecida.');
  end if;

  v_n := quiz_arquivar(p_slug);

  delete from quiz_answers
   where player_id in (select id from quiz_players where session_slug = p_slug);
  delete from quiz_players where session_slug = p_slug;

  update quiz_sessions
     set estado = 'lobby', pergunta_atual = 0, aberta_em = null, publicado_em = now()
   where slug = p_slug;

  select coalesce(periodo, 'sem-periodo') || '-' || p_slug into v_tag
    from quiz_sessions where slug = p_slug;

  return jsonb_build_object(
    'ok', true,
    'arquivadas', v_n,
    'publicado_em', (select publicado_em from quiz_sessions where slug = p_slug),
    'rodadas', (select count(*) from quiz_relatorios r
                 where r.data_tag = v_tag
                   and (select count(distinct l->>'nome')
                          from jsonb_array_elements(r.data) l) >= quiz_banco_piso()));
end $$;

revoke all on function quiz_banco_salas()                from public;
revoke all on function quiz_banco(text)                  from public;
revoke all on function quiz_publicar(text,text,text)     from public;
grant execute on function quiz_banco_salas()             to anon, authenticated;
grant execute on function quiz_banco(text)               to anon, authenticated;
grant execute on function quiz_publicar(text,text,text)  to anon, authenticated;
