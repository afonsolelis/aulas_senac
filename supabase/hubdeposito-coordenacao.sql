-- =====================================================================
-- Acesso da coordenação aos depósitos do TCC2 (somente leitura)
--
-- Depende de supabase/hubdeposito-tcc2.sql. Objetos NOVOS:
--   tabela  hubdeposito_acesso (RLS ligada, sem policy)
--   função  hubdeposito_coordenacao(p_token)
--
-- O token da coordenação NÃO fica neste arquivo (o repositório é público).
-- Para criar ou trocar, rode no SQL Editor trocando TOKEN-AQUI:
--
--   insert into hubdeposito_acesso (papel, sal, hash)
--   select 'coordenacao', s, encode(sha256(convert_to(s || 'TOKEN-AQUI', 'UTF8')), 'hex')
--     from (select md5(random()::text || clock_timestamp()::text) as s) x
--   on conflict (papel) do update set sal = excluded.sal, hash = excluded.hash;
--
-- A função devolve só o envio mais recente de cada grupo, sem nota nem
-- comentário. Cinco tokens errados seguidos bloqueiam por 15 minutos.
-- Idempotente e sem drop/alter/replace em objeto existente.
-- =====================================================================

begin;

create table if not exists hubdeposito_acesso (
  papel          text primary key,
  sal            text not null,
  hash           text not null,
  falhas         int not null default 0,
  bloqueado_ate  timestamptz
);
alter table hubdeposito_acesso enable row level security;

create function hubdeposito_coordenacao(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  a hubdeposito_acesso;
begin
  select * into a from hubdeposito_acesso where papel = 'coordenacao' for update;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Acesso da coordenação não configurado.');
  end if;
  if a.bloqueado_ate is not null and a.bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'erro', 'Muitas tentativas. Aguarde 15 minutos.');
  end if;
  if encode(sha256(convert_to(a.sal || coalesce(p_token, ''), 'UTF8')), 'hex') <> a.hash then
    update hubdeposito_acesso
       set falhas = falhas + 1,
           bloqueado_ate = case when falhas + 1 >= 5 then now() + interval '15 minutes' end
     where papel = 'coordenacao';
    return jsonb_build_object('ok', false, 'erro', 'Token inválido.');
  end if;
  update hubdeposito_acesso set falhas = 0, bloqueado_ate = null where papel = 'coordenacao';

  return jsonb_build_object('ok', true, 'depositos', coalesce((
    select jsonb_agg(jsonb_build_object(
      'turma', f.turma, 'grupo', r.grupo, 'integrantes', r.integrantes,
      'arquivo', r.arquivo, 'nome_arquivo', r.nome_arquivo, 'tamanho', r.tamanho,
      'enviado_em', r.enviado_em) order by f.turma, r.grupo)
    from (select distinct on (formulario_slug, lower(grupo)) *
            from hubdeposito_respostas
           order by formulario_slug, lower(grupo), enviado_em desc) r
    join entrega_formularios f on f.slug = r.formulario_slug), '[]'::jsonb));
end $$;

revoke all on function hubdeposito_coordenacao(text) from public;
grant execute on function hubdeposito_coordenacao(text) to anon, authenticated;

commit;
