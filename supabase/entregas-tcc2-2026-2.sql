-- =====================================================================
-- Depósito do TCC2 · 2026.2
--
-- Usa as tabelas e funções entrega_* instaladas pelo repositório
-- aulas_mackenzie (supabase/entregas_schema.sql), que é o dono delas.
-- Este arquivo só insere o formulário da turma BCCCAS8NA:
-- não cria, altera nem substitui objeto nenhum.
--
-- Formulário sem prazo: o professor abre e fecha o recebimento pela página
-- pages/tcc2/entrega/professor.html. Grupo de até 4 integrantes e
-- repositório público no GitHub. Token do professor: o mesmo da área de
-- entregas do Mackenzie (hash em entrega_professor).
--
-- Idempotente: rodar de novo não mexe em formulário já criado.
-- =====================================================================

begin;

insert into entrega_formularios (slug, disciplina, turma, titulo, instrucoes, max_integrantes)
values
  ('senac-tcc2-2026-2-bcccas8na', 'TCC2', 'BCCCAS8NA · 2026.2', 'Depósito do TCC2',
   'Um envio por grupo, feito por um integrante. Para corrigir, envie de novo com o mesmo link do GitHub: vale o envio mais recente.', 4)
on conflict (slug) do nothing;

commit;
