-- =====================================================================
-- Qualidade de Software 2026.2 — Aula 07 (Semana 38)
-- Quiz de retomada da Aula 06: "Testes Automatizados em CI (GitHub Actions)".
--
-- Oito questões, 90 segundos cada, extraídas do slide e do material da
-- Aula 06 (pages/qualidade2/slide_ci-github-actions.html e
-- .../material/material_ci-github-actions.html).
--
-- As questões são de aplicação: cada uma descreve um pipeline real do
-- Foot Fanatics e pede o diagnóstico ou a intervenção. Os distratores
-- reproduzem confusões correntes (verify × test, rerun × correção,
-- cache × workspace persistente, artifact × log do job, cancelar
-- execução × enfraquecer o gate), não alternativas implausíveis. A
-- posição da correta é distribuída entre as quatro letras — duas em
-- cada — e o comprimento das alternativas é equilibrado.
--
-- O token do professor é fixo em '080909' e já vai gravado no fim deste
-- arquivo. Também permite ler relatórios individuais e gabaritos: não
-- oferece confidencialidade. Ver README.md.
--
-- Rodar depois de quiz-schema.sql e quiz-relatorio.sql. É idempotente.
-- =====================================================================

insert into quiz_sessions (slug, titulo, periodo) values
  ('ci-q2-a07', 'Aula 07 — Retomada: Testes Automatizados em CI', '2026-2')
on conflict (slug) do update set titulo = excluded.titulo;

delete from quiz_questions where session_slug = 'ci-q2-a07';

