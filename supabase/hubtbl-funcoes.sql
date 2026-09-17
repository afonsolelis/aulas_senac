-- =====================================================================
-- TBL ao vivo — funções (RPCs)
-- Projeto: lwamaovuxcevsjfvtqhf (COMPARTILHADO com o projeto Einstein)
--
-- Idempotente e não destrutivo: só "create or replace" de funções com o
-- prefixo hubtbl_, que é do Hub. Nenhum drop. Não troque o prefixo por
-- tbl_: tbl_host, tbl_state, tbl_vote etc. são do Einstein e seriam
-- sobrescritos em silêncio.
--
-- Toda leitura e toda escrita passam por estas funções, e o corte de
-- informação por fase é feito aqui, não no navegador:
--   - a questão entregue ao aluno é sempre a corrente, nunca as seguintes;
--   - o dado novo de uma questão só sai depois de aberta a discussão;
--   - a distribuição da primeira decisão só circula a partir da discussão.
-- =====================================================================

-- Duração de cada fase, em segundos: nove minutos por questão.
create or replace function hubtbl_duracao(p_fase text)
returns int language sql immutable set search_path = public, pg_temp as $$
  select case p_fase
    when 'voto1'     then 180    -- 3 min de decisão individual
    when 'discussao' then 240    -- 4 min de discussão com a turma à vista
    when 'voto2'     then 120    -- 2 min para decidir outra vez
    else null                    -- lobby, sintese e revelacao sem prazo
  end;
$$;

create or replace function hubtbl_proxima_fase(p_fase text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select case p_fase
    when 'lobby'     then 'voto1'
    when 'voto1'     then 'discussao'
    when 'discussao' then 'voto2'
    when 'voto2'     then 'sintese'
    else 'sintese'
  end;
$$;

create or replace function hubtbl_total_questoes(p_slug text)
returns int language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(max(ordem), 0)::int from hubtbl_questoes where session_slug = p_slug;
$$;

-- ---------------------------------------------------------------------
-- Cadastro do participante. Devolve o uuid, que é a credencial dele.
-- p_id retoma a sessão do mesmo aparelho sem consumir outro nome.
-- ---------------------------------------------------------------------
create or replace function hubtbl_entrar(p_slug text, p_nome text, p_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_nome text; v_id uuid;
begin
  v_nome := btrim(regexp_replace(coalesce(p_nome,''), '\s+', ' ', 'g'));

  if char_length(v_nome) < 2 or char_length(v_nome) > 24 then
    return jsonb_build_object('ok', false, 'erro', 'O nome deve ter entre 2 e 24 caracteres.');
  end if;

  if not exists (select 1 from hubtbl_sessions where slug = p_slug) then
    return jsonb_build_object('ok', false, 'erro', 'Sala inexistente.');
  end if;

  if p_id is not null and exists (select 1 from hubtbl_participantes
                                   where id = p_id and session_slug = p_slug) then
    if exists (select 1 from hubtbl_participantes
                where session_slug = p_slug and lower(nome) = lower(v_nome) and id <> p_id) then
      return jsonb_build_object('ok', false, 'erro', 'Esse nome já está em uso nesta sala. Escolha outro.');
    end if;
    update hubtbl_participantes set nome = v_nome, visto_em = now() where id = p_id;
    return jsonb_build_object('ok', true, 'participante_id', p_id, 'nome', v_nome);
  end if;

  if exists (select 1 from hubtbl_participantes
              where session_slug = p_slug and lower(nome) = lower(v_nome)) then
    return jsonb_build_object('ok', false, 'erro', 'Esse nome já está em uso nesta sala. Escolha outro.');
  end if;

  insert into hubtbl_participantes (session_slug, nome) values (p_slug, v_nome)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'participante_id', v_id, 'nome', v_nome);
end $$;

-- ---------------------------------------------------------------------
-- Registro da decisão, sempre sobre a questão corrente da sala.
-- ---------------------------------------------------------------------
create or replace function hubtbl_votar(p_participante uuid, p_rodada int,
                                        p_escolha int, p_justificativa text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_slug text; v_s record; v_just text;
begin
  select session_slug into v_slug from hubtbl_participantes where id = p_participante;
  if v_slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Participante não encontrado. Entre novamente na sala.');
  end if;

  select * into v_s from hubtbl_sessions where slug = v_slug;

  if v_s.fase <> 'voto' || p_rodada::text then
    return jsonb_build_object('ok', false, 'erro', 'Esta rodada não está aberta.');
  end if;

  -- Dois segundos de tolerância para a latência entre o toque e o servidor.
  if v_s.fase_termina_em is not null and now() > v_s.fase_termina_em + interval '2 seconds' then
    return jsonb_build_object('ok', false, 'erro', 'O tempo desta rodada terminou.');
  end if;

  if p_escolha is null or p_escolha < 0 or p_escolha > 3 then
    return jsonb_build_object('ok', false, 'erro', 'Escolha inválida.');
  end if;

  v_just := btrim(regexp_replace(coalesce(p_justificativa,''), '\s+', ' ', 'g'));
  if char_length(v_just) < 10 then
    return jsonb_build_object('ok', false, 'erro', 'Registre a justificativa com pelo menos 10 caracteres.');
  end if;
  if char_length(v_just) > 240 then
    v_just := left(v_just, 240);
  end if;

  insert into hubtbl_votos (session_slug, participante_id, questao, rodada, escolha, justificativa)
  values (v_slug, p_participante, v_s.questao, p_rodada::smallint, p_escolha::smallint, v_just)
  on conflict (session_slug, participante_id, questao, rodada)
    do update set escolha = excluded.escolha,
                  justificativa = excluded.justificativa,
                  votado_em = now();

  update hubtbl_participantes set visto_em = now() where id = p_participante;

  return jsonb_build_object('ok', true, 'questao', v_s.questao, 'rodada', p_rodada, 'escolha', p_escolha);
end $$;

-- Distribuição de uma rodada: sempre as quatro alternativas.
create or replace function hubtbl_distribuicao(p_slug text, p_questao int, p_rodada int)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(x order by x.escolha), '[]'::jsonb)
  from (
    select g as escolha, count(v.escolha)::int as votos
      from generate_series(0,3) g
      left join hubtbl_votos v
        on v.session_slug = p_slug and v.questao = p_questao
       and v.rodada = p_rodada and v.escolha = g
     group by g
  ) x;
$$;

-- Justificativas de uma rodada, sem identificação do autor.
create or replace function hubtbl_justificativas(p_slug text, p_questao int, p_rodada int)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('escolha', escolha, 'texto', justificativa)
                            order by escolha, votado_em), '[]'::jsonb)
    from hubtbl_votos
   where session_slug = p_slug and questao = p_questao
     and rodada = p_rodada and justificativa <> '';
