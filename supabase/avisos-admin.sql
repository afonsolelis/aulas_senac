-- =====================================================================
-- Conta do professor no quadro de avisos
-- Rodar no SQL Editor DEPOIS de supabase/avisos-schema.sql.
--
-- ⚠️  TROQUE 'SENHA-AQUI' pela senha real ANTES de executar, e não
--     versione a senha: este arquivo está num repositório público
--     (github.com/afonsolelis/aulas_senac). Só o hash salgado fica no
--     banco — nem o Supabase guarda a senha em claro.
--
-- Reexecutar redefine a senha do usuário e zera o bloqueio por tentativas.
-- =====================================================================

with nova as (
  select 'afonsolelis'::text            as usuario,
         avisos_novo_token()            as salt,
         'SENHA-AQUI'::text             as senha
)
insert into avisos_admin (usuario, salt, senha_hash)
select usuario, salt, avisos_hash(salt, senha) from nova
on conflict (usuario) do update
   set salt          = excluded.salt,
       senha_hash    = excluded.senha_hash,
       falhas        = 0,
       bloqueado_ate = null;

-- Conferência (deve devolver a conta, sem revelar a senha):
--   select usuario, criado_em, falhas, bloqueado_ate from avisos_admin;

-- Para destravar a conta depois de 5 erros seguidos, sem trocar a senha:
--   update avisos_admin set falhas = 0, bloqueado_ate = null
--    where usuario = 'afonsolelis';
