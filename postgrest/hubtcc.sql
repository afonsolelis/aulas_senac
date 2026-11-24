-- Acompanhamento do TCC por edição (estreia: TCC1 2027.1, edição 'tcc1-2027-1').
-- Postgres do aulas_senac na VPS.
--
-- Fluxo
--   1. A coordenação cadastra os professores que podem orientar. Cada professor
--      recebe um token único que vale para tudo o que é dele na edição:
--      orientandos e bancas.
--   2. Na entrega de acompanhamento (fim do 1º mês), o aluno (individual, dupla
--      ou trio) informa título e integrantes, escolhe o orientador numa lista e
--      sobe o PDF da primeira versão. O comprovante mostra o token do trabalho,
--      que abre o painel do aluno.
--   3. A coordenação confirma ou troca o orientador indicado.
--   4. O orientador registra considerações com avaliação (grave, esperado,
--      supera), que ficam em histórico e aparecem para o aluno, e libera ou não
--      o trabalho para a banca.
--   5. A coordenação aloca a banca; os professores escrevem as considerações e a
--      coordenação as libera para o aluno.
--
-- Tokens: <codigo>-<segredo>. O código (8 hex) localiza a linha; o segredo
-- (122 bits) é conferido por sha256(sal || token). O banco guarda só o hash.
-- A coordenação usa o mesmo token do TCC2 (hubbanca_coord_ok, hubdeposito_acesso).
--
-- PDFs ficam em hubtcc_arquivos, separados de hubdeposito_arquivos: a limpeza
-- do TCC2 apaga o que não está em hubdeposito_respostas.
--
-- Objetos NOVOS: prefixo hubtcc_. Depende de hubbanca_coord_ok (postgrest/hubbanca.sql).
-- Idempotente. Aplicar com psql -U postgres -d aulas -v ON_ERROR_STOP=1 -f.

begin;

-- ---------------------------------------------------------------- tabelas

create table if not exists public.hubtcc_edicoes (
  slug             text primary key,
  titulo           text not null,
  max_integrantes  int  not null default 3,
  entrega_aberta   boolean not null default false,
  prazo_entrega    timestamptz,
  final_aberta     boolean not null default false,
  criado_em        timestamptz not null default now()
);

create table if not exists public.hubtcc_professores (
  id          uuid primary key default gen_random_uuid(),
  edicao      text not null references public.hubtcc_edicoes(slug),
  nome        text not null check (length(nome) between 2 and 120),
  orienta     boolean not null default true,
  codigo      text not null unique,
  sal         text not null,
  hash        text not null,
  acesso_em   timestamptz,
  criado_em   timestamptz not null default now(),
  removido_em timestamptz
);

create table if not exists public.hubtcc_trabalhos (
  id                   uuid primary key default gen_random_uuid(),
  edicao               text not null references public.hubtcc_edicoes(slug),
  titulo               text not null,
  integrantes          text not null,
  orientador_indicado  uuid references public.hubtcc_professores(id),
  orientador_id        uuid references public.hubtcc_professores(id),
  codigo               text not null unique,
  sal                  text not null,
  hash                 text not null,
  liberado_banca       boolean,
  liberacao_texto      text,
  liberacao_em         timestamptz,
  banca_liberada_em    timestamptz,
  acesso_em            timestamptz,
  criado_em            timestamptz not null default now(),
  removido_em          timestamptz
);

create table if not exists public.hubtcc_arquivos (
  caminho    text primary key,
  conteudo   bytea not null,
  tamanho    bigint not null,
  enviado_em timestamptz not null default now()
);
alter table public.hubtcc_arquivos alter column conteudo set storage external;

create table if not exists public.hubtcc_partes (
  caminho    text not null,
  parte      int  not null,
  conteudo   bytea not null,
  enviado_em timestamptz not null default now(),
  primary key (caminho, parte)
);
alter table public.hubtcc_partes alter column conteudo set storage external;

create table if not exists public.hubtcc_versoes (
  id           uuid primary key default gen_random_uuid(),
  trabalho_id  uuid not null references public.hubtcc_trabalhos(id),
  tipo         text not null check (tipo in ('primeira', 'nova', 'final')),
  arquivo      text not null unique references public.hubtcc_arquivos(caminho),
  nome_arquivo text,
  tamanho      bigint,
  enviado_em   timestamptz not null default now()
);

create table if not exists public.hubtcc_registros (
  id            uuid primary key default gen_random_uuid(),
  trabalho_id   uuid not null references public.hubtcc_trabalhos(id),
  professor_id  uuid not null references public.hubtcc_professores(id),
  avaliacao     text check (avaliacao in ('grave', 'esperado', 'supera')),
  texto         text check (length(texto) <= 20000),
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz,
  removido_em   timestamptz
);

