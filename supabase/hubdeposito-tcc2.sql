-- =====================================================================
-- Depósito do PDF final do TCC2 · 2026.2
--
-- O aluno sobe o PDF para o bucket hub-tcc2-depositos (nome sorteado no
-- navegador, pasta = turma) e depois chama hubdeposito_enviar, que confere
-- o arquivo no storage e grava o depósito em hubdeposito_respostas.
--
-- Objetos NOVOS deste arquivo (prefixo hubdeposito_ / bucket hub-tcc2-*):
--   bucket   hub-tcc2-depositos (PDF, até 30 MB)
--   policy   "hub-tcc2-depositos: envio" em storage.objects (só INSERT, só neste bucket)
--   tabela   hubdeposito_respostas (RLS ligada, sem policy)
--   funções  hubdeposito_enviar, hubdeposito_painel, hubdeposito_corrigir
--
-- Usa sem alterar: entrega_formularios (abertura da turma, slug senac-tcc2-*),
-- entrega_checar_token (token do professor) e entrega_ajustar (abrir/fechar),
-- todos do repositório aulas_mackenzie.
--
-- O bucket é público para leitura direta pelo link, mas não há policy de
-- SELECT: ninguém lista os arquivos. O link (nome sorteado de 122 bits) só
-- aparece no comprovante de quem enviou e no painel do professor.
--
-- Idempotente e sem drop/alter/replace em objeto existente.
-- =====================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('hub-tcc2-depositos', 'hub-tcc2-depositos', true, 31457280, array['application/pdf'])
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'storage' and tablename = 'objects'
                    and policyname = 'hub-tcc2-depositos: envio') then
    create policy "hub-tcc2-depositos: envio" on storage.objects
      for insert to anon, authenticated
      with check (bucket_id = 'hub-tcc2-depositos'
                  and name ~ '^[a-z0-9]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.pdf$');
  end if;
end $$;

create table if not exists hubdeposito_respostas (
  id               uuid primary key default gen_random_uuid(),
  formulario_slug  text not null,
  grupo            text not null,
  integrantes      text not null,
  arquivo          text not null unique,
  nome_arquivo     text,
  tamanho          bigint,
  enviado_em       timestamptz not null default now(),
  nota             numeric(4, 2) check (nota between 0 and 10),
  comentario       text,
  corrigido_em     timestamptz
);
alter table hubdeposito_respostas enable row level security;

create function hubdeposito_enviar(
  p_slug text, p_integrantes text[], p_arquivo text, p_nome_arquivo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  select (o.metadata ->> 'size')::bigint into v_tam
    from storage.objects o
   where o.bucket_id = 'hub-tcc2-depositos' and o.name = p_arquivo;
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
end $$;

create function hubdeposito_painel(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := entrega_checar_token(p_token);
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  return jsonb_build_object('ok', true, 'formularios', coalesce((
    select jsonb_agg(jsonb_build_object(
      'slug', f.slug, 'turma', f.turma, 'titulo', f.titulo, 'aberto', f.aberto,
      'prazo', f.prazo, 'max_integrantes', f.max_integrantes,
      'respostas', coalesce((
        select jsonb_agg(to_jsonb(r) - 'formulario_slug' order by r.grupo, r.enviado_em desc)
        from hubdeposito_respostas r where r.formulario_slug = f.slug), '[]'::jsonb))
      order by f.slug)
    from entrega_formularios f where f.slug like 'senac-tcc2-%'), '[]'::jsonb));
end $$;

create function hubdeposito_corrigir(
  p_token text, p_id uuid, p_nota numeric, p_comentario text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_erro text := entrega_checar_token(p_token);
begin
  if v_erro is not null then
    return jsonb_build_object('ok', false, 'erro', v_erro);
  end if;
  if p_nota is not null and (p_nota < 0 or p_nota > 10) then
    return jsonb_build_object('ok', false, 'erro', 'A nota vai de 0 a 10.');
  end if;
  update hubdeposito_respostas
     set nota = p_nota,
         comentario = nullif(trim(p_comentario), ''),
         corrigido_em = case when p_nota is null and nullif(trim(p_comentario), '') is null
                             then null else now() end
   where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Depósito não encontrado.');
  end if;
  return jsonb_build_object('ok', true, 'corrigido_em', now());
end $$;

revoke all on function hubdeposito_enviar(text, text[], text, text),
  hubdeposito_painel(text), hubdeposito_corrigir(text, uuid, numeric, text) from public;
grant execute on function hubdeposito_enviar(text, text[], text, text),
  hubdeposito_painel(text), hubdeposito_corrigir(text, uuid, numeric, text) to anon, authenticated;

commit;
