-- =====================================================================
-- Quadro de avisos — esquema, RLS e RPCs
-- Projeto: lwamaovuxcevsjfvtqhf (Supabase do Hub de Aulas Senac)
--
-- Suporte do widget de avisos (js/avisos.js) e da página pages/avisos.html.
-- Mesmo desenho de acesso do quiz: NENHUMA tabela é legível pela API — RLS
-- habilitada e nenhuma policy — e tudo passa pelas funções SECURITY DEFINER
-- do final. A leitura pública (avisos_listar) devolve só os avisos vigentes,
-- nunca os removidos, os expirados nem qualquer dado da conta do professor.
--
-- A senha do professor NÃO fica no JavaScript: o navegador manda usuário e
-- senha para avisos_login, que compara com o hash salgado guardado aqui e
-- devolve um token de sessão de 12 h. Sem a senha não há publicação.
--
-- Rodar inteiro no SQL Editor do painel. É idempotente e NÃO destrutivo:
-- reexecutar preserva os avisos já publicados e a conta do professor.
-- Depois deste arquivo, rode supabase/avisos-admin.sql para criar a conta.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------

create table if not exists avisos (
  id            bigint generated always as identity primary key,
  titulo        text        not null,
  corpo         text        not null,
  escopo        text        not null default 'geral',  -- 'geral' ou slug da disciplina
  fixado        boolean     not null default false,
  publicado_em  timestamptz not null default now(),
  atualizado_em timestamptz,
  expira_em     timestamptz,                            -- nulo = não expira
  removido_em   timestamptz                             -- nulo = visível
);

create index if not exists avisos_vigentes
  on avisos (escopo, fixado desc, publicado_em desc)
  where removido_em is null;

-- Conta do professor. Uma linha por usuário; a senha vive só como hash
-- salgado (sha256 nativo do Postgres — sem depender de extensão).
create table if not exists avisos_admin (
  usuario       text primary key,
  salt          text not null,
  senha_hash    text not null,
  falhas        int  not null default 0,
  bloqueado_ate timestamptz,
  criado_em     timestamptz not null default now()
);

-- Sessões emitidas por avisos_login. O token é a credencial do professor
-- daí em diante e mora no localStorage do navegador dele.
create table if not exists avisos_sessoes (
  token     text primary key,
  usuario   text not null references avisos_admin(usuario) on delete cascade,
  criada_em timestamptz not null default now(),
  expira_em timestamptz not null
);

-- ---------------------------------------------------------------------
-- RLS — negar por omissão, sem exceção
-- ---------------------------------------------------------------------

alter table avisos          enable row level security;
alter table avisos_admin    enable row level security;
alter table avisos_sessoes  enable row level security;

-- Nenhuma policy em tabela alguma: diferente do quiz, aqui nem a leitura
-- direta existe (não há Realtime a atender). Reforço sobre os grants amplos
-- que o Supabase concede ao schema public.
revoke all on avisos         from anon, authenticated;
revoke all on avisos_admin   from anon, authenticated;
revoke all on avisos_sessoes from anon, authenticated;

-- ---------------------------------------------------------------------
-- Funções internas — não são RPC, ninguém de fora as executa
-- ---------------------------------------------------------------------

create or replace function avisos_hash(p_salt text, p_senha text)
returns text language sql immutable as $$
  select encode(sha256(convert_to(p_salt || ':' || p_senha, 'utf8')), 'hex')
$$;

-- Token opaco de 256 bits, sem pgcrypto: dois uuid v4 concatenados.
create or replace function avisos_novo_token()
returns text language sql volatile as $$
  select replace(gen_random_uuid()::text, '-', '')
      || replace(gen_random_uuid()::text, '-', '')
$$;

-- Traduz token de sessão em usuário; nulo se inválido ou vencido.
create or replace function avisos_usuario(p_token text)
returns text
language sql security definer stable set search_path = public, pg_temp as $$
  select usuario from avisos_sessoes
   where token = p_token and expira_em > now()
$$;

revoke all on function avisos_hash(text, text)  from public, anon, authenticated;
revoke all on function avisos_novo_token()      from public, anon, authenticated;
revoke all on function avisos_usuario(text)     from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Leitura pública — o que o aluno vê
-- ---------------------------------------------------------------------