create table if not exists public.hubtcc_bancas (
  id            uuid primary key default gen_random_uuid(),
  trabalho_id   uuid not null references public.hubtcc_trabalhos(id),
  professor_id  uuid not null references public.hubtcc_professores(id),
  consideracoes text check (length(consideracoes) <= 20000),
  atualizado_em timestamptz,
  criado_em     timestamptz not null default now(),
  removido_em   timestamptz
);
create unique index if not exists hubtcc_bancas_unica
  on public.hubtcc_bancas (trabalho_id, professor_id) where removido_em is null;

do $$
declare t text;
begin
  foreach t in array array['hubtcc_edicoes','hubtcc_professores','hubtcc_trabalhos','hubtcc_arquivos',
                           'hubtcc_partes','hubtcc_versoes','hubtcc_registros','hubtcc_bancas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

insert into public.hubtcc_edicoes (slug, titulo, max_integrantes)
values ('tcc1-2027-1', 'TCC1 · 2027.1', 3)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------- internas

-- Gera <codigo>-<segredo>, com sal e hash.
create or replace function public.hubtcc_token_novo(out codigo text, out sal text, out hash text, out token text)
language plpgsql
volatile
set search_path = public
as $$
begin
  codigo := left(replace(gen_random_uuid()::text, '-', ''), 8);
  token  := codigo || '-' || replace(gen_random_uuid()::text, '-', '');
  sal    := md5(gen_random_uuid()::text);
  hash   := encode(sha256(convert_to(sal || token, 'UTF8')), 'hex');
end $$;

create or replace function public.hubtcc_prof_do_token(p_token text)
returns hubtcc_professores
language sql
security definer
set search_path = public
as $$
  select p.* from hubtcc_professores p
   where p.codigo = split_part(trim(coalesce(p_token, '')), '-', 1)
     and p.removido_em is null
     and p.hash = encode(sha256(convert_to(p.sal || trim(p_token), 'UTF8')), 'hex');
$$;

create or replace function public.hubtcc_trab_do_token(p_token text)
returns hubtcc_trabalhos
language sql
security definer
set search_path = public
as $$
  select t.* from hubtcc_trabalhos t
   where t.codigo = split_part(trim(coalesce(p_token, '')), '-', 1)
     and t.removido_em is null
     and t.hash = encode(sha256(convert_to(t.sal || trim(p_token), 'UTF8')), 'hex');
$$;

-- Versões de um trabalho, da mais recente para a mais antiga.
create or replace function public.hubtcc_json_versoes(p_trabalho uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'tipo', v.tipo, 'arquivo', v.arquivo, 'nome_arquivo', v.nome_arquivo,
    'tamanho', v.tamanho, 'enviado_em', v.enviado_em) order by v.enviado_em desc), '[]'::jsonb)
  from hubtcc_versoes v where v.trabalho_id = p_trabalho;
$$;

-- Histórico do orientador, do mais recente para o mais antigo.
create or replace function public.hubtcc_json_registros(p_trabalho uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id, 'professor', p.nome, 'avaliacao', r.avaliacao, 'texto', r.texto,
    'criado_em', r.criado_em, 'atualizado_em', r.atualizado_em) order by r.criado_em desc), '[]'::jsonb)
  from hubtcc_registros r join hubtcc_professores p on p.id = r.professor_id
  where r.trabalho_id = p_trabalho and r.removido_em is null;
$$;

-- Banca do trabalho (professores e considerações).
create or replace function public.hubtcc_json_banca(p_trabalho uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'professor_id', p.id, 'professor', p.nome, 'consideracoes', b.consideracoes,
    'atualizado_em', b.atualizado_em) order by b.criado_em), '[]'::jsonb)
  from hubtcc_bancas b join hubtcc_professores p on p.id = b.professor_id
  where b.trabalho_id = p_trabalho and b.removido_em is null;
$$;

