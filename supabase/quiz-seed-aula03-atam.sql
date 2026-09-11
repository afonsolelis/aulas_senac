-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 03 (Semana 34)
-- Quiz de retomada da Aula 02: "ATAM e Planejamento de Casos de Teste".
--
-- Oito questões, 90 segundos cada, extraídas do slide e do material da
-- Aula 02 (pages/qualidade2/slide_planejamento-casos-teste.html e
-- .../material/material_planejamento-casos-teste.html).
--
-- As questões exigem diagnóstico e decisão, com distratores baseados em
-- confusões reais: atributo × cenário, sensibilidade × trade-off,
-- risco × selo de aprovação e requisito vago × critério mensurável.
-- A posição correta é distribuída entre as quatro letras — duas em cada.
-- Nesta sala a sequência ficou A, B, C, D, A, B, C, D. Não foi reordenada
-- depois de jogada porque o histórico casa as respostas pela posição da
-- alternativa; no próximo semestre, embaralhe antes da primeira turma.
--
-- O token do professor é fixo em '080909' e já vai gravado no fim deste
-- arquivo. Também permite ler relatórios individuais e gabaritos: não
-- oferece confidencialidade. Ver README.md.
--
-- A última questão vale o dobro (peso 2) e a página do aluno registra
-- strike a quem sair da aba com a pergunta aberta: ver quiz-peso-strike.sql.
--
-- Rodar depois de quiz-schema.sql, quiz-peso-strike.sql e
-- quiz-relatorio.sql. É idempotente.
-- =====================================================================

