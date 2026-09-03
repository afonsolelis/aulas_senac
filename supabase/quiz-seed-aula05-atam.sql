-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 05 (Semana 36)
-- Quiz de retomada da Aula 04: "Arquitetura e ATAM com IA Agêntica".
--
-- Oito questões, 40 segundos cada, extraídas do slide e do material da
-- Aula 04 (pages/qualidade2/slide_introducao-testes-automatizados.html e
-- .../material/material_introducao-testes-automatizados.html).
--
-- As questões são de aplicação: cada uma apresenta uma situação e pede a
-- classificação, o diagnóstico ou a intervenção correspondente. Os
-- distratores reproduzem confusões correntes (idempotência × lock,
-- sensibilidade × trade-off, suposição × requisito), não alternativas
-- implausíveis. A posição da resposta correta é distribuída entre as
-- quatro letras e o comprimento das alternativas é equilibrado, para que
-- nem a posição nem a extensão sirvam de atalho a quem não acompanhou.
--
-- O token do professor é fixo em '080909' e já vai gravado no fim deste
-- arquivo — decisão do professor: a sala é descartável e o token só abre,
-- revela e reinicia.
--
--   insert into quiz_host_tokens (session_slug, token)
--   values ('atam-q2-a05', 'COLE-O-TOKEN-AQUI')
--   on conflict (session_slug) do update set token = excluded.token;
--
-- Para gerar um token novo:  python3 -c "import secrets;print(secrets.token_urlsafe(9))"
--
-- Rodar depois de quiz-schema.sql e quiz-relatorio.sql. É idempotente.
-- =====================================================================