$$;

-- Trajetórias entre as duas rodadas de uma questão.
create or replace function hubtbl_trajetos(p_slug text, p_questao int)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('de', de, 'para', para, 'pessoas', pessoas)
                            order by pessoas desc), '[]'::jsonb)
  from (
    select a.escolha as de, b.escolha as para, count(*)::int as pessoas
      from hubtbl_votos a
      join hubtbl_votos b
        on b.session_slug = a.session_slug
       and b.participante_id = a.participante_id
       and b.questao = a.questao
       and b.rodada = 2
     where a.session_slug = p_slug and a.questao = p_questao and a.rodada = 1
     group by a.escolha, b.escolha
  ) t;
$$;

-- Consolidado de todas as questões. Interno: entrega todas as questões de
-- uma vez, então só sai por hubtbl_estado na revelação ou pelo painel.
create or replace function hubtbl_consolidado(p_slug text)
returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'ordem', q.ordem,
           'categoria', q.categoria,
           'titulo', q.titulo,
           'pergunta', q.pergunta,
           'alternativas', q.alternativas,
           'rodada1', hubtbl_distribuicao(p_slug, q.ordem, 1),
           'rodada2', hubtbl_distribuicao(p_slug, q.ordem, 2),
           'trajetos', hubtbl_trajetos(p_slug, q.ordem))
           order by q.ordem), '[]'::jsonb)
    from hubtbl_questoes q where q.session_slug = p_slug;
$$;

-- ---------------------------------------------------------------------
-- Estado visível ao aluno. O corte de informação por fase é feito aqui.
-- ---------------------------------------------------------------------
create or replace function hubtbl_estado(p_slug text, p_participante uuid default null)
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  v_s record; v_c record; v_q record;
  v_restante int; v_aberta bool; v_rodada int;
  v_online int; v_inscritos int;
  v_meus jsonb; v_extra jsonb := '{}'::jsonb;
