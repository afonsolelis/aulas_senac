-- =====================================================================
-- TBL — Qualidade de Software 2026.2 · Aula 07 (Semana 38)
-- Caso: Foot Fanatics às vésperas do plano anual
--
-- Um caso único percorrido por cinco questões, uma para cada bloco do
-- semestre até aqui:
--   1. Requisito de qualidade verificável   (Aulas 01 e 02: ISO 25010, ATAM, cenário)
--   2. Projeto de teste e cobertura          (Aulas 03 e 07: caixas, limite, JaCoCo)
--   3. Arquitetura e táticas                 (Aulas 04 e 06: job diário, ATAM, Len Bass)
--   4. Gestão de defeitos                    (Aula 05: severidade, triagem, causa raiz)
--   5. Integração contínua e Quality Gate    (Aulas 06 e 07: CI, SonarCloud)
-- Cada questão apresenta quatro táticas com ganho e custo declarados, e
-- nenhuma é correta.
--
-- A segunda questão traz um dado novo, liberado só quando a discussão é
-- aberta: o resultado da análise de mutação mostra que a cobertura alta
-- não protegia a regra, o que desloca o critério sem mudar as alternativas.
--
-- O token do professor é o mesmo dos quizzes ('080909'). Como o
-- repositório é público, ele não é segredo (ver CLAUDE.md).
--
-- Idempotente e restrito à sala 'ff-q2-a07-tbl': só insert/update em
-- tabelas hubtbl_ e o delete de questões excedentes desta mesma sala.
-- =====================================================================

begin;

insert into hubtbl_sessions (slug, titulo)
values ('ff-q2-a07-tbl', 'TBL — Foot Fanatics às vésperas do plano anual')
on conflict (slug) do update set titulo = excluded.titulo;

insert into hubtbl_host_tokens (session_slug, token)
values ('ff-q2-a07-tbl', '080909')
on conflict (session_slug) do update set token = excluded.token;

-- ---------------------------------------------------------------------
-- O contexto comum das cinco questões
-- ---------------------------------------------------------------------
insert into hubtbl_casos (session_slug, caso_titulo, caso_texto, contexto)
values (
  'ff-q2-a07-tbl',
  'O acesso premium que abriu para quem não pagou',
  'A Foot Fanatics é uma API de conteúdo esportivo com assinatura: clubes, jogos, resultados e matérias, com uma parte pública e outra exclusiva de quem assina. A plataforma atende três perfis — o **torcedor casual, no plano free**, o **torcedor assinante, no plano premium**, e o **editor de conteúdo**, que publica as matérias — e está organizada em quatro escopos: identidade e conta (E1), sessão e acesso (E2), assinatura (E3) e conteúdo (E4). Hoje são **380 mil contas, das quais 41 mil pagam o premium**.

A empresa fechou parceria com uma liga para transmitir os bastidores da fase final do campeonato e vai lançar um **plano anual em três semanas**. A campanha paga já está contratada e a data foi comunicada ao parceiro, que exige uma **homologação da API na sexta-feira da semana que vem**. A diretoria comercial considera que **a data não se move**, e a operação editorial pede que nenhuma mudança trave a publicação de matérias durante os jogos.

O último mês acumulou três problemas. Em três ocasiões, **conteúdo premium foi liberado para contas free**, somando **214 acessos indevidos**; a investigação encontrou um token aceito exatamente no instante da expiração, numa classe com **94% de cobertura de linhas**. Numa madrugada, o **job diário de vencimentos falhou no meio do lote e avançou o marcador de processamento**: **1.240 assinaturas vencidas mantiveram acesso premium por três dias**, e ninguém foi alertado. E o repositório tem **37 issues abertas sem triagem**, com **taxa de reabertura de 31%**.

A engenharia avançou no semestre. O PRD traz as personas e os escopos, mas descreve a qualidade em frases como "a sessão deve ser segura e o acesso premium, rápido". A suíte passou do vermelho ao verde pelo TDD, o **CI no GitHub Actions roda ./mvnw verify** em todo pull request, e o **JaCoCo passa com 86% de linhas e 73% de branches** contra a meta de 80/70. Nesta semana entrou o SonarCloud, e o **Quality Gate do pull request da release está vermelho**. Um teste de E2 que usa Thread.sleep **falha em uma de cada seis execuções**. O ciclo 01 do ATAM registrou como tema de risco que **nenhuma etapa do job diário tem alerta**.

A área jurídica lembra que o assinante premium que perde acesso ao que pagou reclama com base no Código de Defesa do Consumidor, e que logs com token ou e-mail exigem cuidado perante a LGPD. A equipe tem **cinco pessoas e três semanas**, sem contratação prevista. Cada problema admite mais de uma resposta de qualidade, e **cada resposta cobra um custo diferente do torcedor, da equipe ou do negócio**. **As decisões serão tomadas nesta aula.**',
  '[
    {"rotulo":"Base de contas","valor":"380 mil contas","nota":"41 mil assinantes premium"},
    {"rotulo":"Acesso indevido","valor":"214 acessos","nota":"premium liberado a contas free em 3 ocasiões"},
    {"rotulo":"Job de vencimentos","valor":"1.240 assinaturas","nota":"acesso premium vencido por três dias, sem alerta"},
    {"rotulo":"Gate local","valor":"JaCoCo 86% / 73%","nota":"meta 80/70 · verde"},
    {"rotulo":"SonarCloud","valor":"Quality Gate vermelho","nota":"pull request da release"},
    {"rotulo":"Prazo","valor":"três semanas","nota":"cinco pessoas · homologação na próxima sexta"}
  ]'::jsonb
)
on conflict (session_slug) do update set
  caso_titulo = excluded.caso_titulo,
  caso_texto  = excluded.caso_texto,
  contexto    = excluded.contexto;

