-- Depósito do PDF final do TCC2 no Postgres do aulas_senac (VPS).
-- Substitui o bucket hub-tcc2-depositos do Supabase Storage, que o PostgREST não tem.
--
-- hubdeposito_subir  : recebe o PDF em base64 no caminho escolhido pela página
--                      (<turma>/<uuid>.pdf), só para turma de TCC2 com recebimento aberto.
-- hubdeposito_pdf    : GET /rpc/hubdeposito_pdf?p_caminho=... devolve o PDF
--                      (Content-Type application/pdf) para qualquer Accept, como o
--                      link público do bucket.
-- hubdeposito_enviar : passa a conferir o arquivo nesta tabela em vez de storage.objects.
--
-- Idempotente. Aplicar com psql -U postgres -d aulas -v ON_ERROR_STOP=1 -f.

begin;

create table if not exists public.hubdeposito_arquivos (
  caminho    text primary key,
  conteudo   bytea not null,
  tamanho    bigint not null,
  enviado_em timestamptz not null default now()
);
alter table public.hubdeposito_arquivos enable row level security;
revoke all on public.hubdeposito_arquivos from anon, authenticated;
grant all on public.hubdeposito_arquivos to service_role;

-- Tipo "*/*" para o PostgREST devolver os bytes crus a qualquer Accept
-- (um link comum do navegador manda text/html,...,*/*). O Content-Type vai
-- em response.headers.
do $$ begin
  if not exists (select 1 from pg_type where typname = '*/*') then
    create domain "*/*" as bytea;
  end if;
end $$;
drop function if exists public.hubdeposito_pdf(text);
drop domain if exists "application/pdf";

create or replace function public.hubdeposito_subir(p_caminho text, p_conteudo text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_turma text;
  v_slug  text;
  v_bin   bytea;
  f       entrega_formularios;
begin
  if coalesce(p_caminho, '') !~ '^[a-z0-9]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$' then
    raise exception 'Arquivo inválido. Envie o PDF de novo.';
  end if;
  v_turma := split_part(p_caminho, '/', 1);
  select slug into v_slug from entrega_formularios
   where slug like 'senac-tcc2-%' and regexp_replace(slug, '^.*-', '') = v_turma;
  if v_slug is null then
    raise exception 'Formulário não encontrado.';
  end if;
  select * into f from entrega_formularios where slug = v_slug;
  if not f.aberto or now() > coalesce(f.prazo, 'infinity') then
    raise exception 'O recebimento desta turma está fechado.';
  end if;

  begin
    v_bin := decode(p_conteudo, 'base64');
  exception when others then
    raise exception 'O PDF chegou corrompido. Envie de novo.';
  end;
  if v_bin is null or length(v_bin) = 0 then
    raise exception 'O PDF chegou vazio. Envie de novo.';
  end if;
  if length(v_bin) > 30 * 1024 * 1024 then
    raise exception 'O PDF passa de 30 MB. Comprima o arquivo e tente de novo.';
  end if;
  if substring(v_bin from 1 for 4) <> '\x25504446'::bytea then  -- %PDF
    raise exception 'O arquivo não é um PDF.';
  end if;
  if exists (select 1 from hubdeposito_arquivos where caminho = p_caminho) then
    raise exception 'Este arquivo já foi enviado.';
  end if;

  -- Uploads que nunca viraram depósito somem depois de um dia.
  delete from hubdeposito_arquivos a
   where a.enviado_em < now() - interval '1 day'
     and not exists (select 1 from hubdeposito_respostas r where r.arquivo = a.caminho);

  if (select count(*) from hubdeposito_arquivos
       where split_part(caminho, '/', 1) = v_turma
         and enviado_em > now() - interval '10 minutes') >= 30 then
    raise exception 'Muitos envios em poucos minutos. Aguarde e tente de novo.';
  end if;

  insert into hubdeposito_arquivos (caminho, conteudo, tamanho) values (p_caminho, v_bin, length(v_bin));
  return jsonb_build_object('caminho', p_caminho, 'tamanho', length(v_bin));
end $$;

create or replace function public.hubdeposito_pdf(p_caminho text)
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
  select a.conteudo into v_bin from hubdeposito_arquivos a where a.caminho = p_caminho;
  if v_bin is null then
    perform set_config('response.status', '404', true);
    return null;
  end if;
  select nome_arquivo into v_nome from hubdeposito_respostas where arquivo = p_caminho
   order by enviado_em desc limit 1;
  v_nome := regexp_replace(coalesce(v_nome, split_part(p_caminho, '/', 2)), '[^A-Za-z0-9._ -]', '_', 'g');
  perform set_config('response.headers', json_build_array(
    json_build_object('Content-Type', 'application/pdf'),
    json_build_object('Content-Disposition', 'inline; filename="' || v_nome || '"'),
    json_build_object('Cache-Control', 'private, max-age=300'))::text, true);
  return v_bin;
end $$;

create or replace function public.hubdeposito_enviar(p_slug text, p_integrantes text[], p_arquivo text, p_nome_arquivo text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  f       entrega_formularios;
  v_nome  text[];
  v_grp   text;
  v_tam   bigint;
  v_id    uuid;
  v_em    timestamptz;
begin
  if p_slug not like 'senac-tcc2-%' then
    raise exception 'Formulário não encontrado.';
  end if;
  select * into f from entrega_formularios where slug = p_slug;
  if not found then
    raise exception 'Formulário não encontrado.';
  end if;
  if not f.aberto or now() > coalesce(f.prazo, 'infinity') then
    raise exception 'O recebimento desta turma está fechado.';
  end if;
  select coalesce(array_agg(n order by ord), '{}') into v_nome
    from (select trim(x) as n, ord from unnest(coalesce(p_integrantes, '{}')) with ordinality as t(x, ord)) s
   where n <> '';
  if cardinality(v_nome) = 0 then
    raise exception 'Informe o nome de pelo menos um integrante.';
  end if;
  if cardinality(v_nome) > f.max_integrantes then
    raise exception 'O grupo tem no máximo % integrantes.', f.max_integrantes;
  end if;
  if exists (select 1 from unnest(v_nome) n where length(n) not between 3 and 120) then
    raise exception 'Cada nome precisa ter entre 3 e 120 caracteres.';
  end if;
  if split_part(coalesce(p_arquivo, ''), '/', 1) <> regexp_replace(p_slug, '^.*-', '') then
    raise exception 'Arquivo inválido. Envie o PDF de novo.';
  end if;
  select a.tamanho into v_tam from hubdeposito_arquivos a where a.caminho = p_arquivo;
  if not found then
    raise exception 'O PDF não chegou ao servidor. Envie de novo.';
  end if;
  if exists (select 1 from hubdeposito_respostas where arquivo = p_arquivo) then
    raise exception 'Este arquivo já foi registrado.';
  end if;
  v_grp := v_nome[1];
  if (select count(*) from hubdeposito_respostas
       where formulario_slug = p_slug and lower(grupo) = lower(v_grp)
         and enviado_em > now() - interval '10 minutes') >= 5 then
    raise exception 'Muitos envios em poucos minutos. Aguarde e tente de novo.';
  end if;

  insert into hubdeposito_respostas (formulario_slug, grupo, integrantes, arquivo, nome_arquivo, tamanho)
  values (p_slug, v_grp, array_to_string(v_nome, E'\n'), p_arquivo, left(p_nome_arquivo, 200), v_tam)
  returning id, enviado_em into v_id, v_em;

  return jsonb_build_object('id', v_id, 'enviado_em', v_em, 'arquivo', p_arquivo);
end $function$;

revoke all on function public.hubdeposito_subir(text, text) from public;
revoke all on function public.hubdeposito_pdf(text) from public;
grant execute on function public.hubdeposito_subir(text, text) to anon, authenticated, service_role;
grant execute on function public.hubdeposito_pdf(text) to anon, authenticated, service_role;

commit;
notify pgrst, 'reload schema';
