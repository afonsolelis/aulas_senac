-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 04 (Semana 35)
-- Quiz de retomada da Aula 03: "Caixa Branca vs Caixa Preta e o
-- nascimento do Foot Fanatics".
--
-- Oito questões, 40 segundos cada, extraídas do slide e do material da
-- Aula 03 (pages/qualidade2/slide_caixa-branca-preta.html e
-- .../material/material_caixa-branca-preta.html).
--
-- As questões são de aplicação: cada uma apresenta uma situação de código
-- ou de projeto de teste e pede o diagnóstico. Os distratores reproduzem
-- as confusões correntes (cobertura de comando × ramo × condição, o que
-- cada caixa enxerga, cobertura como prova de proteção, RNF sem métrica).
-- A posição da correta é distribuída entre as quatro letras e o
-- comprimento das alternativas é equilibrado.
--
-- O token do professor é fixo em '080909' e já vai gravado no fim deste
-- arquivo — decisão do professor: a sala é descartável e o token só abre,
-- revela e reinicia.
--
--   insert into quiz_host_tokens (session_slug, token)
--   values ('caixa-q2-a04', 'COLE-O-TOKEN-AQUI')
--   on conflict (session_slug) do update set token = excluded.token;
--
-- Rodar depois de quiz-schema.sql e quiz-relatorio.sql. É idempotente.
-- =====================================================================