-- ---------------------------------------------------------------------
-- Questão 1 — Requisito de qualidade verificável (Aulas 01 e 02)
-- ---------------------------------------------------------------------
insert into hubtbl_questoes (session_slug, ordem, categoria, titulo, pergunta, alternativas)
values (
  'ff-q2-a07-tbl', 1,
  'Requisito de qualidade verificável',
  'A frase que nenhum teste consegue reprovar',
  'O PRD diz que "a sessão deve ser segura e o acesso premium, rápido". Nenhum teste consegue reprovar essa frase, e foi com ela que o token expirado passou. Faltam três semanas. Como a equipe transforma a qualidade esperada em critério verificável?',
  '[
    {
      "letra":"A","titulo":"Cenários de seis partes priorizados","tatica":"Utility tree antes de tudo",
      "texto":"A equipe escreve cenários com fonte, estímulo, ambiente, artefato, resposta e medida, organiza-os numa utility tree com (importância, dificuldade) e começa pelos (Alta, Alta) de E2 e E3.",
      "ganho":"Cada cenário vira caso de teste com medida explícita, e a prioridade mostra onde gastar as três semanas.",
      "custo":"Exige reunião com produto e jurídico para acordar as medidas. Cenários de prioridade baixa ficam sem critério até o próximo ciclo."
    },
    {
      "letra":"B","titulo":"Tabela de decisão do acesso","tatica":"Enumerar as combinações",
      "texto":"A regra de acesso é descrita como tabela: logado × plano × vigência da assinatura × estado do token × tipo de conteúdo, com a decisão e o motivo em cada linha e um teste por linha.",
      "ganho":"A precedência entre as condições fica explícita e as lacunas aparecem antes da implementação. Cada linha vira um teste automatizado.",
      "custo":"Cobre bem a segurança de E2 e E3, mas não diz nada sobre desempenho nem disponibilidade. A tabela cresce de forma combinatória."
    },
    {
      "letra":"C","titulo":"Checklist da ISO/IEC 25010","tatica":"Vocabulário comum para todos os escopos",
      "texto":"Cada história passa a ter critério de aceite para as nove características da norma, com as subcaracterísticas relevantes marcadas pelo time na revisão.",
      "ganho":"Nenhum atributo é esquecido, e produto, QA e desenvolvimento passam a usar os mesmos nomes para as reclamações.",
      "custo":"O checklist diz o que observar, não quanto é suficiente: sem medida, o critério continua subjetivo. O preenchimento em todas as histórias vira burocracia."
    },
    {
      "letra":"D","titulo":"Critério nascido do incidente","tatica":"Crescimento de confiabilidade",
      "texto":"A equipe não reescreve o PRD agora. Cada falha real, a começar pelos 214 acessos indevidos, vira um caso de regressão com a medida observada, e o critério cresce a partir do que quebrou.",
      "ganho":"Custo imediato baixo e foco no que comprovadamente acontece em produção. Cada correção deixa um teste que impede a volta daquela falha.",
      "custo":"É reativo: o critério só existe depois que o torcedor foi afetado. O plano anual chega com o risco ainda não observado sem nenhum critério."
    }
  ]'::jsonb
)
on conflict (session_slug, ordem) do update set
  categoria = excluded.categoria, titulo = excluded.titulo,
  pergunta = excluded.pergunta, alternativas = excluded.alternativas,
  dado_novo = excluded.dado_novo;

