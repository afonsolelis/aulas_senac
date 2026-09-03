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
3. `quiz-ingestao.sql` — a série histórica: coluna `periodo` em `quiz_sessions`,
   tabela `quiz_relatorios` e as funções `quiz_linhas` / `quiz_arquivar`. Não
   destrói dado. **A ação `reiniciar` depende deste arquivo** — sem ele o botão
   Reiniciar do painel falha (e, por falhar, não apaga nada).
4. `quiz-gabarito.sql` — função `quiz_gabarito`, que devolve as perguntas com o
   gabarito para a aba "Perguntas e gabarito" do relatório. Exige token.
5. `quiz-seed-<aula>.sql` — a sessão e as perguntas daquela aula. Grava o
   `periodo` (`2026-2`), que compõe a `data_tag` do histórico.
6. O token do professor já vai no próprio seed: **`080909`**, o mesmo para todas as
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

## Histórico das turmas

A mesma sala é jogada pelas três turmas de Qualidade 2026.2, uma por dia da
semana, e o professor reinicia entre elas. Antes de apagar, `reiniciar` grava a
rodada em `quiz_relatorios`, no grão de **uma linha por estudante e questão** —
de onde qualquer agregação pode ser refeita depois. São três colunas: `ts`
(unixtime do arquivamento), `data` (as linhas, em `jsonb`) e `data_tag`
(`2026-2-atam-q2-a05`). O `ts` distingue as rodadas e, cruzado com o
`dia_semana` de `config/semestres.json`, identifica a turma que jogou.

Nada é gravado quando não houve resposta, para não poluir a série com reinícios
de sala vazia. Para uma rodada de teste que não deve entrar na série existe a
ação **`descartar`**, que zera sem arquivar — é a que `scripts/quiz-e2e.mjs` usa.

`quiz_relatorios` não tem policy: a chave publicável não a lê. A leitura é feita
no SQL Editor, onde a comparação entre turmas faz sentido:

```sql
select data_tag, to_timestamp(ts) as quando, jsonb_array_length(data) as linhas
  from quiz_relatorios order by ts desc;

-- desempenho por tema em uma rodada
select l->>'tema' as tema,
       count(*) filter (where (l->>'acertou')::bool) || '/' || count(*) as acertos
  from quiz_relatorios r, jsonb_array_elements(r.data) l
 where r.data_tag = '2026-2-atam-q2-a05'
 group by 1 order by 1;
```

A tabela não referencia as tabelas do quiz — assim sobrevive a um `quiz-schema.sql`
rodado de novo, que recria todo o resto.

## Desenho de acesso (resumo)

Só `quiz_sessions` é legível pela API — é o que permite ao Realtime avisar os
celulares quando a pergunta abre. Gabarito, jogadores, respostas e o token do
professor ficam em tabelas com RLS habilitada e **nenhuma policy**: nada é lido
ou escrito por chamada direta. Tudo passa pelas funções `security definer`, que
devolvem veredito e placar — nunca o gabarito antes da revelação, nunca a
credencial de outro jogador.

## Conduzindo a sessão

1. Abrir o painel pelo botão **Painel** no topo do slide da aula, pela central em
   `pages/qualidade2/quiz/index.html` ou pelo botão **Painel** no card da home. Digitar o
   token uma vez — ele fica guardado neste navegador.
2. Projetar o lobby: QR code e endereço do quiz; os nomes aparecem conforme
   a turma entra.
3. `Abrir pergunta` → cronômetro de 40 s no celular de cada aluno →
   `Revelar resposta` (mostra distribuição, explicação e placar) → repetir.
4. `Encerrar sessão` na última: cada aluno vê os temas que precisa retomar.
5. `Relatório` para a leitura por tema, questão e estudante — e a aba
   *Perguntas e gabarito*, que mostra as oito questões com a correta e a explicação.
6. `Reiniciar`, no painel, abre a confirmação que oferece **Baixar CSV** antes de
   apagar. O CSV é conveniência: o reinício **arquiva sozinho** a rodada em
   `quiz_relatorios` e informa quantas respostas guardou.
