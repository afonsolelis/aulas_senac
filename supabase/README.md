# Quiz ao vivo — banco de dados

Suporte de dados dos quizzes projetados em aula (`pages/<disciplina>/quiz/*.html`).
O site continua estático: estes arquivos não são executados pelo site, são rodados
**à mão**, uma vez por sessão, no **SQL Editor** do painel do Supabase.

Projeto Supabase: `lwamaovuxcevsjfvtqhf`
(a chave publicável fica escrita nas páginas — ela é pública por desenho; quem
define o que ela alcança é a RLS, não o sigilo dela).

## Ordem de execução

1. `quiz-schema.sql` — tabelas, RLS e funções (`quiz_entrar`, `quiz_responder`,
   `quiz_estado`, `quiz_host`). **Apaga as tabelas do quiz e recria**: rodar de
   novo zera respostas e jogadores de todas as salas.
2. `quiz-relatorio.sql` — função `quiz_relatorio`, usada pela página de relatório.
   Não destrói dado algum; pode ser aplicado com sessão em andamento.
3. `quiz-seed-<aula>.sql` — a sessão e as perguntas daquela aula.
4. O token do professor já vai no próprio seed: **`080909`**, o mesmo para todas as
   salas, por decisão do professor. A sala é descartável e o token só abre, revela e
   reinicia — quem o descobrir consegue, no máximo, atrapalhar a rodada.

   ```sql
   insert into quiz_host_tokens (session_slug, token)
   values ('<slug-da-sessao>', '080909')
   on conflict (session_slug) do update set token = excluded.token;
   ```

## Sessões cadastradas

Cada aula abre cobrando a aula anterior.

| Aula | Cobra | Slug | Seed | Páginas |
|---|---|---|---|---|
| Aula 04 (Semana 35) — Arquitetura e ATAM | Aula 03 — caixas, cobertura e técnicas | `caixa-q2-a04` | `quiz-seed-aula04-caixas.sql` | `pages/qualidade2/quiz/aula04-quiz.html`, `aula04-painel.html`, `aula04-relatorio.html` |
| Aula 05 (Semana 36) — Gestão de erros e bugs | Aula 04 — arquitetura, C4, pipeline e ATAM | `atam-q2-a05` | `quiz-seed-aula05-atam.sql` | `pages/qualidade2/quiz/aula05-quiz.html`, `aula05-painel.html`, `aula05-relatorio.html` |

## Desenho de acesso (resumo)

Só `quiz_sessions` é legível pela API — é o que permite ao Realtime avisar os
celulares quando a pergunta abre. Gabarito, jogadores, respostas e o token do
professor ficam em tabelas com RLS habilitada e **nenhuma policy**: nada é lido
ou escrito por chamada direta. Tudo passa pelas funções `security definer`, que
devolvem veredito e placar — nunca o gabarito antes da revelação, nunca a
credencial de outro jogador.

## Conduzindo a sessão

1. Abrir `aula05-painel.html`, digitar o token (fica guardado no navegador).
2. Projetar o lobby: QR code e endereço do quiz; os nomes aparecem conforme
   a turma entra.
3. `Abrir pergunta` → cronômetro de 40 s no celular de cada aluno →
   `Revelar resposta` (mostra distribuição, explicação e placar) → repetir.
4. `Encerrar sessão` na última: cada aluno vê os temas que precisa retomar.
5. `Relatório` para a leitura por tema, questão e estudante; `Baixar CSV` antes
   de `Reiniciar`, porque reiniciar apaga jogadores e respostas.