begin
  select * into v_s from hubtbl_sessions where slug = p_slug;
  if v_s.slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Sala inexistente.');
  end if;

  select * into v_c from hubtbl_casos where session_slug = p_slug;
  select * into v_q from hubtbl_questoes
   where session_slug = p_slug and ordem = v_s.questao;

  -- Presença, registrada no máximo a cada cinco segundos.
  if p_participante is not null then
    update hubtbl_participantes set visto_em = now()
     where id = p_participante and session_slug = p_slug
       and visto_em < now() - interval '5 seconds';
  end if;

  select count(*) filter (where visto_em > now() - interval '25 seconds'), count(*)
    into v_online, v_inscritos
    from hubtbl_participantes where session_slug = p_slug;

  v_restante := greatest(0, ceil(extract(epoch from (v_s.fase_termina_em - now()))))::int;
  if v_s.fase_termina_em is null then v_restante := null; end if;
  v_aberta := v_s.fase in ('voto1','voto2')
              and (v_s.fase_termina_em is null or now() <= v_s.fase_termina_em);
  v_rodada := case v_s.fase when 'voto1' then 1 when 'voto2' then 2 else null end;

  select coalesce(jsonb_object_agg(rodada::text,
           jsonb_build_object('escolha', escolha, 'justificativa', justificativa)), '{}'::jsonb)
    into v_meus
    from hubtbl_votos
   where session_slug = p_slug and participante_id = p_participante
     and questao = v_s.questao;

  if v_s.fase in ('discussao','voto2','sintese','revelacao') then
    v_extra := v_extra || jsonb_build_object(
      'rodada1', hubtbl_distribuicao(p_slug, v_s.questao, 1),
      'justificativas1', hubtbl_justificativas(p_slug, v_s.questao, 1),
      'dado_novo', v_q.dado_novo);
  end if;

  if v_s.fase in ('sintese','revelacao') then
    v_extra := v_extra || jsonb_build_object(
      'rodada2', hubtbl_distribuicao(p_slug, v_s.questao, 2),
      'justificativas2', hubtbl_justificativas(p_slug, v_s.questao, 2),
      'trajetos', hubtbl_trajetos(p_slug, v_s.questao));
  end if;

  if v_s.fase = 'revelacao' then
    v_extra := v_extra || jsonb_build_object('consolidado', hubtbl_consolidado(p_slug));
  end if;

  return jsonb_build_object(
    'ok', true,
    'slug', v_s.slug,
    'titulo', v_s.titulo,
    'fase', v_s.fase,
    'questao', v_s.questao,
    'total_questoes', hubtbl_total_questoes(p_slug),
    'restante', v_restante,
    'votacao_aberta', v_aberta,
    'participantes', v_online,
    'inscritos', v_inscritos,
    'votos_rodada', (select count(*)::int from hubtbl_votos
                      where session_slug = p_slug
                        and questao = v_s.questao and rodada = v_rodada),
    'inscrito', exists (select 1 from hubtbl_participantes
                         where id = p_participante and session_slug = p_slug),
    'caso_titulo', v_c.caso_titulo,
    'caso_texto', v_c.caso_texto,
    'contexto', v_c.contexto,
    -- No lobby a turma lê apenas o caso. O enunciado e as alternativas da
    -- questão corrente só saem quando o professor abre a primeira decisão,
    -- para que um aluno que chame a RPC direto não leia a questão adiantado.
    'categoria', case when v_s.fase = 'lobby' then null else v_q.categoria end,
    'questao_titulo', case when v_s.fase = 'lobby' then null else v_q.titulo end,
    'pergunta', case when v_s.fase = 'lobby' then null else v_q.pergunta end,
    'alternativas', case when v_s.fase = 'lobby' then null else v_q.alternativas end,
    'meus_votos', v_meus
  ) || v_extra;
end $$;