-- Última avaliação dada pelo orientador.
create or replace function public.hubtcc_avaliacao_atual(p_trabalho uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select r.avaliacao from hubtcc_registros r
   where r.trabalho_id = p_trabalho and r.removido_em is null and r.avaliacao is not null
   order by r.criado_em desc limit 1;
$$;

-- ---------------------------------------------------------------- arquivos

create or replace function public.hubtcc_subir_parte(p_caminho text, p_parte int, p_total int, p_conteudo text, p_token text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ed   text := split_part(coalesce(p_caminho, ''), '/', 1);
  e      hubtcc_edicoes;
  t      hubtcc_trabalhos;
  v_bin  bytea;
  v_qtd  int;
  v_tam  bigint;
begin
  if coalesce(p_caminho, '') !~ '^[a-z0-9-]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$' then
    raise exception 'Arquivo inválido. Envie o PDF de novo.';
  end if;
  if p_total is null or p_total not between 1 and 20 or p_parte is null or p_parte not between 1 and p_total then
    raise exception 'Arquivo inválido. Envie o PDF de novo.';
  end if;
  select * into e from hubtcc_edicoes where slug = v_ed;
  if not found then
    raise exception 'Edição não encontrada.';
  end if;
  -- Sem token, só com a entrega aberta. Com token, o aluno manda nova versão.
  if p_token is not null then
    t := hubtcc_trab_do_token(p_token);
    if t.id is null or t.edicao <> v_ed then
      raise exception 'Token inválido.';
    end if;
  elsif not e.entrega_aberta or now() > coalesce(e.prazo_entrega, 'infinity') then
    raise exception 'A entrega está fechada.';
  end if;
  if exists (select 1 from hubtcc_arquivos where caminho = p_caminho) then
    raise exception 'Este arquivo já foi enviado.';
  end if;

  begin
    v_bin := decode(p_conteudo, 'base64');
  exception when others then
    raise exception 'O PDF chegou corrompido. Envie de novo.';
  end;
  if v_bin is null or length(v_bin) = 0 then
    raise exception 'O PDF chegou vazio. Envie de novo.';
  end if;
  if length(v_bin) > 8 * 1024 * 1024 then
    raise exception 'Arquivo inválido. Recarregue a página e envie de novo.';
  end if;
  if p_parte = 1 and substring(v_bin from 1 for 4) <> '\x25504446'::bytea then  -- %PDF
    raise exception 'O arquivo não é um PDF.';
  end if;

  -- Partes e arquivos que nunca viraram versão somem depois de um dia.
  delete from hubtcc_partes where enviado_em < now() - interval '1 day';
  delete from hubtcc_arquivos a
   where a.enviado_em < now() - interval '1 day'
     and not exists (select 1 from hubtcc_versoes v where v.arquivo = a.caminho);

  if p_parte = 1 and (select count(distinct caminho) from hubtcc_partes
       where split_part(caminho, '/', 1) = v_ed and parte = 1
         and enviado_em > now() - interval '10 minutes') >= 30 then
    raise exception 'Muitos envios em poucos minutos. Aguarde e tente de novo.';
  end if;

  insert into hubtcc_partes (caminho, parte, conteudo) values (p_caminho, p_parte, v_bin)
  on conflict (caminho, parte) do update set conteudo = excluded.conteudo, enviado_em = now();

  select count(*), coalesce(sum(length(conteudo)), 0) into v_qtd, v_tam
    from hubtcc_partes where caminho = p_caminho and parte between 1 and p_total;
  if v_tam > 100 * 1024 * 1024 then
    delete from hubtcc_partes where caminho = p_caminho;
    raise exception 'O PDF passa de 100 MB. Comprima o arquivo e tente de novo.';
  end if;
  if v_qtd < p_total then
    return jsonb_build_object('caminho', p_caminho, 'completo', false, 'recebidas', v_qtd);
  end if;

  insert into hubtcc_arquivos (caminho, conteudo, tamanho)
  select p_caminho, string_agg(conteudo, ''::bytea order by parte), v_tam
    from hubtcc_partes where caminho = p_caminho and parte between 1 and p_total;
  delete from hubtcc_partes where caminho = p_caminho;
  return jsonb_build_object('caminho', p_caminho, 'completo', true, 'tamanho', v_tam);
end $$;

-- GET /rpc/hubtcc_pdf?p_caminho=... devolve o PDF (nome sorteado, sem listagem).
create or replace function public.hubtcc_pdf(p_caminho text)
returns "*/*"
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_bin  bytea;
  v_nome text;
begin
  select a.conteudo into v_bin from hubtcc_arquivos a where a.caminho = p_caminho;
  if v_bin is null then
    perform set_config('response.status', '404', true);
    return null;
  end if;
  select nome_arquivo into v_nome from hubtcc_versoes where arquivo = p_caminho;
  v_nome := regexp_replace(coalesce(v_nome, split_part(p_caminho, '/', 2)), '[^A-Za-z0-9._ -]', '_', 'g');
  perform set_config('response.headers', json_build_array(
    json_build_object('Content-Type', 'application/pdf'),
    json_build_object('Content-Disposition', 'inline; filename="' || v_nome || '"'),
    json_build_object('Cache-Control', 'private, max-age=300'))::text, true);
  return v_bin;
end $$;

-- ---------------------------------------------------------------- aluno

-- Dados públicos da edição para o formulário de entrega.
create or replace function public.hubtcc_edicao(p_edicao text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'slug', e.slug, 'titulo', e.titulo, 'max_integrantes', e.max_integrantes,
    'entrega_aberta', e.entrega_aberta and now() <= coalesce(e.prazo_entrega, 'infinity'),
    'prazo_entrega', e.prazo_entrega, 'final_aberta', e.final_aberta,
    'orientadores', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome) order by p.nome)
                                from hubtcc_professores p
                               where p.edicao = e.slug and p.orienta and p.removido_em is null), '[]'::jsonb))
  from hubtcc_edicoes e where e.slug = p_edicao;