with novas as (
  insert into quiz_questions (session_slug, ordem, enunciado, alternativas, segundos, tema, secao)
  values
  ('ci-q2-a07', 1,
   'O job de testes gera os relatórios em target/surefire-reports e um segundo job, que roda em paralelo, tenta lê-los para montar um resumo. O segundo job não encontra arquivo algum. Qual é a explicação?',
   '["O primeiro job ainda não terminou, e o resumo precisa esperar o processo concluir",
     "Cada job roda em um runner limpo e não compartilha filesystem com os demais",
     "Os relatórios do Surefire só existem quando a fase package é executada antes",
     "O runner apaga os arquivos temporários assim que o passo que os gerou termina"]'::jsonb, 90, 'Anatomia do workflow', 'seção 1'),

  ('ci-q2-a07', 2,
   'A equipe quer que o mesmo comando do gate continue valendo quando, nas próximas semanas, entrarem cobertura e testes de integração. Por que a aula escolhe ./mvnw -B verify em vez de ./mvnw -B test?',
   '["Porque test executa apenas a classe principal e ignora as classes de teste aninhadas",
     "Porque -B só é aceito pelo Maven quando a fase indicada é verify ou posterior a ela",
     "Porque test não falha o build, apenas registra o resultado dos testes no relatório",
     "Porque verify avança o ciclo e acomoda integração e verificações sem trocar o contrato"]'::jsonb, 90, 'Por que verify', 'seção 2'),

  ('ci-q2-a07', 3,
   'Quando a suíte falha, a equipe não consegue baixar os relatórios: o passo de upload não roda. O passo está corretamente configurado com actions/upload-artifact. O que falta?',
   '["Marcar o passo com if: always(), para que ele execute mesmo depois da falha",
     "Mover o upload para um job separado, que depende do job de testes por needs",
     "Aumentar retention-days, porque o artifact expira antes de a equipe baixá-lo",
     "Trocar if-no-files-found para warn, porque error interrompe o passo de upload"]'::jsonb, 90, 'Preservar evidência', 'seção 3'),

  ('ci-q2-a07', 4,
   'Para "facilitar o debug", alguém propõe imprimir o contexto completo do workflow no log e dar permissions: write-all ao job. Qual é o problema, segundo a aula?',
   '["Nenhum, desde que o repositório do Foot Fanatics permaneça privado durante o semestre",
     "O log fica extenso e o tempo de feedback do pipeline cresce além do timeout definido",
     "Imprimir contexto expõe segredo em log e write-all viola o mínimo privilégio do job",
     "write-all é ignorado pelo GitHub Actions, então o passo falha por permissão ausente"]'::jsonb, 90, 'Segurança do workflow', 'seção 4'),

  ('ci-q2-a07', 5,
   'O PR recebe três commits em poucos minutos e as três execuções disputam runners; a primeira ainda roda quando a terceira começa. Qual recurso resolve, e por que é seguro aqui?',
   '["needs, encadeando as execuções para que uma só comece quando a anterior terminar",
     "timeout-minutes, que interrompe a execução antiga assim que o limite é atingido",
     "concurrency com cancel-in-progress, porque o resultado antigo já está obsoleto",
     "cache do Maven, que reduz o tempo de cada execução e desafoga a fila de runners"]'::jsonb, 90, 'Concorrência e tempo de feedback', 'seção 5'),

  ('ci-q2-a07', 6,
   'Um teste de sessão falha uma vez a cada cinco execuções, sem mudança de código. O rerun fica verde e o time libera o merge. Qual é a leitura correta desse rerun?',
   '["O rerun confirma a intermitência; ele não corrige e não deveria liberar o merge",
     "O rerun prova que a falha veio da infraestrutura do runner, e não do código do PR",
     "O rerun é a correção esperada: repetir até o verde é a política de gate saudável",
     "O rerun invalida o resultado anterior, então o vermelho pode ser removido do histórico"]'::jsonb, 90, 'Flakiness e diagnóstico', 'seção 6'),

  ('ci-q2-a07', 7,
   'Uma entrega precisa sair hoje e o check obrigatório está vermelho por um teste legítimo. Propõem marcar o passo com continue-on-error para destravar o merge. O que a aula orienta?',
   '["Aceitar, desde que o registro do débito seja aberto e tratado no ciclo seguinte",
     "Aceitar apenas se a pessoa que revisa aprovar o PR e assumir o risco por escrito",
     "Trocar por retry automático, que é o mecanismo previsto quando o prazo é curto",
     "Recusar: se o pipeline está lento ou instável, corrija o pipeline, não a regra"]'::jsonb, 90, 'Gate como política', 'seção 7'),

  ('ci-q2-a07', 8,
   'A suíte passa na máquina de todo mundo e falha só na CI. Pela tabela de diagnóstico da aula, qual é o primeiro check?',
   '["Reexecutar o job algumas vezes para verificar se o resultado se mantém vermelho",
     "Conferir versão do Java, timezone e o comando exato executado no runner limpo",
     "Revisar o YAML do workflow, porque a indentação costuma alterar a ordem dos passos",
     "Limpar o cache do Maven, porque dependência antiga costuma quebrar só na CI"]'::jsonb, 90, 'Passa local, falha na CI', 'seção 8')
  returning id, ordem
)
insert into quiz_answer_key (question_id, correta, explicacao)
select n.id, g.correta, g.explicacao
  from novas n
  join (values
    (1, 1, 'Cada job executa em um runner limpo e os jobs não compartilham filesystem. Para levar arquivo de um job a outro existe o artifact; para ordenar execução existe needs. Esperar o job terminar não resolveria: mesmo terminado, o diretório target não existe no outro runner.'),
    (2, 3, 'test executa a fase de testes unitários; verify avança o ciclo e é onde entram testes de integração e verificações como cobertura. Escolher verify agora significa que o gate cresce nas próximas semanas sem trocar o contrato principal. test falha o build normalmente — o critério não é esse.'),
    (3, 0, 'Por padrão um passo não roda depois que outro falha, e é justamente na falha que o relatório importa. if: always() garante o upload nos dois casos. retention-days e if-no-files-found afetam o que acontece depois que o passo roda, não se ele roda.'),
    (4, 2, 'São dois problemas distintos e ambos foram citados na aula: imprimir contexto completo expõe segredo no log, que fica visível a quem lê a execução; e permissions deve começar em contents: read, concedendo escrita só ao job que precisa. Repositório privado não é controle de acesso ao log.'),
    (5, 2, 'concurrency agrupa por referência e, com cancel-in-progress, cancela a execução anterior da mesma branch. É seguro porque o resultado do commit antigo já não interessa: quem decide o merge é o último commit. needs ordena jobs dentro de uma execução, não entre execuções.'),
    (6, 0, 'Rerun é experimento: ele confirma que a falha é intermitente, não a corrige nem deve desbloquear merge automaticamente. O caminho é abrir defeito e tratar a fonte de não determinismo — ordem, tempo, concorrência ou estado implícito. Um verde obtido por repetição não é evidência de qualidade.'),
    (7, 3, 'O gate é política: se o check falha, o merge fica bloqueado. Enfraquecer a regra com continue-on-error transforma o pipeline de controle preventivo em relatório decorativo. Quando o pipeline está lento ou instável, o alvo da correção é o pipeline; exceções administrativas existem, mas como exceção auditável, não como rotina.'),
    (8, 1, 'O sintoma clássico de passa local e falha na CI aponta para versão, locale ou estado implícito: Java, timezone e o comando exato são o primeiro check, porque o runner é uma máquina limpa e não herda nada da máquina de ninguém. Reexecutar investiga intermitência, que é outro sintoma; YAML mal indentado costuma impedir o disparo, não produzir falha na suíte.')
  ) as g(ordem, correta, explicacao) on g.ordem = n.ordem;

-- Token público legado. Também autoriza relatórios individuais e publicação.
insert into quiz_host_tokens (session_slug, token)
values ('ci-q2-a07', '080909')
on conflict (session_slug) do update set token = excluded.token;

select count(*) || ' perguntas carregadas' as resultado
  from quiz_questions where session_slug = 'ci-q2-a07';