-- Arquiva a rodada inteira em hubtbl_historico. Não arquiva sala vazia.
create or replace function hubtbl_arquivar(p_slug text)
returns int
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_n int;
begin
  select count(distinct participante_id)::int into v_n
    from hubtbl_votos where session_slug = p_slug;
  if coalesce(v_n, 0) = 0 then
    return 0;
  end if;

  insert into hubtbl_historico (session_slug, participantes, consolidado, decisoes)
  select p_slug, v_n, hubtbl_consolidado(p_slug),
         coalesce(jsonb_agg(jsonb_build_object(
           'nome', p.nome, 'questao', v.questao, 'rodada', v.rodada,
           'escolha', v.escolha, 'justificativa', v.justificativa, 'votado_em', v.votado_em)
           order by p.nome, v.questao, v.rodada), '[]'::jsonb)
    from hubtbl_votos v
    join hubtbl_participantes p on p.id = v.participante_id
   where v.session_slug = p_slug;

  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- Painel do professor. Uma função para ler e para agir.
--
--   ver        apenas lê o estado
--   iniciar    abre a primeira questão e apaga os votos anteriores
--   avancar    encerra a fase corrente e abre a seguinte
--   proxima    passa à questão seguinte; na última, vai à revelação
--   anterior   retorna à questão anterior, na síntese, sem apagar votos
--   estender   acrescenta 120 segundos ao prazo da fase corrente
--   revelar    vai direto ao consolidado de todas as questões
--   lobby      retorna ao lobby e apaga os votos, preservando a turma
--   reiniciar  nova turma: ARQUIVA a rodada e apaga participantes e votos
--   descartar  como reiniciar, mas sem arquivar (usado pela validação)
-- ---------------------------------------------------------------------
create or replace function hubtbl_host(p_slug text, p_token text, p_acao text default 'ver')
returns jsonb
language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare v_s record; v_nova text; v_base jsonb; v_roster jsonb; v_total int; v_arq int := null;
begin
  if not exists (select 1 from hubtbl_host_tokens
                  where session_slug = p_slug and token = p_token) then
    return jsonb_build_object('ok', false, 'erro', 'Token do professor inválido.');
  end if;

  select * into v_s from hubtbl_sessions where slug = p_slug for update;
  if v_s.slug is null then
    return jsonb_build_object('ok', false, 'erro', 'Sala inexistente.');
  end if;

  v_total := hubtbl_total_questoes(p_slug);

  if p_acao = 'iniciar' then
    delete from hubtbl_votos where session_slug = p_slug;
    update hubtbl_sessions
       set fase = 'voto1', questao = 1, aberta_em = now(),
           fase_termina_em = now() + make_interval(secs => hubtbl_duracao('voto1'))
     where slug = p_slug;

  elsif p_acao = 'avancar' then
    if v_s.fase in ('sintese','revelacao') then
      return hubtbl_host(p_slug, p_token, 'proxima');
    end if;
    v_nova := hubtbl_proxima_fase(v_s.fase);
    update hubtbl_sessions
       set fase = v_nova,
           aberta_em = coalesce(aberta_em, now()),
           fase_termina_em = case when hubtbl_duracao(v_nova) is null then null
                                  else now() + make_interval(secs => hubtbl_duracao(v_nova)) end
     where slug = p_slug;

  elsif p_acao = 'proxima' then
    if v_s.questao >= v_total then
      update hubtbl_sessions set fase = 'revelacao', fase_termina_em = null where slug = p_slug;
    else
      update hubtbl_sessions
         set questao = v_s.questao + 1, fase = 'voto1',
             aberta_em = coalesce(aberta_em, now()),
             fase_termina_em = now() + make_interval(secs => hubtbl_duracao('voto1'))
       where slug = p_slug;
    end if;

  elsif p_acao = 'anterior' then
    if v_s.questao <= 1 then
      return jsonb_build_object('ok', false, 'erro', 'Esta é a primeira questão.');
    end if;
    update hubtbl_sessions
       set questao = v_s.questao - 1, fase = 'sintese', fase_termina_em = null
     where slug = p_slug;

  elsif p_acao = 'estender' then
    if v_s.fase not in ('voto1','discussao','voto2') then
      return jsonb_build_object('ok', false, 'erro', 'Não há prazo a estender nesta fase.');
    end if;
    update hubtbl_sessions
       set fase_termina_em = greatest(coalesce(fase_termina_em, now()), now())
                             + interval '120 seconds'
     where slug = p_slug;

  elsif p_acao = 'revelar' then
    update hubtbl_sessions set fase = 'revelacao', fase_termina_em = null where slug = p_slug;

  elsif p_acao = 'lobby' then
    delete from hubtbl_votos where session_slug = p_slug;
    update hubtbl_sessions set fase = 'lobby', questao = 1, aberta_em = null, fase_termina_em = null
     where slug = p_slug;

  elsif p_acao in ('reiniciar','descartar') then
    if p_acao = 'reiniciar' then
      v_arq := hubtbl_arquivar(p_slug);
    end if;
    delete from hubtbl_participantes where session_slug = p_slug;
    update hubtbl_sessions set fase = 'lobby', questao = 1, aberta_em = null, fase_termina_em = null
     where slug = p_slug;

  elsif p_acao <> 'ver' then
    return jsonb_build_object('ok', false, 'erro', 'Ação inválida.');
  end if;

  -- O professor enxerga as duas rodadas da questão corrente e o
  -- consolidado em qualquer fase, para conduzir a discussão.
  select * into v_s from hubtbl_sessions where slug = p_slug;
  v_base := hubtbl_estado(p_slug, null);

  select coalesce(jsonb_agg(jsonb_build_object(
           'nome', p.nome,
           'online', p.visto_em > now() - interval '25 seconds',
           'r1', (select escolha from hubtbl_votos
                   where participante_id = p.id and questao = v_s.questao and rodada = 1),
           'r2', (select escolha from hubtbl_votos
                   where participante_id = p.id and questao = v_s.questao and rodada = 2))
           order by p.nome), '[]'::jsonb)
    into v_roster
    from hubtbl_participantes p where p.session_slug = p_slug;

  return v_base || jsonb_build_object(
    'host', true,
    'arquivados', v_arq,
    'rodadas_arquivadas', (select count(*)::int from hubtbl_historico where session_slug = p_slug),
    'turma', v_roster,
    'dado_novo', (select dado_novo from hubtbl_questoes
                   where session_slug = p_slug and ordem = v_s.questao),
    'rodada1', hubtbl_distribuicao(p_slug, v_s.questao, 1),
    'rodada2', hubtbl_distribuicao(p_slug, v_s.questao, 2),
    'justificativas1', hubtbl_justificativas(p_slug, v_s.questao, 1),
    'justificativas2', hubtbl_justificativas(p_slug, v_s.questao, 2),
    'trajetos', hubtbl_trajetos(p_slug, v_s.questao),
    'consolidado', hubtbl_consolidado(p_slug),
    'votos1', (select count(*)::int from hubtbl_votos
                where session_slug = p_slug and questao = v_s.questao and rodada = 1),
    'votos2', (select count(*)::int from hubtbl_votos
                where session_slug = p_slug and questao = v_s.questao and rodada = 2));