$$;

-- Entrega de acompanhamento: cria o trabalho e devolve o token do aluno.
create or replace function public.hubtcc_inscrever(p_edicao text, p_titulo text, p_integrantes text[],
                                                   p_orientador uuid, p_arquivo text, p_nome_arquivo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  e      hubtcc_edicoes;
  v_nome text[];
  v_tit  text := regexp_replace(trim(coalesce(p_titulo, '')), '\s+', ' ', 'g');
  v_tam  bigint;
  k      record;
  v_id   uuid;
  v_em   timestamptz;
begin
  select * into e from hubtcc_edicoes where slug = p_edicao;
  if not found then
    raise exception 'Edição não encontrada.';
  end if;
  if not e.entrega_aberta or now() > coalesce(e.prazo_entrega, 'infinity') then
    raise exception 'A entrega está fechada.';
  end if;
  select coalesce(array_agg(n order by ord), '{}') into v_nome
    from (select regexp_replace(trim(x), '\s+', ' ', 'g') as n, ord
            from unnest(coalesce(p_integrantes, '{}')) with ordinality as t(x, ord)) s
   where n <> '';
  if cardinality(v_nome) = 0 then
    raise exception 'Informe o nome de pelo menos um integrante.';
  end if;
  if cardinality(v_nome) > e.max_integrantes then
    raise exception 'O trabalho tem no máximo % integrantes.', e.max_integrantes;
  end if;
  if exists (select 1 from unnest(v_nome) n where length(n) not between 3 and 120) then
    raise exception 'Cada nome precisa ter entre 3 e 120 caracteres.';
  end if;
  if length(v_tit) not between 5 and 300 then
    raise exception 'O título precisa ter entre 5 e 300 caracteres.';
  end if;
  if not exists (select 1 from hubtcc_professores
                  where id = p_orientador and edicao = p_edicao and orienta and removido_em is null) then
    raise exception 'Escolha o orientador na lista.';
  end if;
  if split_part(coalesce(p_arquivo, ''), '/', 1) <> p_edicao then
    raise exception 'Arquivo inválido. Envie o PDF de novo.';
  end if;
  select a.tamanho into v_tam from hubtcc_arquivos a where a.caminho = p_arquivo;
  if not found then
    raise exception 'O PDF não chegou ao servidor. Envie de novo.';
  end if;
  if exists (select 1 from hubtcc_versoes where arquivo = p_arquivo) then
    raise exception 'Este arquivo já foi registrado.';
  end if;
  if (select count(*) from hubtcc_trabalhos where edicao = p_edicao
       and criado_em > now() - interval '10 minutes') >= 30 then
    raise exception 'Muitos envios em poucos minutos. Aguarde e tente de novo.';
  end if;

  select * into k from hubtcc_token_novo();
  insert into hubtcc_trabalhos (edicao, titulo, integrantes, orientador_indicado, codigo, sal, hash)
  values (p_edicao, v_tit, array_to_string(v_nome, E'\n'), p_orientador, k.codigo, k.sal, k.hash)
  returning id, criado_em into v_id, v_em;
  insert into hubtcc_versoes (trabalho_id, tipo, arquivo, nome_arquivo, tamanho)
  values (v_id, 'primeira', p_arquivo, left(p_nome_arquivo, 200), v_tam);

  return jsonb_build_object('id', v_id, 'token', k.token, 'titulo', v_tit,
    'integrantes', v_nome, 'enviado_em', v_em, 'arquivo', p_arquivo,
    'orientador', (select nome from hubtcc_professores where id = p_orientador));
end $$;

-- Painel do aluno.
create or replace function public.hubtcc_aluno(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t hubtcc_trabalhos := hubtcc_trab_do_token(p_token);
  e hubtcc_edicoes;
begin
  if t.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  update hubtcc_trabalhos set acesso_em = now() where id = t.id;
  select * into e from hubtcc_edicoes where slug = t.edicao;
  return jsonb_build_object('ok', true,
    'edicao', e.titulo, 'final_aberta', e.final_aberta,
    'titulo', t.titulo, 'integrantes', t.integrantes, 'criado_em', t.criado_em,
    'orientador_indicado', (select nome from hubtcc_professores where id = t.orientador_indicado),
    'orientador', (select nome from hubtcc_professores where id = t.orientador_id),
    'avaliacao', hubtcc_avaliacao_atual(t.id),
    'liberado_banca', t.liberado_banca, 'liberacao_texto', t.liberacao_texto, 'liberacao_em', t.liberacao_em,
    'versoes', hubtcc_json_versoes(t.id),
    'registros', hubtcc_json_registros(t.id),
    'banca', case when t.banca_liberada_em is not null then
      (select coalesce(jsonb_agg(jsonb_build_object('professor', x->>'professor', 'consideracoes', x->>'consideracoes')), '[]'::jsonb)
         from jsonb_array_elements(hubtcc_json_banca(t.id)) x where x->>'consideracoes' is not null)
      end);
end $$;

-- Aluno registra nova versão do PDF (a final, quando a coordenação abre).
create or replace function public.hubtcc_aluno_versao(p_token text, p_arquivo text, p_nome_arquivo text, p_final boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  t     hubtcc_trabalhos := hubtcc_trab_do_token(p_token);
  v_tam bigint;
begin
  if t.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if p_final and not (select final_aberta from hubtcc_edicoes where slug = t.edicao) then
    return jsonb_build_object('ok', false, 'erro', 'O envio da versão final ainda não está aberto.');
  end if;
  if split_part(coalesce(p_arquivo, ''), '/', 1) <> t.edicao then
    return jsonb_build_object('ok', false, 'erro', 'Arquivo inválido. Envie o PDF de novo.');
  end if;
  select a.tamanho into v_tam from hubtcc_arquivos a where a.caminho = p_arquivo;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'O PDF não chegou ao servidor. Envie de novo.');
  end if;
  if exists (select 1 from hubtcc_versoes where arquivo = p_arquivo) then
    return jsonb_build_object('ok', false, 'erro', 'Este arquivo já foi registrado.');
  end if;
  insert into hubtcc_versoes (trabalho_id, tipo, arquivo, nome_arquivo, tamanho)
  values (t.id, case when p_final then 'final' else 'nova' end, p_arquivo, left(p_nome_arquivo, 200), v_tam);
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------- professor

-- Página do professor: orientandos e bancas.
create or replace function public.hubtcc_professor(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p hubtcc_professores := hubtcc_prof_do_token(p_token);
begin
  if p.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  update hubtcc_professores set acesso_em = now() where id = p.id;
  return jsonb_build_object('ok', true, 'nome', p.nome,
    'edicao', (select titulo from hubtcc_edicoes where slug = p.edicao),
    'orientandos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'titulo', t.titulo, 'integrantes', t.integrantes,
        'avaliacao', hubtcc_avaliacao_atual(t.id),
        'liberado_banca', t.liberado_banca, 'liberacao_texto', t.liberacao_texto, 'liberacao_em', t.liberacao_em,
        'versoes', hubtcc_json_versoes(t.id), 'registros', hubtcc_json_registros(t.id)) order by t.titulo)
      from hubtcc_trabalhos t where t.orientador_id = p.id and t.removido_em is null), '[]'::jsonb),
    'bancas', coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'titulo', t.titulo, 'integrantes', t.integrantes,
        'orientador', (select nome from hubtcc_professores where id = t.orientador_id),
        'liberado_banca', t.liberado_banca,
        'versoes', hubtcc_json_versoes(t.id),
        'consideracoes', b.consideracoes, 'atualizado_em', b.atualizado_em) order by t.titulo)
      from hubtcc_bancas b join hubtcc_trabalhos t on t.id = b.trabalho_id
      where b.professor_id = p.id and b.removido_em is null and t.removido_em is null), '[]'::jsonb));