-- Devolve os avisos vigentes: os de escopo 'geral' mais os da disciplina da
-- página que perguntou. Fixados primeiro, depois do mais recente ao mais
-- antigo. Removidos e expirados nunca saem daqui.
create or replace function avisos_listar(p_escopo text default null)
returns jsonb
language plpgsql security definer stable set search_path = public, pg_temp as $$
declare v jsonb;
begin
  select coalesce(jsonb_agg(x order by x.fixado desc, x.publicado_em desc), '[]'::jsonb)
    into v
    from (
      select id, titulo, corpo, escopo, fixado, publicado_em, atualizado_em, expira_em
        from avisos
       where removido_em is null
         and (expira_em is null or expira_em > now())
         and (p_escopo is null or escopo = 'geral' or escopo = lower(p_escopo))
       order by fixado desc, publicado_em desc
       limit 50
    ) x;

  return jsonb_build_object('ok', true, 'agora', now(), 'avisos', v);
end $$;

-- ---------------------------------------------------------------------
-- Sessão do professor
-- ---------------------------------------------------------------------

-- Cinco erros seguidos bloqueiam a conta por 15 minutos. É o que torna uma
-- senha curta defensável: sem isso, seis dígitos caem por força bruta.
create or replace function avisos_login(p_usuario text, p_senha text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare a record; v_token text; v_falta int;
begin
  select * into a from avisos_admin
   where usuario = lower(btrim(coalesce(p_usuario, '')));

  if a.usuario is null then
    perform pg_sleep(0.4);   -- mesma latência do usuário existente
    return jsonb_build_object('ok', false, 'erro', 'Usuário ou senha inválidos.');
  end if;

  if a.bloqueado_ate is not null and a.bloqueado_ate > now() then
    v_falta := greatest(1, ceil(extract(epoch from (a.bloqueado_ate - now())) / 60)::int);
    return jsonb_build_object('ok', false,
      'erro', 'Muitas tentativas. Tente de novo em ' || v_falta || ' min.');
  end if;

  if avisos_hash(a.salt, coalesce(p_senha, '')) <> a.senha_hash then
    update avisos_admin
       set falhas = falhas + 1,
           bloqueado_ate = case when falhas + 1 >= 5
                                then now() + interval '15 minutes' end
     where usuario = a.usuario;
    perform pg_sleep(0.4);
    return jsonb_build_object('ok', false, 'erro', 'Usuário ou senha inválidos.');
  end if;

  update avisos_admin set falhas = 0, bloqueado_ate = null where usuario = a.usuario;

  delete from avisos_sessoes where expira_em < now();

  v_token := avisos_novo_token();
  insert into avisos_sessoes (token, usuario, expira_em)
  values (v_token, a.usuario, now() + interval '12 hours');

  return jsonb_build_object('ok', true, 'token', v_token,
                            'usuario', a.usuario,
                            'expira_em', now() + interval '12 hours');
end $$;

create or replace function avisos_sair(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  delete from avisos_sessoes where token = p_token;
  return jsonb_build_object('ok', true);
end $$;

create or replace function avisos_trocar_senha(p_token text, p_atual text, p_nova text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text; a record; v_salt text;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  select * into a from avisos_admin where usuario = v_usuario;
  if avisos_hash(a.salt, coalesce(p_atual, '')) <> a.senha_hash then
    perform pg_sleep(0.4);
    return jsonb_build_object('ok', false, 'erro', 'A senha atual não confere.');
  end if;

  if char_length(coalesce(p_nova, '')) < 8 then
    return jsonb_build_object('ok', false, 'erro', 'A nova senha precisa de ao menos 8 caracteres.');
  end if;

  v_salt := avisos_novo_token();
  update avisos_admin
     set salt = v_salt, senha_hash = avisos_hash(v_salt, p_nova),
         falhas = 0, bloqueado_ate = null
   where usuario = v_usuario;

  -- Trocar a senha derruba as outras sessões abertas.
  delete from avisos_sessoes where usuario = v_usuario and token <> p_token;

  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- Escrita — só com token de sessão válido
-- ---------------------------------------------------------------------

create or replace function avisos_publicar(
  p_token     text,
  p_titulo    text,
  p_corpo     text,
  p_escopo    text        default 'geral',
  p_fixado    boolean     default false,
  p_expira_em timestamptz default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text; v_titulo text; v_corpo text; v_escopo text; v_id bigint;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  v_titulo := btrim(coalesce(p_titulo, ''));
  v_corpo  := btrim(coalesce(p_corpo, ''));
  v_escopo := lower(btrim(coalesce(nullif(p_escopo, ''), 'geral')));

  if char_length(v_titulo) < 3 or char_length(v_titulo) > 90 then
    return jsonb_build_object('ok', false, 'erro', 'O título deve ter entre 3 e 90 caracteres.');
  end if;
  if char_length(v_corpo) < 3 or char_length(v_corpo) > 2000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto deve ter entre 3 e 2000 caracteres.');
  end if;
  if v_escopo !~ '^[a-z0-9_-]{1,32}$' then
    return jsonb_build_object('ok', false, 'erro', 'Escopo inválido.');
  end if;

  insert into avisos (titulo, corpo, escopo, fixado, expira_em)
  values (v_titulo, v_corpo, v_escopo, coalesce(p_fixado, false), p_expira_em)
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function avisos_editar(
  p_token     text,
  p_id        bigint,
  p_titulo    text,
  p_corpo     text,
  p_escopo    text        default 'geral',
  p_fixado    boolean     default false,
  p_expira_em timestamptz default null)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text; v_titulo text; v_corpo text; v_escopo text;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  v_titulo := btrim(coalesce(p_titulo, ''));
  v_corpo  := btrim(coalesce(p_corpo, ''));
  v_escopo := lower(btrim(coalesce(nullif(p_escopo, ''), 'geral')));

  if char_length(v_titulo) < 3 or char_length(v_titulo) > 90 then
    return jsonb_build_object('ok', false, 'erro', 'O título deve ter entre 3 e 90 caracteres.');
  end if;
  if char_length(v_corpo) < 3 or char_length(v_corpo) > 2000 then
    return jsonb_build_object('ok', false, 'erro', 'O texto deve ter entre 3 e 2000 caracteres.');
  end if;
  if v_escopo !~ '^[a-z0-9_-]{1,32}$' then
    return jsonb_build_object('ok', false, 'erro', 'Escopo inválido.');
  end if;

  update avisos
     set titulo = v_titulo, corpo = v_corpo, escopo = v_escopo,
         fixado = coalesce(p_fixado, false), expira_em = p_expira_em,
         atualizado_em = now()
   where id = p_id;

  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Aviso não encontrado.');
  end if;

  return jsonb_build_object('ok', true, 'id', p_id);
end $$;

-- Remoção é lógica: o aviso sai da vista mas continua no banco, para que um
-- clique errado seja reversível (avisos_restaurar).
create or replace function avisos_remover(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  update avisos set removido_em = now() where id = p_id and removido_em is null;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Aviso não encontrado.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function avisos_restaurar(p_token text, p_id bigint)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  update avisos set removido_em = null where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'erro', 'Aviso não encontrado.');
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- Visão do professor: inclui removidos e expirados, para gerir.
create or replace function avisos_painel(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_usuario text; v jsonb;
begin
  v_usuario := avisos_usuario(p_token);
  if v_usuario is null then
    return jsonb_build_object('ok', false, 'erro', 'Sessão expirada. Entre de novo.');
  end if;

  select coalesce(jsonb_agg(x order by x.publicado_em desc), '[]'::jsonb)
    into v
    from (
      select id, titulo, corpo, escopo, fixado, publicado_em, atualizado_em,
             expira_em, removido_em,
             (removido_em is null and (expira_em is null or expira_em > now())) as vigente
        from avisos
       order by publicado_em desc
       limit 200
    ) x;

  return jsonb_build_object('ok', true, 'usuario', v_usuario, 'agora', now(), 'avisos', v);
end $$;

-- ---------------------------------------------------------------------
-- Conferência dos grants (ver a armadilha descrita em supabase/README.md:
-- revogar de PUBLIC não basta, o Supabase concede EXECUTE a anon por
-- default privilege em toda função nova do schema public).
--
--   select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname like 'avisos%' order by 2 desc, 1;
--
-- Devem sair com t apenas: avisos_listar, avisos_login, avisos_sair,
-- avisos_trocar_senha, avisos_publicar, avisos_editar, avisos_remover,
-- avisos_restaurar, avisos_painel.
-- ---------------------------------------------------------------------