insert into quiz_sessions (slug, titulo) values
  ('caixa-q2-a04', 'Aula 04 — Retomada: Caixa Preta, Caixa Branca e Cobertura')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'caixa-q2-a04';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('caixa-q2-a04', 1,
   'O Foot Fanatics deveria bloquear a conta após cinco tentativas de login, mas ninguém implementou essa regra. A suíte passa e o relatório aponta 100% de cobertura. Que tipo de teste tem chance de encontrar essa falha, e por quê?',
   '["Caixa branca, porque o relatório de cobertura acusa o ramo de bloqueio que nunca executou",
     "Caixa preta, porque parte da especificação e cobra o comportamento que deveria existir",
     "Caixa branca, porque a leitura do fluxo de controle revela a condição que ficou faltando",
     "Nenhum dos dois: sem código escrito, a falha só aparece em produção, com usuário real"]'::jsonb, 40, 'O que cada caixa enxerga', 'Parte 1 · caixa preta e caixa branca'),

  ('caixa-q2-a04', 2,
   'A linha sob teste é "if (token != null && !token.expirado()) { liberarAcesso(); }". Quantos testes, no mínimo, cada critério exige — comando, ramo e condição, nessa ordem?',
   '["1, 2 e 3: condição exige avaliar cada operando como verdadeiro e como falso",
     "1, 2 e 2: com token nulo e token válido os dois critérios já ficam satisfeitos",
     "2, 2 e 3: comando também precisa do caso que nega o acesso para valer 100%",
     "1, 3 e 3: ramo precisa de nulo, expirado e válido para cobrir a decisão"]'::jsonb, 40, 'Comando, ramo e condição', 'Parte 1 · critérios de cobertura'),

  ('caixa-q2-a04', 3,
   'A sessão vale 30 minutos e aos 1800 s ainda é válida. Alguém troca "idade_s > 1800" por "idade_s >= 1800". A suíte tem os casos 1799, 1800 e 1801. Qual deles fica vermelho, e o que isso demonstra?',
   '["1799, porque é o único valor logo antes da fronteira declarada na regra",
     "1801, porque passa a ser aceito quando a comparação muda de sinal",
     "1800, porque é o valor exatamente na fronteira — é o que a análise de valor limite existe para pegar",
     "Os três, porque qualquer alteração no operador invalida a classe de equivalência inteira"]'::jsonb, 40, 'Análise de valor limite', 'Parte 1 · técnicas de caixa preta'),

  ('caixa-q2-a04', 4,
   'Ao testar o campo de plano da assinatura, a equipe usa "free", "premium" e "pirata" como entradas. Qual é o papel da terceira entrada nessa escolha?',
   '["É a classe de entrada inválida, a mais esquecida e justamente a que o atacante usa",
     "É o valor de fronteira entre as duas classes válidas, no espírito do valor limite",
     "É um caso redundante, mantido apenas para elevar o número de testes da suíte",
     "É a regra don''t care da tabela de decisão, que colapsa duas combinações em uma"]'::jsonb, 40, 'Partição de equivalência', 'Parte 1 · técnicas de caixa preta'),

  ('caixa-q2-a04', 5,
   'A regra de acesso combina três condições: logado, assinante e conteúdo premium. São oito combinações possíveis, mas a tabela de decisão da aula tem quatro regras. O que reduziu o número?',
   '["A partição de equivalência, que escolhe um representante por classe de entrada",
     "O critério de ramo, que exige apenas verdadeiro e falso para cada decisão do código",
     "A análise de valor limite, que descarta as combinações longe de qualquer fronteira",
     "O don''t care: sem sessão, assinatura e tipo de conteúdo não mudam o resultado"]'::jsonb, 40, 'Tabela de decisão', 'Parte 1 · técnicas de caixa preta'),

  ('caixa-q2-a04', 6,
   'Um teste chama pode_assistir, não tem nenhuma asserção, passa sempre e soma 100% de cobertura na linha. Qual experimento da aula demonstra que ele não protege nada?',
   '["Repetir a execução com --cov-branch, que revela o ramo ainda não exercitado",
     "Sabotar a regra de propósito e rodar a suíte: se não ficar vermelha, o teste é decoração",
     "Comparar a cobertura de comando com a de condição e exigir a diferença entre as duas",
     "Elevar a meta de cobertura do projeto até que o teste sem asserção deixe de bastar"]'::jsonb, 40, 'A armadilha dos 100%', 'Parte 1 · cobertura não é proteção'),

  ('caixa-q2-a04', 7,
   'No Foot Fanatics a equipe chama POST /auth/login como um cliente qualquer, mas escolhe os casos sabendo que existe um filtro de sessão com ramo de expiração, e depois confere no banco que a sessão foi invalidada. Como se classifica esse teste?',
   '["Caixa preta pura, já que a chamada é feita pelo contrato público da API",
     "Caixa branca pura, já que os casos foram escolhidos a partir do fluxo interno",
     "Caixa cinza: chamada pelo contrato, casos escolhidos com conhecimento interno",
     "Teste de unidade, porque verifica o filtro de sessão isolado do restante do sistema"]'::jsonb, 40, 'Caixa cinza', 'Parte 1 · caixa cinza'),

  ('caixa-q2-a04', 8,
   'Na elicitação com IA, uma equipe registrou: "RNF-04 — o catálogo deve ser rápido para o assinante". Segundo o critério da aula, o que falta e como corrigir?',
   '["Falta o escopo: basta amarrar o item a E4 Conteúdo e manter a redação atual",
     "Falta identificar a persona de origem; a métrica só é exigida na semana da carga",
     "Nada falta: o item já distingue assinante de visitante e por isso é verificável",
     "Falta métrica: RNF só existe se for medível, como p95 abaixo de 2 s no catálogo"]'::jsonb, 40, 'RF, RNF e requisito medível', 'Parte 2 · elicitação de requisitos')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 1, 'Requisito que ninguém implementou não tem linha para cobrir: a cobertura fica em 100% e a caixa branca não vê nada. Quem parte da especificação — a caixa preta — cobra o comportamento ausente. É o ponto cego clássico de cada uma.'),
    (2, 0, 'Comando: uma execução com token válido já roda a linha. Ramo: falta o caso que nega o acesso, então dois. Condição: token nulo e token expirado são bugs diferentes e precisam ser avaliados isoladamente, então três. Nenhuma ferramenta padrão mede condição de graça.'),
    (3, 2, 'Com >=, a sessão de exatamente 1800 s passa a ser recusada. 1799 e 1801 se comportam igual nas duas versões; só o valor na fronteira denuncia a troca. É por isso que a técnica pede o limite, logo antes e logo depois.'),
    (4, 0, 'Entradas tratadas do mesmo jeito formam uma classe e basta um representante de cada. "pirata" representa a classe inválida — a que mais gente esquece e a primeira que alguém mal-intencionado tenta.'),
    (5, 3, 'Quando não há sessão, o resultado é SESSAO_INVALIDA independentemente de assinatura e de tipo de conteúdo: as demais condições viram don''t care e várias combinações colapsam em uma única regra.'),
    (6, 1, 'Cobertura mede o que foi executado, não o que foi verificado. O teste de mutação na unha é o contraexemplo: apague ou inverta a regra e rode a suíte. Se continuar verde, aquele teste não protegia nada.'),
    (7, 2, 'Caixa cinza é exatamente isso: a chamada é externa, pelo contrato, mas a escolha dos casos e a verificação usam conhecimento do que existe atrás. É o modo em que o Foot Fanatics é testado na maior parte do semestre.'),
    (8, 3, '"Rápido" não é requisito: não há como decidir se foi atendido. RNF só existe se for medível — percentil, tempo, taxa, condição de carga. Amarrar ao escopo é necessário, mas não substitui a métrica.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token do professor. Fixo por decisão do professor: a sala é descartável e
-- o token só abre, revela e reinicia — não há dado pessoal atrás dele.
insert into quiz_host_tokens (session_slug, token)
values ('caixa-q2-a04', '080909')
on conflict (session_slug) do update set token = excluded.token;

select count(*) || ' perguntas carregadas' as resultado
  from quiz_questions where session_slug = 'caixa-q2-a04';
