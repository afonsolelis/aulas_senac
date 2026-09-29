-- =====================================================================
-- Entrega do projeto · Qualidade de Software 2026.2
--
-- Usa as tabelas e funções entrega_* instaladas pelo repositório
-- aulas_mackenzie (supabase/entregas_schema.sql), que é o dono delas.
-- Este arquivo só insere os três formulários do Senac, um por turma:
-- não cria, altera nem substitui objeto nenhum.
--
-- Formulário sem prazo: o professor abre e fecha o recebimento pela página
-- pages/qualidade2/entrega/professor.html. Grupo de até 4 integrantes e
-- repositório público no GitHub. Token do professor: o mesmo da área de
-- entregas do Mackenzie (hash em entrega_professor).
--
-- Idempotente: rodar de novo não mexe em formulário já criado.
-- =====================================================================

begin;

insert into entrega_formularios (slug, disciplina, turma, titulo, instrucoes, max_integrantes)
values
  ('senac-qs-2026-2-stadscas4na', 'Qualidade de Software', 'STADSCAS4NA · 2026.2', 'Entrega do Projeto',
   'Um envio por grupo, feito por um integrante. Para corrigir, envie de novo com o mesmo link do GitHub: vale o envio mais recente.', 4),
  ('senac-qs-2026-2-stadscas4nb', 'Qualidade de Software', 'STADSCAS4NB · 2026.2', 'Entrega do Projeto',
   'Um envio por grupo, feito por um integrante. Para corrigir, envie de novo com o mesmo link do GitHub: vale o envio mais recente.', 4),
  ('senac-qs-2026-2-stadscas4nd', 'Qualidade de Software', 'STADSCAS4ND · 2026.2', 'Entrega do Projeto',
   'Um envio por grupo, feito por um integrante. Para corrigir, envie de novo com o mesmo link do GitHub: vale o envio mais recente.', 4)
on conflict (slug) do nothing;

commit;