-- O período compõe a data_tag do histórico (quiz-ingestao.sql): o
-- on conflict não o sobrescreve, para não desfazer um ajuste manual.
insert into quiz_sessions (slug, titulo, periodo) values
  ('atam-q2-a05', 'Aula 05 — Retomada: Arquitetura e ATAM', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'atam-q2-a05';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('atam-q2-a05', 1,
   'Um agente propõe um cache em memória alegando que "sistemas desse tipo costumam exigir resposta abaixo de 200 ms". Nenhum artefato do repositório declara essa meta. Como isso deve ser registrado, segundo a disciplina de decisão da aula?',
   '["Como fato, porque o número corresponde a uma prática consolidada em sistemas dessa natureza",
     "Como requisito não funcional novo, incorporado à lista de requisitos com o próximo identificador",
     "Como suposição explícita e validável, com a decisão marcada como sem requisito correspondente",
     "Como lacuna, suspendendo a proposta de cache até que alguém da equipe confirme a meta de tempo"]'::jsonb, 40, 'Fato, lacuna, suposição e decisão', 'seção 1'),

  ('atam-q2-a05', 2,
   'A equipe precisa mostrar, dentro do contêiner de treinamento, quem agenda o job, quem seleciona os dados novos, quem treina, quem valida e quem promove o modelo. Qual nível do C4 responde a essa pergunta?',
   '["Componentes, que distribui as responsabilidades internas do contêiner em foco",
     "Contêineres, que mostra as aplicações e os armazenamentos e onde cada um executa",
     "Contexto, que situa o sistema entre as pessoas e os sistemas vizinhos que o cercam",
     "Código, que apresenta os tipos e os contratos das classes que implementam o fluxo"]'::jsonb, 40, 'Visões C4', 'seção 2'),

  ('atam-q2-a05', 3,
   'O pipeline diário grava o novo watermark assim que começa a treinar, para não reprocessar registros. O treino falha no meio e a execução seguinte parte do watermark já avançado. Qual invariante da aula foi violada?',
   '["O batch não pode indisponibilizar o fluxo online durante a janela de treinamento",
     "O candidato não pode ser promovido sem passar pelos gates de comparação com o vigente",
     "A execução precisa ser reprodutível, registrando dados, parâmetros e versão utilizados",
     "O checkpoint só avança depois do sucesso, sob pena de perder os dados do intervalo"]'::jsonb, 40, 'Isolamento entre online e batch', 'seção 2'),

  ('atam-q2-a05', 4,
   'Uma instabilidade no agendador dispara o job das 23h duas vezes, com segundos de diferença, e as duas execuções passam a treinar ao mesmo tempo sobre o mesmo intervalo. Qual controle do checklist evita especificamente esse cenário?',
   '["Retry, que diferencia falha transitória de falha permanente antes de tentar de novo",
     "Lock, que impede que duas execuções do mesmo job avancem simultaneamente",
     "Idempotência, que garante que reexecutar o processo não duplique os efeitos",
     "Gates, que comparam o candidato com o baseline antes de qualquer promoção"]'::jsonb, 40, 'Idempotência, lock e recuperação', 'seção 3'),

  ('atam-q2-a05', 5,
   'Um cenário foi escrito assim: "quando o banco degrada durante o pico da noite, o serviço de consulta de conteúdo continua respondendo às requisições dos assinantes". Segundo as seis partes do cenário ATAM, o que falta?',
   '["O estímulo, porque não se sabe o que acontece para provocar a reação do sistema",
     "O ambiente, porque a condição de operação em que tudo ocorre não foi declarada",
     "A métrica de resposta, porque não há como saber se a reação foi suficiente",
     "O artefato, porque a parte do sistema afetada pelo estímulo não foi identificada"]'::jsonb, 40, 'Cenário de atributo de qualidade', 'seção 4'),

  ('atam-q2-a05', 6,
   'Na utility tree, quatro cenários receberam os pares (importância, dificuldade): (alta, alta), (alta, baixa), (baixa, alta) e (baixa, baixa). Por onde a análise começa, e por quê?',
   '["Pelo (alta, alta), que reúne valor para o negócio e incerteza técnica ao mesmo tempo",
     "Pelo (alta, baixa), que entrega resultado rápido e libera a equipe para os demais",
     "Pelo (baixa, alta), que é onde o desconhecimento técnico da equipe é maior",
     "Pela ordem dos atributos na árvore, para não enviesar a priorização dos cenários"]'::jsonb, 40, 'Utility tree e priorização', 'seção 4'),

  ('atam-q2-a05', 7,
   'Aumentar o número de réplicas do modelo ativo melhora a disponibilidade e, ao mesmo tempo, eleva o custo mensal e o tempo de publicação de uma versão nova. Como essa decisão é registrada na análise?',
   '["Como risco, porque existem atributos de qualidade prejudicados pela decisão tomada",
     "Como ponto de trade-off, porque a mesma decisão melhora um atributo e piora outros",
     "Como ponto de sensibilidade, porque a disponibilidade depende fortemente dessa decisão",
     "Como tema de risco, porque o mesmo padrão se repete em outras decisões da arquitetura"]'::jsonb, 40, 'Vocabulário das descobertas', 'seção 4'),

  ('atam-q2-a05', 8,
   'Na revisão cruzada, os agentes divergem sobre reter os dados brutos por 90 dias. O agente de dados encerra o assunto "decidindo" pela retenção e segue para o próximo item. O que a governança da aula determina?',
   '["Que o agente de segurança decida, por ser o papel responsável pelo tema em discussão",
     "Que a divergência saia do documento, preservando apenas a decisão final consolidada",
     "Que a decisão do agente valha enquanto ninguém a contestar, virando regra de retenção",
     "Que a divergência fique registrada e que pessoas arbitrem e aceitem o risco residual"]'::jsonb, 40, 'Governança da IA agêntica', 'seção 5')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 2, 'Fato é o que está declarado e pode ser citado — a meta não está em lugar nenhum. A hipótese entra como suposição explícita e validável, e a decisão que se apoia nela é marcada como "decisão sem requisito correspondente". A IA pode analisar e propor; não pode transformar suposição em fato nem criar requisito.'),
    (2, 0, 'Contexto responde qual problema e para quem; contêineres, onde executa e onde os dados persistem; componentes, quem faz o quê dentro do contêiner em foco. Código fica para depois: demonstra tipos e contratos sem antecipar implementação.'),
    (3, 3, 'O checkpoint precisa avançar de forma atômica e só após o sucesso. Avançado antes, os registros do intervalo ficam para trás em silêncio: a próxima execução não os enxerga como novos. As demais invariantes existem, mas nenhuma foi tocada aqui.'),
    (4, 1, 'Idempotência protege a reexecução — rodar de novo não duplica efeitos. O que impede duas execuções ao mesmo tempo é o lock. As duas são necessárias, mas respondem a perguntas diferentes: concorrência e repetição.'),
    (5, 2, 'Fonte e estímulo (o banco degrada), ambiente (pico da noite), artefato (serviço de consulta) e resposta (continua respondendo) estão presentes. Falta a métrica: "continuar respondendo" sem número não é verificável, e um cenário sem métrica não pressiona a arquitetura.'),
    (6, 0, 'A utility tree prioriza por importância e dificuldade. Alta importância com alta dificuldade concentra o que mais vale e o que menos se sabe — é onde a análise rende mais cedo. O par (alta, baixa) tende a já estar resolvido pela própria arquitetura.'),
    (7, 1, 'Ponto de sensibilidade é a decisão que afeta fortemente um atributo. Quando a mesma decisão melhora um e piora outro, é ponto de trade-off. Risco é o que pode impedir um cenário; tema de risco é o padrão que se repete entre várias descobertas.'),
    (8, 3, 'Agentes especializados propõem e se confrontam, mas não têm autoridade para inventar requisito nem para aceitar risco. Divergência não resolvida fica registrada com o motivo; pessoas arbitram, aceitam o risco residual e respondem por ele.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token do professor. Fixo por decisão do professor: a sala é descartável e
-- o token só abre, revela e reinicia — não há dado pessoal atrás dele.
insert into quiz_host_tokens (session_slug, token)
values ('atam-q2-a05', '080909')
on conflict (session_slug) do update set token = excluded.token;

select count(*) || ' perguntas carregadas' as resultado
  from quiz_questions where session_slug = 'atam-q2-a05';
