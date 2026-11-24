-- Banca do TCC2 · 2026.2 (Postgres do aulas_senac na VPS)
--
-- A coordenação aloca professores para a banca de cada trabalho depositado.
-- Cada professor recebe um token único que abre só aquele trabalho, onde ele
-- lê o PDF e escreve as considerações, editáveis a qualquer momento. A
-- coordenação lê as considerações e repassa aos alunos por conta própria.
-- Não há envio de e-mail: a página da coordenação mostra o link e o token
-- para copiar.
--
-- Token do professor: <codigo>-<segredo>. O código (8 hex) localiza a linha;
-- o segredo (122 bits) é conferido por sha256(sal || token). O banco não
-- guarda o token, só o hash: se o professor perder, a coordenação gera outro.
--
-- Objetos NOVOS (prefixo hubbanca_):
--   tabela   hubbanca_avaliadores (RLS ligada, sem policy)
--   funções  hubbanca_coord_ok (interna), hubbanca_gerar_token (interna),
--            hubbanca_listar, hubbanca_alocar, hubbanca_novo_token,
--            hubbanca_remover, hubbanca_abrir, hubbanca_salvar
-- Também substitui hubdeposito_coordenacao para devolver o slug da turma.
--
-- Depende de hubdeposito_respostas, hubdeposito_acesso e entrega_formularios.
-- Idempotente. Aplicar com psql -U postgres -d aulas -v ON_ERROR_STOP=1 -f.

begin;

create table if not exists public.hubbanca_avaliadores (
  id               uuid primary key default gen_random_uuid(),
  formulario_slug  text not null,
  grupo            text not null,
  nome             text not null check (length(nome) between 2 and 120),
  codigo           text not null unique,
  sal              text not null,
  hash             text not null,
  consideracoes    text check (length(consideracoes) <= 20000),
  atualizado_em    timestamptz,
  acesso_em        timestamptz,
  criado_em        timestamptz not null default now(),
  removido_em      timestamptz
);
create index if not exists hubbanca_avaliadores_trabalho
  on public.hubbanca_avaliadores (formulario_slug, lower(grupo));
alter table public.hubbanca_avaliadores enable row level security;
revoke all on public.hubbanca_avaliadores from anon, authenticated;
grant all on public.hubbanca_avaliadores to service_role;

-- Confere o token da coordenação com a mesma trava de hubdeposito_coordenacao.
-- Devolve null quando confere, ou a mensagem de erro.
create or replace function public.hubbanca_coord_ok(p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  a hubdeposito_acesso;
begin
  select * into a from hubdeposito_acesso where papel = 'coordenacao' for update;
  if not found then
    return 'Acesso da coordenação não configurado.';
  end if;
  if a.bloqueado_ate is not null and a.bloqueado_ate > now() then
    return 'Muitas tentativas. Aguarde 15 minutos.';
  end if;
  if encode(sha256(convert_to(a.sal || coalesce(p_token, ''), 'UTF8')), 'hex') <> a.hash then
    update hubdeposito_acesso
       set falhas = falhas + 1,
           bloqueado_ate = case when falhas + 1 >= 5 then now() + interval '15 minutes' end
     where papel = 'coordenacao';
    return 'Token inválido.';
  end if;
  update hubdeposito_acesso set falhas = 0, bloqueado_ate = null where papel = 'coordenacao';
  return null;
end $$;

-- Gera token novo para o avaliador e grava o hash. Devolve o token em claro,
-- que só aparece nesta resposta.
create or replace function public.hubbanca_gerar_token(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
  v_token  text;
  v_sal    text := md5(gen_random_uuid()::text);
begin
  loop
    v_codigo := left(replace(gen_random_uuid()::text, '-', ''), 8);
    exit when not exists (select 1 from hubbanca_avaliadores where codigo = v_codigo);
  end loop;
  v_token := v_codigo || '-' || replace(gen_random_uuid()::text, '-', '');
  update hubbanca_avaliadores
     set codigo = v_codigo, sal = v_sal,
         hash = encode(sha256(convert_to(v_sal || v_token, 'UTF8')), 'hex')
   where id = p_id;
  return v_token;
end $$;

-- Coordenação: avaliadores ativos de todos os trabalhos, com as considerações.
create or replace function public.hubbanca_listar(p_token text)
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
  return jsonb_build_object('ok', true, 'avaliadores', coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'slug', a.formulario_slug, 'grupo', a.grupo, 'nome', a.nome,
      'consideracoes', a.consideracoes, 'atualizado_em', a.atualizado_em,
      'acesso_em', a.acesso_em, 'criado_em', a.criado_em) order by a.criado_em)
    from hubbanca_avaliadores a
    where a.removido_em is null), '[]'::jsonb));
end $$;

-- Coordenação: aloca um professor para o trabalho (turma + grupo).
create or replace function public.hubbanca_alocar(p_token text, p_slug text, p_grupo text, p_nome text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := hubbanca_coord_ok(p_token);
  v_nome text := regexp_replace(trim(coalesce(p_nome, '')), '\s+', ' ', 'g');
  v_id   uuid;
  v_grp  text;
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  if length(v_nome) < 2 or length(v_nome) > 120 then
    return jsonb_build_object('ok', false, 'erro', 'Informe o nome do professor.');
  end if;
  select grupo into v_grp from hubdeposito_respostas
   where formulario_slug = p_slug and lower(grupo) = lower(p_grupo)
   order by enviado_em desc limit 1;
  if v_grp is null then
    return jsonb_build_object('ok', false, 'erro', 'Trabalho não encontrado.');
  end if;
  if (select count(*) from hubbanca_avaliadores
       where formulario_slug = p_slug and lower(grupo) = lower(p_grupo)
         and removido_em is null) >= 6 then
    return jsonb_build_object('ok', false, 'erro', 'Esta banca já tem seis professores.');
  end if;

  insert into hubbanca_avaliadores (formulario_slug, grupo, nome, codigo, sal, hash)
  values (p_slug, v_grp, v_nome, 'tmp-' || gen_random_uuid(), '', '')
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'token', hubbanca_gerar_token(v_id));
end $$;