end $$;

-- ---------------------------------------------------------------------
-- Permissões. No Supabase, função nova no schema public nasce executável
-- por anon e authenticated (default privileges), não só por public. Por
-- isso as internas são revogadas dos três: hubtbl_consolidado, por
-- exemplo, entregaria todas as questões antes da hora.
-- ---------------------------------------------------------------------
revoke all on function hubtbl_duracao(text)                    from public, anon, authenticated;
revoke all on function hubtbl_proxima_fase(text)               from public, anon, authenticated;
revoke all on function hubtbl_total_questoes(text)             from public, anon, authenticated;
revoke all on function hubtbl_distribuicao(text,int,int)       from public, anon, authenticated;
revoke all on function hubtbl_justificativas(text,int,int)     from public, anon, authenticated;
revoke all on function hubtbl_trajetos(text,int)               from public, anon, authenticated;
revoke all on function hubtbl_consolidado(text)                from public, anon, authenticated;
revoke all on function hubtbl_arquivar(text)                   from public, anon, authenticated;
revoke all on function hubtbl_entrar(text,text,uuid)           from public, anon, authenticated;
revoke all on function hubtbl_votar(uuid,int,int,text)         from public, anon, authenticated;
revoke all on function hubtbl_estado(text,uuid)                from public, anon, authenticated;
revoke all on function hubtbl_host(text,text,text)             from public, anon, authenticated;

grant execute on function hubtbl_entrar(text,text,uuid)   to anon, authenticated;
grant execute on function hubtbl_votar(uuid,int,int,text) to anon, authenticated;
grant execute on function hubtbl_estado(text,uuid)        to anon, authenticated;
grant execute on function hubtbl_host(text,text,text)     to anon, authenticated;