-- ---------------------------------------------------------------------
-- Questão 2 — Projeto de teste e cobertura (Aulas 03 e 07)
-- O dado novo é liberado quando a discussão é aberta: a análise de
-- mutação mostra que a cobertura alta executava a regra sem verificá-la.
-- ---------------------------------------------------------------------
insert into hubtbl_questoes (session_slug, ordem, categoria, titulo, pergunta, alternativas, dado_novo)
values (
  'ff-q2-a07-tbl', 2,
  'Projeto de teste e cobertura',
  'O defeito que passou por uma linha coberta',
  'O token era aceito exatamente no instante da expiração, e a classe AutorizadorSessao tinha 94% de cobertura de linhas. A equipe tem uma semana para E2. Qual técnica ela adota como resposta primária para que essa classe de defeito não volte?',
  '[
    {
      "letra":"A","titulo":"Valor limite em trinca","tatica":"Caixa preta na fronteira",
      "texto":"Todo limite de tempo de E2 e E3 ganha um @ParameterizedTest com −1, 0 e +1 segundo em torno da expiração, com o instante controlado por Clock.fixed.",
      "ganho":"Ataca exatamente o erro de < versus <= que causou o incidente, com testes baratos, rápidos e determinísticos.",
      "custo":"Só protege as fronteiras que alguém lembrou de listar. Não revela teste sem asserção nem erro de precedência entre condições."
    },
    {
      "letra":"B","titulo":"Meta de branch por classe crítica","tatica":"Endurecer o JaCoCo onde dói",
      "texto":"Os pacotes de E2 e E3 recebem regra própria no JaCoCo, com 95% de linhas e 90% de branches, e o verify falha abaixo disso.",
      "ganho":"Força a execução dos dois lados de cada decisão nas classes que liberam acesso, e o controle já roda no CI sem ferramenta nova.",
      "custo":"Cobertura mede o que foi executado, não o que foi verificado. A meta alta incentiva teste sem asserção só para subir o número."
    },
    {
      "letra":"C","titulo":"Teste de mutação no gate","tatica":"Provar que o teste protege",
      "texto":"A equipe adota o PIT nos pacotes de E2 e E3: mutantes que alteram operadores e condições precisam ser mortos pela suíte, com pontuação mínima exigida no pull request.",
      "ganho":"Mede se a suíte percebe a regra quebrada, o que expõe testes sem asserção e fronteiras não verificadas.",
      "custo":"Aumenta o tempo do pipeline e exige analisar mutantes equivalentes. É ferramenta nova para aprender a uma semana da homologação."
    },
    {
      "letra":"D","titulo":"Tabela de decisão com motivo","tatica":"Verificar a precedência",
      "texto":"Os testes de E2 seguem a tabela token ausente, inválido, expirado, revogado e válido, e cada caso afirma a decisão e o motivo estável com assertAll.",
      "ganho":"Verifica a precedência entre as regras, por exemplo expirado antes de assinatura ativa, e deixa o oráculo explícito em cada teste.",
      "custo":"Não garante o limite exato do tempo se a linha da tabela usar um instante qualquer. A tabela precisa ser mantida a cada regra nova."
    }
  ]'::jsonb,
  '{
    "titulo":"O resultado da análise de mutação em E2",
    "texto":"Depois do incidente, uma pessoa da equipe rodou o PIT só no pacote de sessão e acesso, sem mudar nenhum teste. A cobertura do JaCoCo continuou a mesma; o que mudou foi a leitura sobre o que a suíte realmente protege. As quatro alternativas e o prazo de uma semana continuam os mesmos.",
    "evidencias":[
      "O pacote de E2 tem 94% de cobertura de linhas e 88% de branches.",
      "Dos 40 mutantes gerados, 23 sobreviveram: a suíte continuou verde com a regra alterada.",
      "O mutante que troca isAfter por !isBefore, o mesmo defeito do incidente, sobreviveu, embora a linha seja executada por 9 testes.",
      "17 dos 23 sobreviventes estão em testes que verificam só permitido() e nunca o motivo da negação.",
      "Nenhum teste de E2 usa um instante igual ao da expiração; 6 testes chamam Instant.now() e Thread.sleep().",
      "O PIT leva 4 minutos no pacote de E2 e 38 minutos na suíte inteira."
    ],
    "pergunta":"Diante da análise de mutação, qual técnica permanece como resposta primária? Declare se a sua escolha anterior sobrevive a este dado e por quê."
  }'::jsonb
)
on conflict (session_slug, ordem) do update set
  categoria = excluded.categoria, titulo = excluded.titulo,
  pergunta = excluded.pergunta, alternativas = excluded.alternativas,
  dado_novo = excluded.dado_novo;

