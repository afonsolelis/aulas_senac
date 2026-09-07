-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 08 (Semana 39)
-- Quiz de retomada da Aula 07: "JUnit 5, JaCoCo e SonarCloud".
--
-- Oito questões, 90 segundos cada, extraídas do slide e do material da
-- Aula 07 (pages/qualidade2/slide_junit-jacoco-sonarcloud.html e
-- .../material/material_junit-jacoco-sonarcloud.html).
--
-- As questões são de aplicação: cada uma mostra um teste, uma
-- configuração ou um relatório do Foot Fanatics e pede o diagnóstico ou
-- a intervenção. Os distratores reproduzem confusões correntes
-- (cobertura de linha × de ramo, cobertura como prova de correção,
-- análise estática × teste de regra de negócio, relógio do sistema ×
-- relógio injetado), não alternativas implausíveis. A posição da
-- correta é distribuída entre as quatro letras — duas em cada — e o
-- comprimento das alternativas é equilibrado.
--
-- O token do professor é fixo em '080909' e já vai gravado no fim deste
-- arquivo. Também permite ler relatórios individuais e gabaritos: não
-- oferece confidencialidade. Ver README.md.
--
-- Rodar depois de quiz-schema.sql e quiz-relatorio.sql. É idempotente.
-- =====================================================================

