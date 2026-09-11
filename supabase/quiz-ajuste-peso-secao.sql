-- =====================================================================
-- Qualidade de Software 2026.2 — ajuste das salas já instaladas
--
-- 1. A última questão de toda sala vale o dobro (peso 2). Antes, só as
--    salas das aulas 07 e 08 tinham esse peso.
-- 2. O campo secao passa a apontar para a seção numerada do material que
--    o aluno relê ("O que retomar"). Várias salas apontavam para a seção
--    errada; os seeds já foram corrigidos e este arquivo leva a correção
--    para o banco sem rodá-los de novo.
--
-- Por que não rodar os seeds: eles fazem delete + insert nas questões, e o
-- delete apaga em cascata as respostas de uma rodada ainda não arquivada.
-- Aqui só há update: jogadores, respostas e histórico ficam intactos. As
-- rodadas já arquivadas em quiz_relatorios guardam a secao antiga — é o
-- registro do que a turma viu na hora.
--
-- Rodar uma vez no SQL Editor, depois de quiz-peso-strike.sql. Idempotente.
-- =====================================================================

begin;

update quiz_questions q set peso = 2
 where q.session_slug in ('qualidade-q2-a02', 'atam-q2-a03', 'caixa-q2-a04', 'atam-q2-a05',
                          'bugs-q2-a06', 'ci-q2-a07', 'cobertura-q2-a08')
   and q.ordem = (select max(ordem) from quiz_questions where session_slug = q.session_slug);

update quiz_questions q set secao = v.secao
  from (values
    ('qualidade-q2-a02', 5, 'seção 7'),
    ('qualidade-q2-a02', 6, 'seção 8'),
    ('qualidade-q2-a02', 8, 'seção 6'),
    ('atam-q2-a05', 1, 'seção 2'),
    ('atam-q2-a05', 2, 'seção 3'),
    ('atam-q2-a05', 3, 'seção 5'),
    ('atam-q2-a05', 4, 'seção 5'),
    ('atam-q2-a05', 5, 'seção 6'),
    ('atam-q2-a05', 6, 'seção 6'),
    ('atam-q2-a05', 7, 'seção 6'),
    ('atam-q2-a05', 8, 'seção 8'),
    ('bugs-q2-a06', 3, 'seção 4'),
    ('bugs-q2-a06', 4, 'seção 5'),
    ('bugs-q2-a06', 6, 'seção 7'),
    ('bugs-q2-a06', 7, 'seção 8'),
    ('bugs-q2-a06', 8, 'seção 9'),
    ('ci-q2-a07', 1, 'seção 2'),
    ('ci-q2-a07', 2, 'seção 4'),
    ('ci-q2-a07', 3, 'seção 6'),
    ('ci-q2-a07', 4, 'seção 7'),
    ('ci-q2-a07', 6, 'seção 9'),
    ('ci-q2-a07', 7, 'seção 8'),
    ('ci-q2-a07', 8, 'seção 9'),
    ('cobertura-q2-a08', 1, 'seção 5'),
    ('cobertura-q2-a08', 2, 'seção 6'),
    ('cobertura-q2-a08', 3, 'seção 4'),
    ('cobertura-q2-a08', 4, 'seção 7'),
    ('cobertura-q2-a08', 5, 'seção 8'),
    ('cobertura-q2-a08', 6, 'seção 9'),
    ('cobertura-q2-a08', 7, 'seção 11'),
    ('cobertura-q2-a08', 8, 'seção 3')
  ) as v(slug, ordem, secao)
 where q.session_slug = v.slug and q.ordem = v.ordem;

commit;

-- Conferência: toda sala com peso 2 só na última questão.
select session_slug,
       count(*)                                        as questoes,
       max(peso) filter (where ordem = 8)              as peso_ultima,
       count(*) filter (where peso > 1)                as com_peso,
       string_agg(ordem || ': ' || secao, ' | ' order by ordem) as secoes
  from quiz_questions
 where session_slug like '%-q2-a0%'
 group by session_slug
 order by session_slug;
