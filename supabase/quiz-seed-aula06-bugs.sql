-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 06 (Semana 37)
-- Quiz de retomada da Aula 05: "Gestão de Erros e Bugs".
--
-- Oito questões, 90 segundos cada, extraídas do slide e do material da
-- Aula 05 (pages/qualidade2/slide_gestao-erros-bugs.html e
-- .../material/material_gestao-erros-bugs.html).
--
-- As questões são de aplicação: cada uma apresenta uma situação de
-- triagem, diagnóstico ou fechamento e pede a classificação ou a
-- intervenção correspondente. Os distratores reproduzem confusões
-- correntes da turma (severidade × prioridade, sintoma × causa raiz,
-- resolvido × fechado, defeito × melhoria), não alternativas
-- implausíveis. A posição da correta é distribuída entre as quatro
-- letras — duas em cada — e o comprimento das alternativas é
-- equilibrado, para que nem a posição nem a extensão sirvam de atalho.
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
  ('bugs-q2-a06', 'Aula 06 — Retomada: Gestão de Erros e Bugs', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'bugs-q2-a06';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('bugs-q2-a06', 1,
   'A regra de cadastro estava ambígua, alguém programou a comparação de e-mail sem normalizar, duas contas equivalentes foram criadas e um assinante do Foot Fanatics abriu chamado por acesso inconsistente. Na cadeia causal da aula, o que é a comparação sem normalizar?',
   '["A falha, porque é onde o comportamento incorreto aparece durante a execução",
     "O incidente, porque é o evento percebido que obriga a equipe a investigar",
     "O defeito, porque é o problema inserido no código a partir do erro humano",
     "O erro humano, porque foi a decisão equivocada que originou toda a cadeia"]'::jsonb, 90, 'Erro, defeito, falha e incidente', 'seção 1'),

  ('bugs-q2-a06', 2,
   'Um relato chega assim: "Cadastro não funciona. Urgente!". Pela lista mínima de um bom bug report, qual é a carência que impede qualquer avanço da triagem?',
   '["Faltam cenário, oráculo e evidência, então ninguém consegue reproduzir a falha",
     "Falta a severidade, porque sem ela a triagem não classifica o dano causado",
     "Falta o responsável, porque sem dono declarado o registro não muda de estado",
     "Falta a frequência, porque sem ela não se calcula o alcance sobre os usuários"]'::jsonb, 90, 'Bug report reproduzível', 'seção 2'),

  ('bugs-q2-a06', 3,
   'Um erro de grafia aparece na campanha que o Foot Fanatics publica hoje, à vista de todos os visitantes. O contorno é trivial e nada quebra. Como classificar?',
   '["Severidade crítica e prioridade P0, pela exposição pública imediata do problema",
     "Severidade baixa e prioridade alta, porque o dano técnico é pequeno e a janela é hoje",
     "Severidade alta e prioridade P2, porque a imagem do produto é um requisito de negócio",
     "Severidade média e prioridade P3, porque existe contorno disponível para o problema"]'::jsonb, 90, 'Severidade × prioridade', 'seção 4'),

  ('bugs-q2-a06', 4,
   'Na triagem, a equipe conclui que o comportamento relatado é exatamente o que o requisito acordado descreve — o usuário é que esperava outra coisa. Qual é a decisão correta?',
   '["Registrar como defeito de severidade baixa, já que o usuário percebeu o problema",
     "Fechar como não reproduzível, porque o comportamento observado é o esperado",
     "Vincular ao registro canônico como duplicado do requisito que descreve o fluxo",
     "Tratar como melhoria ou decisão de produto, porque nenhum requisito foi violado"]'::jsonb, 90, 'Triagem como decisão explícita', 'seção 5'),

  ('bugs-q2-a06', 5,
   'Quem corrigiu marcou o registro como resolvido, anexou o commit e pediu para fechar no mesmo instante. O que o ciclo de vida auditável exige antes do estado fechado?',
   '["Que outra pessoa verifique o comportamento em um build e confirme a não regressão",
     "Que o registro passe por nova triagem para reconfirmar severidade e prioridade",
     "Que a correção seja aprovada por produto, que é quem define o valor da entrega",
     "Que a causa raiz esteja escrita, ainda que a verificação aconteça no ciclo seguinte"]'::jsonb, 90, 'Ciclo de vida e verificação', 'seção 5'),

  ('bugs-q2-a06', 6,
   'Os cinco porquês do e-mail duplicado terminam em: não havia caso de equivalência na RTM e o domínio não declarava invariantes. Qual conjunto de ações corresponde a tratar a causa, e não o sintoma?',
   '["Corrigir a comparação no controller e reabrir o registro se o problema retornar",
     "Apagar a conta duplicada em produção e avisar o suporte sobre o caso encontrado",
     "Adicionar um alerta que detecte contas equivalentes e notifique a operação de plantão",
     "Criar o tipo-valor que normaliza, exigir restrição única no banco e atualizar a RTM"]'::jsonb, 90, 'Causa raiz e ação sistêmica', 'seção 7'),

  ('bugs-q2-a06', 7,
   'A equipe corrigiu a duplicidade e escreveu um teste que passa. Pelas três provas de uma correção completa, o que ainda falta demonstrar?',
   '["Que a mudança foi a menor possível, comparando o diff com alternativas descartadas",
     "Que o teste falha no commit anterior à correção, e pelo motivo esperado",
     "Que a cobertura do módulo subiu depois que o teste novo entrou na suíte",
     "Que o relato original foi reescrito com os passos definitivos de reprodução"]'::jsonb, 90, 'Correção com prova de regressão', 'seção 8'),

  ('bugs-q2-a06', 8,
   'A coordenação propõe um ranking mensal de bugs abertos por desenvolvedor para estimular qualidade. Qual é a objeção da aula, e o que medir no lugar?',
   '["Nenhuma: o ranking expõe quem precisa de apoio e acelera a melhoria da equipe",
     "A objeção é o custo de coletar o dado; melhor medir apenas o total de bugs abertos",
     "A métrica vira ranking e incentiva ocultar e fragmentar; meça o fluxo de trabalho",
     "A objeção é a amostra pequena; o ranking funciona quando o volume mensal é alto"]'::jsonb, 90, 'Métricas sem caça aos culpados', 'seção 9')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 2, 'A cadeia é erro humano (a compreensão equivocada da regra ambígua) → defeito (o problema inserido no código, aqui a comparação sem normalizar) → falha (as duas contas equivalentes criadas na execução) → incidente (o chamado aberto). Confundir defeito com falha faz a equipe procurar o problema no lugar errado: a falha é sintoma, o defeito é o que se corrige.'),
    (2, 0, 'Sem título observável, passos mínimos, esperado × obtido e evidência, ninguém reproduz — e o que não se reproduz não se triage nem se corrige. Severidade, responsável e frequência são consequências da triagem: só se classifica o que já se consegue observar.'),
    (3, 1, 'Severidade mede o dano técnico ou de negócio; prioridade mede quando tratar, dado o contexto. Erro de grafia causa dano pequeno (severidade baixa), mas a campanha é hoje: a janela de valor fecha, então a prioridade sobe. O par oposto também existe — vazamento raro é severidade crítica e P0.'),
    (4, 3, 'Defeito é violação de requisito ou de comportamento acordado. Sem violação, o registro é melhoria ou decisão de produto, e quem define o valor é produto. Fechar como não reproduzível seria errado: o comportamento foi reproduzido, ele é que está correto.'),
    (5, 0, 'Resolvido não é fechado. Quem corrige fornece a mudança; quem verifica confirma, num build, que o comportamento mudou e que a regressão continua verde. Sem essa separação, o registro fecha com a palavra de quem corrigiu e o defeito volta pela porta dos fundos.'),
    (6, 3, 'Causa raiz aponta invariante ausente no domínio e lacuna na RTM: a ação sistêmica é o tipo-valor que normaliza, a restrição única que impede o estado inválido mesmo por outro caminho e a RTM atualizada com o caso de equivalência. Corrigir só o controller trata o sintoma daquele fluxo e deixa a porta aberta nos demais.'),
    (7, 1, 'As três provas são reproduzir, corrigir e verificar. Um teste que passa depois da correção não prova nada sozinho: ele precisa falhar no commit anterior, e pelo motivo esperado, senão pode estar verde por não exercitar o cenário. Cobertura não substitui essa demonstração.'),
    (8, 2, 'Contar bugs por pessoa transforma a métrica em ranking: incentiva ocultar defeito e fragmentar registros para melhorar o número. Meça o sistema de trabalho — tempo de ciclo, reabertura, escape e recorrência — que descreve o fluxo e aponta onde ele falha, sem apontar culpados.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token público legado. Também autoriza relatórios individuais e publicação.
insert into quiz_host_tokens (session_slug, token)
values ('bugs-q2-a06', '080909')
on conflict (session_slug) do update set token = excluded.token;

-- A última questão vale o dobro.
update quiz_questions set peso = 2
 where session_slug = 'bugs-q2-a06'
   and ordem = (select max(ordem) from quiz_questions where session_slug = 'bugs-q2-a06');

select count(*) || ' perguntas carregadas, a última com peso '
       || max(peso) filter (where ordem = 8) as resultado
  from quiz_questions where session_slug = 'bugs-q2-a06';