insert into quiz_sessions (slug, titulo, periodo) values
  ('cobertura-q2-a08', 'Aula 08 — Retomada: JUnit, JaCoCo e SonarCloud', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'cobertura-q2-a08';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('cobertura-q2-a08', 1,
   'O teste de expiração de token cria o cenário com Instant.now() e um Thread.sleep(1000). Ele passa quase sempre e falha em dias de fila cheia na CI. Qual é a correção estrutural?',
   '["Aumentar o sleep para três segundos, criando margem para a lentidão do runner",
     "Marcar o teste com assertTimeout, para que o limite fique explícito no próprio caso",
     "Isolar o teste em um job próprio, sem concorrência com o resto da suíte na CI",
     "Injetar um Clock.fixed no validador, tratando o tempo como entrada e não ambiente"]'::jsonb, 90, 'Tempo como dependência', 'seção 1'),

  ('cobertura-q2-a08', 2,
   'O relatório do JaCoCo mostra 100% de cobertura de linha no autorizador, mas o ramo "token expirado" nunca foi verificado. Como isso é possível?',
   '["É um defeito conhecido do JaCoCo ao medir código que usa expressões condicionais",
     "Executar a linha da decisão já a conta como coberta, sem exigir os dois resultados",
     "A cobertura de linha só ignora ramos quando o método tem mais de uma saída possível",
     "O agente não foi preparado no build, então o número exibido não corresponde à execução"]'::jsonb, 90, 'Cobertura de linha × de ramo', 'seção 2'),

  ('cobertura-q2-a08', 3,
   'A regra diz que o token vale enquanto o instante atual for anterior ao de expiração. Pela trinca de limite da aula, quais três entradas o teste parametrizado precisa cobrir?',
   '["Um segundo antes do limite, exatamente no limite e um segundo depois do limite",
     "Um token recém-emitido, um token de ontem e um token com data de expiração nula",
     "Um valor baixo, um valor médio e um valor alto dentro do intervalo de validade",
     "Três instantes sorteados no intervalo, para não viciar o teste em um caso único"]'::jsonb, 90, 'Classes de equivalência e limites', 'seção 3'),

  ('cobertura-q2-a08', 4,
   'O JaCoCo está gerando o relatório HTML, mas o build fica verde mesmo com a cobertura de ramo em 40%. As metas do projeto são 80% de linha e 70% de ramo. O que está faltando?',
   '["Rodar ./mvnw test em vez de verify, porque check só atua na fase de testes",
     "Elevar as metas no SonarCloud, que é quem decide a aprovação do build no PR",
     "Executar o goal check com as regras configuradas, além do goal report, na fase verify",
     "Adicionar o prepare-agent, sem o qual o plugin não consegue medir nada da execução"]'::jsonb, 90, 'JaCoCo como gate do build', 'seção 4'),

  ('cobertura-q2-a08', 5,
   'No relatório HTML do JaCoCo, uma linha da regra de assinatura aparece em amarelo. O que isso significa, e qual é a ação?',
   '["A linha não foi executada; verificar se representa risco ou se é código morto",
     "A decisão foi parcialmente coberta; escrever o caso que exercita o resultado ausente",
     "A linha foi executada sem assert relevante; acrescentar oráculo ao teste existente",
     "A linha está fora do escopo medido; incluir o pacote nas regras do bundle do plugin"]'::jsonb, 90, 'Leitura do relatório', 'seção 5'),

  ('cobertura-q2-a08', 6,
   'O SonarCloud passou sem nenhum problema aberto no módulo de assinatura, mas a regra de negócio calcula o vencimento com um mês de diferença. Como interpretar isso?',
   '["Como falso negativo da análise, que deveria ter apontado o cálculo incorreto",
     "Como sinal de que faltou configurar a regra de negócio no perfil de qualidade",
     "Como esperado: análise estática encontra padrões, não comprova regra de negócio",
     "Como efeito da cobertura baixa, já que o Sonar só analisa o que os testes executam"]'::jsonb, 90, 'SonarCloud e testes são complementares', 'seção 6'),

  ('cobertura-q2-a08', 7,
   'O projeto é legado e tem muita dívida acumulada. Exigir métrica alta sobre toda a base travaria a equipe por semanas. Qual é a estratégia de Quality Gate defendida na aula?',
   '["Aplicar o gate ao código novo, mantendo a base existente sob acompanhamento",
     "Desativar o gate até que um mutirão de correção reduza a dívida acumulada",
     "Reduzir o gate global a um patamar que a base atual já alcance hoje sem esforço",
     "Excluir da análise os pacotes legados, deixando apenas os módulos recém-criados"]'::jsonb, 90, 'Quality Gate no novo código', 'seção 7'),

  ('cobertura-q2-a08', 8,
   'Uma classe de teste tem um @BeforeEach de quarenta linhas que monta assinatura, token, relógio e provedor para todos os casos. Ler um teste isolado não deixa claro qual cenário ele exercita. O que a aula recomenda?',
   '["Trocar por @BeforeAll, para que o custo do setup seja pago uma única vez",
     "Manter o setup e documentar cada caso com um comentário no topo do método",
     "Extrair o setup para uma classe utilitária compartilhada por toda a suíte",
     "Organizar em @Nested com @DisplayName, e cada cenário monta o que de fato usa"]'::jsonb, 90, 'Organizar testes por comportamento', 'seção 8')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 3, 'No Foot Fanatics o tempo decide segurança: se o teste não controla o relógio, não controla o cenário. Injetar Clock.fixed torna o instante um dado de entrada e o resultado determinístico — produção usa o relógio do sistema, o teste usa o relógio controlado. Aumentar o sleep apenas adia a falha e deixa a suíte mais lenta.'),
    (2, 1, 'Cobertura de linha conta linhas alcançadas; basta a decisão ser executada uma vez para a linha ficar verde, ainda que apenas um dos resultados tenha ocorrido. Cobertura de ramo é que exige verdadeiro e falso. Por isso 100% de linha convive com o ramo de token expirado nunca verificado — cobertura responde executou, não testou certo.'),
    (3, 0, 'A trinca de limite é imediatamente antes, exatamente no limite e imediatamente depois — é ali que o erro de comparação aparece, quando alguém troca menor por menor ou igual. Valores sorteados ou espalhados pelo meio do intervalo pertencem à mesma classe de equivalência e não pressionam a fronteira.'),
    (4, 2, 'report gera o relatório; quem falha o build é o goal check, com as regras de 80% de linha e 70% de ramo configuradas no elemento BUNDLE, executado na fase verify. Sem prepare-agent não haveria medição alguma, mas aqui o relatório existe — logo o agente está ativo e o que falta é o check.'),
    (5, 1, 'No relatório do JaCoCo, vermelho é instrução não executada, amarelo é decisão parcialmente coberta e verde é executado. Amarelo significa que falta pelo menos um resultado da decisão: a ação é escrever o caso que exercita o ramo ausente, priorizando autorização, expiração e transições, não pintar DTO de verde.'),
    (6, 2, 'Análise estática encontra padrões propensos a erro, vulnerabilidade e dívida; ela não conhece a regra de vencimento e não pode comprová-la. SonarCloud e testes são lentes complementares: o cálculo errado é responsabilidade do teste de comportamento, com oráculo explícito.'),
    (7, 0, 'O gate no novo código exige qualidade do que entra agora, sem travar a equipe com a dívida herdada, e faz a base melhorar a cada PR. Desativar o gate ou rebaixá-lo ao patamar atual elimina a pressão que produz a melhoria; excluir pacotes da análise apaga a dívida do relatório sem reduzi-la.'),
    (8, 3, 'Lifecycle não é depósito de dados invisíveis: setup grande e compartilhado esconde o motivo do cenário e acopla casos que deveriam ser independentes. @Nested com @DisplayName dá contexto pelo nome da classe e revela a regra pelo nome do método, com cada cenário montando o que de fato usa. @BeforeAll agrava o problema, porque compartilha estado entre os casos.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token público legado. Também autoriza relatórios individuais e publicação.
insert into quiz_host_tokens (session_slug, token)
values ('cobertura-q2-a08', '080909')
on conflict (session_slug) do update set token = excluded.token;

select count(*) || ' perguntas carregadas' as resultado
  from quiz_questions where session_slug = 'cobertura-q2-a08';