-- ---------------------------------------------------------------------
-- Questão 3 — Arquitetura e táticas (Aulas 04 e 06)
-- ---------------------------------------------------------------------
insert into hubtbl_questoes (session_slug, ordem, categoria, titulo, pergunta, alternativas)
values (
  'ff-q2-a07-tbl', 3,
  'Arquitetura e táticas',
  'O job que avançou o marcador antes de terminar',
  'O job diário de vencimentos falhou no meio do lote, o marcador de processamento já tinha avançado e 1.240 assinaturas vencidas mantiveram acesso premium por três dias, sem alerta. O ciclo 01 do ATAM classificou isso como risco. Que tática arquitetural a equipe adota como resposta primária?',
  '[
    {
      "letra":"A","titulo":"Checkpoint atômico e idempotência","tatica":"Recuperar sem perder nem duplicar",
      "texto":"O marcador só avança na mesma transação que conclui o lote, e reprocessar um intervalo já processado não repete efeito. Um lock impede duas execuções simultâneas.",
      "ganho":"A falha no meio deixa o marcador no lugar certo e a próxima execução retoma sem perder nem duplicar vencimentos.",
      "custo":"Não reduz a janela: entre a falha e a próxima execução, o acesso indevido continua. Sem alerta, a falha ainda pode passar despercebida."
    },
    {
      "letra":"B","titulo":"Vigência conferida a cada acesso","tatica":"Tirar a decisão do job",
      "texto":"A autorização de conteúdo premium consulta a data de vigência da assinatura em toda requisição. O job passa a ser só manutenção de dados, e a decisão de acesso deixa de depender dele.",
      "ganho":"Uma assinatura vencida perde o acesso no instante certo, mesmo que o job falhe por dias.",
      "custo":"Aumenta a carga no banco e a latência justamente nos picos de jogo. É um ponto de trade-off entre segurança e desempenho que exige cache e medição."
    },
    {
      "letra":"C","titulo":"Observabilidade do job","tatica":"Detectar em minutos, não em dias",
      "texto":"Cada execução registra início, fim, lote processado e posição do marcador, com métrica de atraso e alerta para a equipe quando o job não termina na janela.",
      "ganho":"Ataca o tema de risco do ATAM e transforma três dias de exposição em minutos, com evidência para investigar a causa.",
      "custo":"Detectar não é corrigir: alguém precisa estar de plantão para agir de madrugada. Alerta mal calibrado vira ruído ignorado."
    },
    {
      "letra":"D","titulo":"Token de vida curta","tatica":"Limitar a exposição",
      "texto":"O token de acesso passa a valer 15 minutos, e a renovação reconsulta plano e vigência. Um acesso indevido dura no máximo um ciclo de renovação.",
      "ganho":"Limita a janela de exposição de qualquer falha de vigência ou revogação, sem depender do job nem de consulta a cada requisição.",
      "custo":"Aumenta as chamadas de renovação e o risco de o torcedor ser deslogado no meio do jogo. Mexe em E2, que acabou de ter incidente."
    }
  ]'::jsonb
)
on conflict (session_slug, ordem) do update set
  categoria = excluded.categoria, titulo = excluded.titulo,
  pergunta = excluded.pergunta, alternativas = excluded.alternativas,
  dado_novo = excluded.dado_novo;