-- Coordenação: troca o token do professor (o anterior deixa de valer).
create or replace function public.hubbanca_novo_token(p_token text, p_id uuid)
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
  if not exists (select 1 from hubbanca_avaliadores where id = p_id and removido_em is null) then
    return jsonb_build_object('ok', false, 'erro', 'Professor não encontrado.');
  end if;
  return jsonb_build_object('ok', true, 'token', hubbanca_gerar_token(p_id));
end $$;

-- Coordenação: tira o professor da banca. O token para de valer, mas as
-- considerações ficam guardadas na tabela.
create or replace function public.hubbanca_remover(p_token text, p_id uuid)
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
  update hubbanca_avaliadores set removido_em = now() where id = p_id and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Professor não encontrado.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Localiza o avaliador ativo pelo token do professor.
create or replace function public.hubbanca_avaliador_do_token(p_token text)
returns hubbanca_avaliadores
language sql
security definer
set search_path = public
as $$
  select a.* from hubbanca_avaliadores a
   where a.codigo = split_part(coalesce(p_token, ''), '-', 1)
     and a.removido_em is null
     and a.hash = encode(sha256(convert_to(a.sal || p_token, 'UTF8')), 'hex');
$$;

-- Professor: abre o trabalho da banca (último depósito do grupo).
create or replace function public.hubbanca_abrir(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  a hubbanca_avaliadores := hubbanca_avaliador_do_token(trim(p_token));
  r record;
begin
  if a.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  update hubbanca_avaliadores set acesso_em = now() where id = a.id;

  select f.turma, d.titulo, d.integrantes, d.arquivo, d.nome_arquivo, d.enviado_em
    into r
    from hubdeposito_respostas d
    join entrega_formularios f on f.slug = d.formulario_slug
   where d.formulario_slug = a.formulario_slug and lower(d.grupo) = lower(a.grupo)
   order by d.enviado_em desc
   limit 1;

  return jsonb_build_object('ok', true,
    'nome', a.nome, 'turma', r.turma, 'titulo', r.titulo, 'integrantes', r.integrantes,
    'arquivo', r.arquivo, 'nome_arquivo', r.nome_arquivo, 'enviado_em', r.enviado_em,
    'consideracoes', a.consideracoes, 'atualizado_em', a.atualizado_em);
end $$;

-- Professor: grava as considerações (sem trava; pode editar sempre).
create or replace function public.hubbanca_salvar(p_token text, p_texto text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  a hubbanca_avaliadores := hubbanca_avaliador_do_token(trim(p_token));
  v_em timestamptz := now();
begin
  if a.id is null then
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  if length(coalesce(p_texto, '')) > 20000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto passou de 20 mil caracteres.');
  end if;
  update hubbanca_avaliadores
     set consideracoes = nullif(trim(p_texto), ''), atualizado_em = v_em
   where id = a.id;
  return jsonb_build_object('ok', true, 'atualizado_em', v_em);
end $$;

-- A coordenação passa a receber o slug da turma, que a alocação da banca usa.
create or replace function public.hubdeposito_coordenacao(p_token text)
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
  return jsonb_build_object('ok', true, 'depositos', coalesce((
    select jsonb_agg(jsonb_build_object(
      'slug', r.formulario_slug, 'turma', f.turma, 'grupo', r.grupo,
      'integrantes', r.integrantes, 'titulo', r.titulo,
      'arquivo', r.arquivo, 'nome_arquivo', r.nome_arquivo, 'tamanho', r.tamanho,
      'enviado_em', r.enviado_em) order by f.turma, r.grupo)
    from (select distinct on (formulario_slug, lower(grupo)) *
            from hubdeposito_respostas
           order by formulario_slug, lower(grupo), enviado_em desc) r
    join entrega_formularios f on f.slug = r.formulario_slug), '[]'::jsonb));
end $$;

-- Funções internas: fechadas para a API.
revoke all on function public.hubbanca_coord_ok(text) from public, anon, authenticated;
revoke all on function public.hubbanca_gerar_token(uuid) from public, anon, authenticated;
revoke all on function public.hubbanca_avaliador_do_token(text) from public, anon, authenticated;

-- Funções expostas.
revoke all on function public.hubbanca_listar(text) from public;
revoke all on function public.hubbanca_alocar(text, text, text, text) from public;
revoke all on function public.hubbanca_novo_token(text, uuid) from public;
revoke all on function public.hubbanca_remover(text, uuid) from public;
revoke all on function public.hubbanca_abrir(text) from public;
revoke all on function public.hubbanca_salvar(text, text) from public;
revoke all on function public.hubdeposito_coordenacao(text) from public;
grant execute on function public.hubbanca_listar(text) to anon, authenticated, service_role;
grant execute on function public.hubbanca_alocar(text, text, text, text) to anon, authenticated, service_role;
grant execute on function public.hubbanca_novo_token(text, uuid) to anon, authenticated, service_role;
grant execute on function public.hubbanca_remover(text, uuid) to anon, authenticated, service_role;
grant execute on function public.hubbanca_abrir(text) to anon, authenticated, service_role;
grant execute on function public.hubbanca_salvar(text, text) to anon, authenticated, service_role;
grant execute on function public.hubdeposito_coordenacao(text) to anon, authenticated, service_role;

commit;
notify pgrst, 'reload schema';