insert into quiz_sessions (slug, titulo, periodo) values
  ('atam-q2-a03', 'Aula 03 — Retomada: ATAM e Casos de Teste', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'atam-q2-a03';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('atam-q2-a03', 1,
   'A equipe conclui a análise e registra três riscos e dois trade-offs. Um gerente afirma que o ATAM aprovou a arquitetura. Qual resposta é consistente com o método?',
   '["O ATAM identifica riscos e conflitos; não certifica que a arquitetura está correta", "A aprovação vale apenas para os cenários classificados como importância alta", "O ATAM aprova a estrutura, mas deixa os atributos para validação em produção", "A arquitetura está aprovada se todos os riscos tiverem um responsável definido"]'::jsonb, 90, 'Propósito do ATAM', 'seção 2'),

  ('atam-q2-a03', 2,
   'A frase “a API deve continuar disponível no pico” será usada como folha da utility tree. Qual alteração a torna uma folha testável?',
   '["Ligá-la à característica Confiabilidade e manter o texto como está", "Definir fonte, estímulo, ambiente, artefato, resposta e medida numérica", "Acrescentar o nome do arquiteto que responderá pelo requisito", "Classificá-la como (A, A), pois prioridade alta dispensa detalhamento"]'::jsonb, 90, 'Cenário em seis partes', 'seção 4'),

  ('atam-q2-a03', 3,
   'Na utility tree, um cenário é muito importante e muito difícil, classificado como (A, A). Qual decisão decorre dessa combinação?',
   '["Adiar, porque cenários difíceis não devem bloquear a primeira entrega", "Automatizar apenas depois que todos os cenários fáceis estiverem cobertos", "Investigar cedo e em profundidade, pois concentra valor e incerteza", "Remover do escopo, porque dificuldade alta indica requisito inviável"]'::jsonb, 90, 'Priorização da utility tree', 'seção 3'),

  ('atam-q2-a03', 4,
   'Reduzir o tempo de cache melhora a revogação de acesso, mas aumenta chamadas ao serviço de autenticação e piora a latência. Como classificar o tempo de cache?',
   '["Não-risco, porque o cache continua funcionando nas duas configurações", "Risco, apenas porque qualquer cache pode guardar um acesso revogado", "Ponto de sensibilidade, apenas porque altera a latência do sistema", "Ponto de trade-off, porque move segurança e performance em sentidos opostos"]'::jsonb, 90, 'Sensibilidade × trade-off', 'seção 5'),

  ('atam-q2-a03', 5,
   'Um cenário define pico, API afetada, 2.000 requisições e p95 abaixo de 2 s. Ao virar caso de teste, onde entram o pico e a API?',
   '["Nas pré-condições, pois ambiente e artefato definem o estado de execução", "Nos passos, pois ambiente e artefato são ações disparadas pelo testador", "No resultado esperado, pois identificam o comportamento aprovado", "Na rastreabilidade, pois substituem o identificador do cenário original"]'::jsonb, 90, 'Do cenário ao caso de teste', 'seção 6'),

  ('atam-q2-a03', 6,
   'O caso CT-021 só funciona se CT-020 tiver criado os dados antes. Qual problema o plano de teste precisa corrigir?',
   '["Falta prioridade, porque casos dependentes devem sempre receber classificação alta", "Falta independência e pré-condição reproduzível, tornando a falha difícil de diagnosticar", "Falta um resultado subjetivo, pois a ordem dos testes precisa ser interpretada", "Falta um ponto de trade-off entre tempo de execução e quantidade de dados"]'::jsonb, 90, 'Anatomia do caso de teste', 'seção 7'),

  ('atam-q2-a03', 7,
   'A matriz mostra um cenário de segurança sem nenhum caso associado. Qual é a utilidade concreta desse achado?',
   '["Provar que o requisito de segurança não é importante para o negócio", "Autorizar a retirada do cenário para que a cobertura volte a 100%", "Expor uma lacuna de cobertura antes que a mudança chegue à produção", "Substituir o teste ausente por uma revisão documental do requisito"]'::jsonb, 90, 'Matriz de rastreabilidade', 'seção 8'),

  ('atam-q2-a03', 8,
   'O plano lista apenas os itens que serão testados. O que falta para transformar a omissão inevitável em decisão controlada?',
   '["Uma meta de cobertura única para todos os módulos do produto", "A assinatura do desenvolvedor responsável por cada caso", "Uma ferramenta de gestão que bloqueie testes fora do escopo", "Os itens que não serão testados, com justificativa e risco assumido"]'::jsonb, 90, 'Escopo do plano de teste', 'seção 8')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 0, 'O ATAM torna riscos, sensibilidades e conflitos discutíveis antes da implementação; ele não mede o sistema nem emite selo de correção. Responsáveis e tratamentos ajudam a governar riscos, mas não convertem o método em certificação.'),
    (2, 1, 'Uma folha testável precisa das seis partes e, sobretudo, de uma medida da resposta. Atributo e prioridade organizam a análise, mas não dizem sob qual estímulo o comportamento passa ou falha.'),
    (3, 2, '(A, A) combina impacto alto com incerteza alta: é onde um erro compromete o negócio e a solução ainda não está dominada. Por isso deve ser analisado e testado cedo, não empurrado para o fim.'),
    (4, 3, 'O tempo de cache é sensível aos dois atributos e produz conflito: encurtá-lo melhora segurança e piora performance. Sensibilidade em apenas um atributo não capturaria essa oposição; o nome correto é ponto de trade-off.'),
    (5, 0, 'Ambiente e artefato viram pré-condições: descrevem onde e sob qual estado o teste começa. Fonte e estímulo geram passos e dados; resposta e medida formam o resultado esperado.'),
    (6, 1, 'Cada caso deve montar ou declarar seu próprio estado inicial. Dependência silenciosa da ordem cria fragilidade: se CT-020 falhar ou a execução mudar, CT-021 falha sem revelar qual regra realmente quebrou.'),
    (7, 2, 'A matriz liga requisito e evidência e torna visível o que ficou sem verificação. A lacuna não prova irrelevância nem deve ser apagada para melhorar um número; ela orienta a decisão de criar o teste ou aceitar o risco explicitamente.'),
    (8, 3, 'Todo plano deixa algo de fora. Registrar itens não testados, justificativa e risco torna a fronteira revisável e assumida; omitir a lista apenas esconde a decisão até que uma falha a revele.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token público legado. Também autoriza relatórios individuais e publicação.
insert into quiz_host_tokens (session_slug, token)
values ('atam-q2-a03', '080909')
on conflict (session_slug) do update set token = excluded.token;

-- A última questão vale o dobro.
update quiz_questions set peso = 2
 where session_slug = 'atam-q2-a03'
   and ordem = (select max(ordem) from quiz_questions where session_slug = 'atam-q2-a03');

select count(*) || ' perguntas carregadas, a última com peso '
       || max(peso) filter (where ordem = 8) as resultado
  from quiz_questions where session_slug = 'atam-q2-a03';