-- ---------------------------------------------------------------------
-- Questão 4 — Gestão de defeitos (Aula 05)
-- ---------------------------------------------------------------------
insert into hubtbl_questoes (session_slug, ordem, categoria, titulo, pergunta, alternativas)
values (
  'ff-q2-a07-tbl', 4,
  'Gestão de defeitos',
  'Trinta e sete issues e ninguém sabe qual vem primeiro',
  'São 37 issues abertas sem triagem. Quem abriu marcou 9 como críticas, 31% das correções foram reabertas e três relatos diferentes descrevem o mesmo problema de e-mail duplicado no cadastro. Com cinco pessoas e três semanas, como a equipe trata os defeitos?',
  '[
    {
      "letra":"A","titulo":"Triagem com severidade e prioridade separadas","tatica":"Decidir antes de corrigir",
      "texto":"Produto, QA e desenvolvimento fazem triagem diária: confirmam o fato, juntam duplicados, justificam a severidade pelo dano e decidem a prioridade pelo custo do atraso até o lançamento.",
      "ganho":"As 9 críticas deixam de ser opinião de quem abriu, os duplicados somem e a equipe corrige primeiro o que ameaça o plano anual.",
      "custo":"Consome tempo de três áreas todos os dias, e a triagem sozinha não baixa a taxa de reabertura."
    },
    {
      "letra":"B","titulo":"Nenhuma correção sem teste de regressão","tatica":"Fluxo de correção seguro",
      "texto":"Todo pull request de correção precisa trazer um teste que falha no commit com defeito e passa com a correção, vinculado à issue e à matriz de rastreabilidade.",
      "ganho":"Ataca os 31% de reabertura: a correção passa a ter prova, e aquele defeito não volta sem o CI avisar.",
      "custo":"Cada correção fica mais lenta, e defeitos difíceis de reproduzir travam na fila. Não decide o que corrigir primeiro."
    },
    {
      "letra":"C","titulo":"Causa raiz da recorrência","tatica":"Cinco porquês e ações em camadas",
      "texto":"A equipe para as correções pontuais do cadastro, faz os cinco porquês do e-mail duplicado e corrige em camadas: tipo-valor Email, restrição única no banco, testes e checklist de revisão.",
      "ganho":"Elimina a condição que gera vários relatos de uma vez e ensina algo ao processo, não só ao código.",
      "custo":"Concentra esforço em E1 enquanto E2 e E3 têm incidentes de acesso. O resto do backlog continua sem triagem."
    },
    {
      "letra":"D","titulo":"Risco aceito e registrado","tatica":"Cortar escopo com responsabilidade",
      "texto":"Tudo que não afeta E2 e E3 é classificado como não será corrigido antes do lançamento, com o risco aceito, quem decidiu e a data de revisão registrados na issue.",
      "ganho":"Libera a equipe para os incidentes de acesso e torna a decisão de adiar explícita e auditável, em vez de silenciosa.",
      "custo":"Defeitos de baixa severidade chegam ao plano anual, e o backlog cresce depois do lançamento. Exige que alguém do negócio assine o risco."
    }
  ]'::jsonb
)
on conflict (session_slug, ordem) do update set
  categoria = excluded.categoria, titulo = excluded.titulo,
  pergunta = excluded.pergunta, alternativas = excluded.alternativas,
  dado_novo = excluded.dado_novo;

