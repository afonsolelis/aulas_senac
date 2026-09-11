-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 02 (Semana 33)
-- Quiz de retomada da Aula 01: "Introdução à Qualidade de Software".
--
-- Oito questões, 90 segundos cada, extraídas do slide e do material da
-- Aula 01 (pages/qualidade2/slide_introducao-qualidade.html e
-- .../material/material_introducao-qualidade.html).
--
-- As questões partem de incidentes e decisões do trabalho de qualidade.
-- Os distratores reproduzem confusões tratadas na aula: QA × QC × teste,
-- verificação × validação, métrica × meta e prevenção × correção tardia.
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
  ('qualidade-q2-a02', 'Aula 02 — Retomada: Introdução à Qualidade de Software', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'qualidade-q2-a02';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('qualidade-q2-a02', 1,
   'Uma equipe adiciona revisão obrigatória de código e uma Definition of Done antes de iniciar a próxima entrega. Em qual camada de qualidade essa intervenção atua primeiro?',
   '["QA, porque muda o processo usado para prevenir defeitos", "QC, porque inspeciona somente o produto já concluído", "Teste, porque executa o sistema com dados controlados", "Validação, porque confirma diretamente o valor com o usuário"]'::jsonb, 90, 'QA × QC × teste', 'seção 3'),

  ('qualidade-q2-a02', 2,
   'O sistema implementa exatamente o requisito aprovado, mas usuários não conseguem concluir a compra no celular. Qual diagnóstico separa as duas evidências?',
   '["Falhou na verificação e passou na validação, pois o código seguiu o documento", "Passou na verificação e falhou na validação, pois não resolveu o uso real", "Falhou em QA e passou em QC, pois o requisito estava formalmente aprovado", "Passou em teste e falhou em segurança, pois a compra ocorreu no celular"]'::jsonb, 90, 'Verificação × validação', 'seção 4'),

  ('qualidade-q2-a02', 3,
   'Uma atualização chega a todos os clientes ao mesmo tempo e derruba cada máquina que a recebe. Qual controle reduziria diretamente o raio de alcance sem esconder o defeito?',
   '["Aumentar a cobertura de linha do módulo antes de cada publicação", "Duplicar o serviço com o mesmo software em uma segunda região", "Liberar por canário e ampliar por anéis após observar cada grupo", "Trocar o alerta por um e-mail com prioridade alta para a operação"]'::jsonb, 90, 'Falhas reais e contenção', 'seção 1'),

  ('qualidade-q2-a02', 4,
   'O requisito diz apenas que a busca deve ser rápida. O que precisa ser acrescentado para transformá-lo em critério testável?',
   '["O nome da ferramenta que será usada para medir a busca", "A estimativa de esforço da equipe para otimizar a consulta", "A característica ISO escolhida para classificar o requisito", "Uma condição de uso e um limite mensurável, como p95 abaixo de 2 s"]'::jsonb, 90, 'Qualidade sob condições especificadas', 'seção 2'),

  ('qualidade-q2-a02', 5,
   'Depois de um incidente, a equipe corrige o defeito, mas não registra um teste de regressão. Segundo o mecanismo do “cerco”, qual risco permanece?',
   '["A mesma falha pode voltar, porque a correção não virou memória executável", "A maturidade aumenta mesmo assim, pois basta o tempo de produção", "O risco residual chega a zero assim que o hotfix é publicado", "A densidade de defeitos necessariamente cai com uma correção manual"]'::jsonb, 90, 'Maturidade e regressão', 'seção 7'),

  ('qualidade-q2-a02', 6,
   'A equipe mede 100% de cobertura e passa a premiar quem mantiver esse número. Surgem testes sem assertivas relevantes. Qual princípio explica o desvio?',
   '["Shift-left: antecipar o teste torna a métrica menos confiável", "Lei de Goodhart: transformar a métrica em meta incentiva otimizar o número", "Custo de conformidade: toda medição desloca defeitos para produção", "Eficiência de remoção: quanto mais testes, menor a evidência obtida"]'::jsonb, 90, 'Métricas e Lei de Goodhart', 'seção 8'),

  ('qualidade-q2-a02', 7,
   'Um sistema atende às funções previstas, mas expõe tokens nos logs. Qual característica da ISO/IEC 25010 localiza melhor o problema?',
   '["Adequação funcional, porque o sistema ainda executa as funções pedidas", "Capacidade de interação, porque o log pode confundir o operador", "Segurança, porque a confidencialidade da credencial foi violada", "Flexibilidade, porque o token dificulta instalar o sistema em outro ambiente"]'::jsonb, 90, 'ISO/IEC 25010', 'seção 5'),

  ('qualidade-q2-a02', 8,
   'O orçamento corta treinamento, revisão e automação, mas mantém uma reserva para hotfixes e suporte após o release. Como o custo da qualidade interpreta a decisão?',
   '["Converte custo de falha externa em prevenção, reduzindo a exposição", "Remove custo de conformidade sem alterar a probabilidade de falha", "Prioriza avaliação, pois suporte e hotfix são controles detectivos", "Troca prevenção planejada por não conformidade, cuja conta chega mais tarde"]'::jsonb, 90, 'Custo da qualidade e shift-left', 'seção 6')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 0, 'QA atua sobre o processo: revisão obrigatória e Definition of Done reduzem a chance de inserir defeitos. QC inspeciona um artefato, enquanto teste executa o software para produzir evidência; nenhum desses dois descreve primeiro a mudança proposta.'),
    (2, 1, 'Verificação pergunta se construímos o produto conforme a especificação; por isso ela passou. Validação pergunta se construímos o produto certo para o uso real; a compra inviável no celular mostra que ela falhou.'),
    (3, 2, 'Canário e anéis não impedem o primeiro erro, mas limitam quantos usuários o recebem antes da observação e da interrupção. Duplicar software idêntico replica a mesma falha, e cobertura isolada não controla a distribuição.'),
    (4, 3, '“Rápida” é opinião até existir contexto e número. Condição e limite, como carga definida e p95 abaixo de 2 s, criam um critério binário; nomear ferramenta ou atributo não fornece o valor de aprovação.'),
    (5, 0, 'O cerco fecha quando a falha revelada produz correção e teste de regressão. Sem o teste, a equipe não guarda uma prova executável contra a reincidência e pode resolver o mesmo defeito novamente.'),
    (6, 1, 'A Lei de Goodhart descreve a distorção: quando o indicador vira alvo, as pessoas aprendem a melhorar o número sem melhorar o fenômeno. Cobertura mede execução; não demonstra que o comportamento foi verificado.'),
    (7, 2, 'Token em log viola confidencialidade, subcaracterística de Segurança. O sistema pode continuar funcional, mas qualidade inclui necessidades implícitas e não funcionais; executar a função não compensa expor a credencial.'),
    (8, 3, 'Treinamento, revisão e automação são custos de conformidade escolhidos, sobretudo prevenção. Hotfix, suporte e dano após o release são custos de não conformidade; cortar a primeira coluna desloca a despesa para a segunda, normalmente com juros.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token público legado. Também autoriza relatórios individuais e publicação.
insert into quiz_host_tokens (session_slug, token)
values ('qualidade-q2-a02', '080909')
on conflict (session_slug) do update set token = excluded.token;

-- A última questão vale o dobro.
update quiz_questions set peso = 2
 where session_slug = 'qualidade-q2-a02'
   and ordem = (select max(ordem) from quiz_questions where session_slug = 'qualidade-q2-a02');

select count(*) || ' perguntas carregadas, a última com peso '
       || max(peso) filter (where ordem = 8) as resultado
  from quiz_questions where session_slug = 'qualidade-q2-a02';
