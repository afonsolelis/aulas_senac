-- =====================================================================
-- Entregas dos Trabalhos 1 e 2 · Qualidade de Software 2027.1
--
-- Banco: Postgres + PostgREST do projeto aulas_senac no Coolify da VPS
-- Hostinger (não o Supabase cloud; a pasta supabase/ só guarda o nome
-- histórico). Usa as tabelas e funções entrega_* que o esquema do
-- aulas_mackenzie (supabase/entregas_schema.sql) define e que já estão
-- instaladas nesse banco.
-- Este arquivo só insere dois formulários do Senac, um por trabalho:
-- não cria, altera nem substitui objeto nenhum.
--
-- Trabalho individual: max_integrantes = 1. O aluno informa o nome
-- completo e o link do repositório público no GitHub; a página é
-- pages/qualidade3/entrega/entrega.html. O professor abre e fecha o
-- recebimento em pages/qualidade3/entrega/professor.html. O Trabalho 2
-- nasce fechado e é aberto pelo professor na semana 17.
--
-- Quando as turmas de 2027.1 forem definidas, o campo turma pode ser
-- ajustado com update; o slug não muda.
--
-- Idempotente: rodar de novo não mexe em formulário já criado.
-- Aplicar à mão com psql no banco da VPS Hostinger, pelo túnel SSH ou com
-- docker exec no container do Postgres, e recarregar o schema do PostgREST
-- (ver postgrest/README.md).
-- =====================================================================

begin;

insert into entrega_formularios (slug, disciplina, turma, titulo, instrucoes, max_integrantes, aberto)
values
  ('senac-qs-2027-1-trabalho-1', 'Qualidade de Software', '2027.1', 'Trabalho 1',
   'Entrega individual: nome completo e link do repositório público organizacao-recursos, com a tag trabalho-1 enviada. Para corrigir, envie de novo: vale o envio mais recente.', 1, true),
  ('senac-qs-2027-1-trabalho-2', 'Qualidade de Software', '2027.1', 'Trabalho 2',
   'Entrega individual: nome completo e link do repositório público organizacao-recursos, com a tag trabalho-2 enviada. Para corrigir, envie de novo: vale o envio mais recente.', 1, false)
on conflict (slug) do nothing;

commit;