end $$;

-- Orientador registra consideração e/ou avaliação.
create or replace function public.hubtcc_registrar(p_token text, p_trabalho uuid, p_avaliacao text, p_texto text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p hubtcc_professores := hubtcc_prof_do_token(p_token);
  v_txt text := nullif(trim(coalesce(p_texto, '')), '');
  v_av  text := nullif(p_avaliacao, '');
begin
  if p.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if not exists (select 1 from hubtcc_trabalhos where id = p_trabalho and orientador_id = p.id and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Este trabalho não é seu orientando.');
  end if;
  if v_av is not null and v_av not in ('grave', 'esperado', 'supera') then
    return jsonb_build_object('ok', false, 'erro', 'Avaliação inválida.');
  end if;
  if v_txt is null and v_av is null then
    return jsonb_build_object('ok', false, 'erro', 'Escreva a consideração ou escolha a avaliação.');
  end if;
  if length(v_txt) > 20000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto passou de 20 mil caracteres.');
  end if;
  insert into hubtcc_registros (trabalho_id, professor_id, avaliacao, texto) values (p_trabalho, p.id, v_av, v_txt);
  return jsonb_build_object('ok', true);
end $$;

-- Orientador edita ou apaga um registro dele.
create or replace function public.hubtcc_registro_alterar(p_token text, p_registro uuid, p_avaliacao text, p_texto text, p_remover boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p hubtcc_professores := hubtcc_prof_do_token(p_token);
  v_txt text := nullif(trim(coalesce(p_texto, '')), '');
  v_av  text := nullif(p_avaliacao, '');
begin
  if p.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if not exists (select 1 from hubtcc_registros where id = p_registro and professor_id = p.id and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Registro não encontrado.');
  end if;
  if p_remover then
    update hubtcc_registros set removido_em = now() where id = p_registro;
    return jsonb_build_object('ok', true);
  end if;
  if v_av is not null and v_av not in ('grave', 'esperado', 'supera') then
    return jsonb_build_object('ok', false, 'erro', 'Avaliação inválida.');
  end if;
  if v_txt is null and v_av is null then
    return jsonb_build_object('ok', false, 'erro', 'Escreva a consideração ou escolha a avaliação.');
  end if;
  if length(v_txt) > 20000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto passou de 20 mil caracteres.');
  end if;
  update hubtcc_registros set avaliacao = v_av, texto = v_txt, atualizado_em = now() where id = p_registro;
  return jsonb_build_object('ok', true);
end $$;

-- Orientador libera (true), não libera (false) ou volta a pendente (null).
create or replace function public.hubtcc_liberar(p_token text, p_trabalho uuid, p_liberado boolean, p_texto text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p hubtcc_professores := hubtcc_prof_do_token(p_token);
  v_txt text := nullif(trim(coalesce(p_texto, '')), '');
begin
  if p.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if not exists (select 1 from hubtcc_trabalhos where id = p_trabalho and orientador_id = p.id and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Este trabalho não é seu orientando.');
  end if;
  if p_liberado = false and v_txt is null then
    return jsonb_build_object('ok', false, 'erro', 'Explique ao aluno por que o trabalho não foi liberado.');
  end if;
  if length(v_txt) > 5000 then
    return jsonb_build_object('ok', false, 'erro', 'A justificativa passou de 5 mil caracteres.');
  end if;
  update hubtcc_trabalhos
     set liberado_banca = p_liberado, liberacao_texto = v_txt,
         liberacao_em = case when p_liberado is null then null else now() end
   where id = p_trabalho;
  return jsonb_build_object('ok', true);
end $$;

-- Professor da banca grava as considerações (editáveis sempre).
create or replace function public.hubtcc_banca_salvar(p_token text, p_trabalho uuid, p_texto text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p hubtcc_professores := hubtcc_prof_do_token(p_token);
  v_em timestamptz := now();
begin
  if p.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if length(coalesce(p_texto, '')) > 20000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto passou de 20 mil caracteres.');
  end if;
  update hubtcc_bancas set consideracoes = nullif(trim(p_texto), ''), atualizado_em = v_em
   where trabalho_id = p_trabalho and professor_id = p.id and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Você não está na banca deste trabalho.');
  end if;
  return jsonb_build_object('ok', true, 'atualizado_em', v_em);
end $$;

-- ---------------------------------------------------------------- coordenação

create or replace function public.hubtcc_coord(p_token text, p_edicao text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  e hubtcc_edicoes;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  select * into e from hubtcc_edicoes where slug = p_edicao;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Edição não encontrada.');
  end if;
  return jsonb_build_object('ok', true,
    'edicao', jsonb_build_object('slug', e.slug, 'titulo', e.titulo, 'max_integrantes', e.max_integrantes,
      'entrega_aberta', e.entrega_aberta, 'prazo_entrega', e.prazo_entrega, 'final_aberta', e.final_aberta),
    'professores', coalesce((select jsonb_agg(jsonb_build_object(
        'id', p.id, 'nome', p.nome, 'orienta', p.orienta, 'acesso_em', p.acesso_em,
        'orientandos', (select count(*) from hubtcc_trabalhos t where t.orientador_id = p.id and t.removido_em is null),
        'bancas', (select count(*) from hubtcc_bancas b join hubtcc_trabalhos t on t.id = b.trabalho_id
                    where b.professor_id = p.id and b.removido_em is null and t.removido_em is null)) order by p.nome)
      from hubtcc_professores p where p.edicao = e.slug and p.removido_em is null), '[]'::jsonb),
    'trabalhos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', t.id, 'titulo', t.titulo, 'integrantes', t.integrantes, 'criado_em', t.criado_em,
        'acesso_em', t.acesso_em,
        'orientador_indicado', t.orientador_indicado, 'orientador_id', t.orientador_id,
        'avaliacao', hubtcc_avaliacao_atual(t.id),
        'liberado_banca', t.liberado_banca, 'liberacao_texto', t.liberacao_texto, 'liberacao_em', t.liberacao_em,
        'banca_liberada_em', t.banca_liberada_em,
        'versoes', hubtcc_json_versoes(t.id), 'registros', hubtcc_json_registros(t.id),
        'banca', hubtcc_json_banca(t.id)) order by t.criado_em)
      from hubtcc_trabalhos t where t.edicao = e.slug and t.removido_em is null), '[]'::jsonb));
end $$;

create or replace function public.hubtcc_coord_edicao(p_token text, p_edicao text, p_entrega_aberta boolean,
                                                      p_prazo_entrega timestamptz, p_final_aberta boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  update hubtcc_edicoes
     set entrega_aberta = coalesce(p_entrega_aberta, entrega_aberta),
         prazo_entrega = p_prazo_entrega,
         final_aberta = coalesce(p_final_aberta, final_aberta)
   where slug = p_edicao;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Edição não encontrada.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Cadastra (p_id nulo, devolve o token) ou edita um professor.
create or replace function public.hubtcc_coord_professor(p_token text, p_edicao text, p_id uuid, p_nome text, p_orienta boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  v_nome text := regexp_replace(trim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  k record;
  v_id uuid;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  if length(v_nome) not between 2 and 120 then
    return jsonb_build_object('ok', false, 'erro', 'Informe o nome do professor.');
  end if;
  if p_id is null then
    if not exists (select 1 from hubtcc_edicoes where slug = p_edicao) then
      return jsonb_build_object('ok', false, 'erro', 'Edição não encontrada.');
    end if;
    if exists (select 1 from hubtcc_professores where edicao = p_edicao and lower(nome) = lower(v_nome) and removido_em is null) then
      return jsonb_build_object('ok', false, 'erro', 'Já existe um professor com esse nome.');
    end if;
    select * into k from hubtcc_token_novo();
    insert into hubtcc_professores (edicao, nome, orienta, codigo, sal, hash)
    values (p_edicao, v_nome, coalesce(p_orienta, true), k.codigo, k.sal, k.hash)
    returning id into v_id;
    return jsonb_build_object('ok', true, 'id', v_id, 'token', k.token);
  end if;
  update hubtcc_professores set nome = v_nome, orienta = coalesce(p_orienta, orienta)
   where id = p_id and edicao = p_edicao and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Professor não encontrado.');
  end if;
  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

-- Novo token para professor ('professor') ou trabalho ('aluno'); o anterior deixa de valer.
create or replace function public.hubtcc_coord_token(p_token text, p_tipo text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  k record;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  select * into k from hubtcc_token_novo();
  if p_tipo = 'professor' then
    update hubtcc_professores set codigo = k.codigo, sal = k.sal, hash = k.hash where id = p_id and removido_em is null;
  elsif p_tipo = 'aluno' then
    update hubtcc_trabalhos set codigo = k.codigo, sal = k.sal, hash = k.hash where id = p_id and removido_em is null;
  else
    return jsonb_build_object('ok', false, 'erro', 'Tipo inválido.');
  end if;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Não encontrado.');
  end if;
  return jsonb_build_object('ok', true, 'token', k.token);
end $$;

-- Remove professor ('professor') ou trabalho ('trabalho'). Remoção lógica.
create or replace function public.hubtcc_coord_remover(p_token text, p_tipo text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  if p_tipo = 'professor' then
    if exists (select 1 from hubtcc_trabalhos where orientador_id = p_id and removido_em is null) then
      return jsonb_build_object('ok', false, 'erro', 'Este professor ainda orienta trabalhos. Troque o orientador antes.');
    end if;
    update hubtcc_professores set removido_em = now() where id = p_id and removido_em is null;
    if not found then
      return jsonb_build_object('ok', false, 'erro', 'Não encontrado.');
    end if;
    update hubtcc_bancas set removido_em = now() where professor_id = p_id and removido_em is null;
    return jsonb_build_object('ok', true);
  elsif p_tipo = 'trabalho' then
    update hubtcc_trabalhos set removido_em = now() where id = p_id and removido_em is null;
  else
    return jsonb_build_object('ok', false, 'erro', 'Tipo inválido.');
  end if;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Não encontrado.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Define o orientador do trabalho (nulo tira).
create or replace function public.hubtcc_coord_orientador(p_token text, p_trabalho uuid, p_professor uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  t hubtcc_trabalhos;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  select * into t from hubtcc_trabalhos where id = p_trabalho and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  if p_professor is not null and not exists (select 1 from hubtcc_professores
       where id = p_professor and edicao = t.edicao and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Professor não encontrado.');
  end if;
  update hubtcc_trabalhos set orientador_id = p_professor where id = p_trabalho;
  return jsonb_build_object('ok', true);
end $$;

-- Põe (p_remover falso) ou tira um professor da banca.
create or replace function public.hubtcc_coord_banca(p_token text, p_trabalho uuid, p_professor uuid, p_remover boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  t hubtcc_trabalhos;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  select * into t from hubtcc_trabalhos where id = p_trabalho and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  if p_remover then
    update hubtcc_bancas set removido_em = now()
     where trabalho_id = p_trabalho and professor_id = p_professor and removido_em is null;
    return jsonb_build_object('ok', true);
  end if;
  if not exists (select 1 from hubtcc_professores where id = p_professor and edicao = t.edicao and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Professor não encontrado.');
  end if;
  if exists (select 1 from hubtcc_bancas where trabalho_id = p_trabalho and professor_id = p_professor and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Este professor já está na banca.');
  end if;
  insert into hubtcc_bancas (trabalho_id, professor_id) values (p_trabalho, p_professor);
  return jsonb_build_object('ok', true);
end $$;

-- Libera (ou recolhe) as considerações da banca para o aluno.
create or replace function public.hubtcc_coord_banca_liberar(p_token text, p_trabalho uuid, p_liberar boolean)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  update hubtcc_trabalhos set banca_liberada_em = case when p_liberar then now() end
   where id = p_trabalho and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------- grants

revoke all on function public.hubtcc_token_novo() from public, anon, authenticated;
revoke all on function public.hubtcc_prof_do_token(text) from public, anon, authenticated;
revoke all on function public.hubtcc_trab_do_token(text) from public, anon, authenticated;
revoke all on function public.hubtcc_json_versoes(uuid) from public, anon, authenticated;
revoke all on function public.hubtcc_json_registros(uuid) from public, anon, authenticated;
revoke all on function public.hubtcc_json_banca(uuid) from public, anon, authenticated;
revoke all on function public.hubtcc_avaliacao_atual(uuid) from public, anon, authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'hubtcc_subir_parte(text, int, int, text, text)',
    'hubtcc_pdf(text)',
    'hubtcc_edicao(text)',
    'hubtcc_inscrever(text, text, text[], uuid, text, text)',
    'hubtcc_aluno(text)',
    'hubtcc_aluno_versao(text, text, text, boolean)',
    'hubtcc_professor(text)',
    'hubtcc_registrar(text, uuid, text, text)',
    'hubtcc_registro_alterar(text, uuid, text, text, boolean)',
    'hubtcc_liberar(text, uuid, boolean, text)',
    'hubtcc_banca_salvar(text, uuid, text)',
    'hubtcc_coord(text, text)',
    'hubtcc_coord_edicao(text, text, boolean, timestamptz, boolean)',
    'hubtcc_coord_professor(text, text, uuid, text, boolean)',
    'hubtcc_coord_token(text, text, uuid)',
    'hubtcc_coord_remover(text, text, uuid)',
    'hubtcc_coord_orientador(text, uuid, uuid)',
    'hubtcc_coord_banca(text, uuid, uuid, boolean)',
    'hubtcc_coord_banca_liberar(text, uuid, boolean)'] loop
    execute format('revoke all on function public.%s from public', f);
    execute format('grant execute on function public.%s to anon, authenticated, service_role', f);
  end loop;
end $$;

commit;
notify pgrst, 'reload schema';