-- ---------------------------------------------------------------------
-- Questão 5 — Integração contínua e Quality Gate (Aulas 06 e 07)
-- ---------------------------------------------------------------------
insert into hubtbl_questoes (session_slug, ordem, categoria, titulo, pergunta, alternativas)
values (
  'ff-q2-a07-tbl', 5,
  'Integração contínua e Quality Gate',
  'O gate vermelho na semana da homologação',
  'O pull request da release está com o Quality Gate do SonarCloud vermelho: o novo código tem 64% de cobertura, contra a meta de 80%, e há dois security hotspots sem revisão. O teste de E2 com Thread.sleep falha em uma de cada seis execuções, e a homologação com o parceiro é na próxima sexta. O que a equipe faz com o gate?',
  '[
    {
      "letra":"A","titulo":"Gate mantido e bloqueante","tatica":"Corrigir antes de integrar",
      "texto":"Nada entra na main com o gate vermelho. A equipe revisa os hotspots, cobre as regras de risco do novo código e troca o Thread.sleep por Clock injetável antes do merge.",
      "ganho":"O gate continua confiável e a release chega à homologação com evidência de qualidade, sem precedente de exceção.",
      "custo":"Pode atrasar a homologação com o parceiro. Toda a equipe para outras frentes para destravar um único pull request."
    },
    {
      "letra":"B","titulo":"Gate diferenciado para o novo código","tatica":"Rigor onde o risco está",
      "texto":"A meta de 80% vale integralmente para E2 e E3. Nos demais pacotes do novo código, cada issue é corrigida, aceita com justificativa ou marcada como falso positivo com evidência, e o critério fica registrado.",
      "ganho":"Concentra o esforço nas regras que liberam acesso e mantém o gate honesto, com decisão explícita em cada issue.",
      "custo":"Mexer nas condições do gate na semana da release parece baixar a régua. Exige disciplina para não usar a justificativa só para ficar verde."
    },
    {
      "letra":"C","titulo":"Quarentena do teste instável","tatica":"Isolar a intermitência",
      "texto":"O teste com Thread.sleep sai do job obrigatório para um job separado e não bloqueante, com issue aberta, responsável e prazo de uma semana para voltar corrigido.",
      "ganho":"O CI volta a ser confiável: vermelho passa a significar defeito, e não sorte. A equipe para de rodar o pipeline de novo até passar.",
      "custo":"Por uma semana, o limite de sessão de E2, que já causou incidente, fica sem proteção obrigatória no merge."
    },
    {
      "letra":"D","titulo":"Exceção auditável","tatica":"Merge administrativo registrado",
      "texto":"O responsável técnico aprova o merge com o gate vermelho, registra a decisão num ADR com os riscos aceitos e abre issues com prazo de uma sprint para zerar a dívida.",
      "ganho":"Garante a data com o parceiro, e a exceção fica visível, justificada e rastreável, em vez de escondida.",
      "custo":"Cria precedente: na próxima pressão, o gate vira sugestão. A release chega à homologação sem a evidência de qualidade que o gate existe para dar."
    }
  ]'::jsonb
)
on conflict (session_slug, ordem) do update set
  categoria = excluded.categoria, titulo = excluded.titulo,
  pergunta = excluded.pergunta, alternativas = excluded.alternativas,
  dado_novo = excluded.dado_novo;

-- Remove questões de uma carga anterior que excedam a sequência atual,
-- sempre restrito a esta sala.
delete from hubtbl_questoes where session_slug = 'ff-q2-a07-tbl' and ordem > 5;

commit;
