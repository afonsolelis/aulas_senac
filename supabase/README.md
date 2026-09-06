# Supabase — banco de dados do Hub

Dois assuntos vivem no mesmo projeto Supabase e não se tocam: o **quiz ao vivo**
(o grosso deste arquivo) e o **quadro de avisos** (última seção). Cada um tem os
seus arquivos `*.sql` e o seu conjunto de funções.

## Quiz ao vivo

Suporte de dados dos quizzes projetados em aula (`pages/<disciplina>/quiz/*.html`).
O site continua estático: estes arquivos não são executados pelo site, são rodados
**à mão**, no **SQL Editor** do painel do Supabase. O esquema é instalado uma vez;
para uma aula nova, usa-se o seed correspondente, sem recriar as tabelas existentes.

Projeto Supabase: `lwamaovuxcevsjfvtqhf`
(a chave publicável fica escrita nas páginas — ela é pública por desenho; quem
define o que ela alcança é a RLS, não o sigilo dela).

### Ordem de execução

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
5. `quiz-banco.sql` — o banco público: coluna `publicado_em` em `quiz_sessions`,
   as funções `quiz_banco_salas` / `quiz_banco` (leitura sem token, sem nome de
   aluno) e `quiz_publicar`, que o botão **Publicar banco** do painel chama.
   Não destrói dado.
6. `quiz-seed-<aula>.sql` — a sessão e as perguntas daquela aula. Grava o
   `periodo` (`2026-2`), que compõe a `data_tag` do histórico.
7. Os seeds existentes usam um token fixo e público, por decisão anterior do professor.
   Ele autoriza também o relatório individual, o gabarito e a publicação do banco.
   Portanto, não oferece confidencialidade aos resultados individuais. Para restringir
   esse acesso, configure uma credencial privada no SQL Editor e não a versione.
   A troca precisa ser aplicada à sala no Supabase; editar o arquivo local não basta.

   ```sql
   insert into quiz_host_tokens (session_slug, token)
   values ('<slug-da-sessao>', '<token-privado-definido-no-SQL-Editor>')
   on conflict (session_slug) do update set token = excluded.token;
   ```

### Sessões cadastradas

Cada aula abre cobrando a aula anterior.

| Aula | Cobra | Slug | Seed | Páginas |
|---|---|---|---|---|
| Aula 04 (Semana 35) — Arquitetura e ATAM | Aula 03 — caixas, cobertura e técnicas | `caixa-q2-a04` | `quiz-seed-aula04-caixas.sql` | `pages/qualidade2/quiz/aula04-quiz.html`, `aula04-painel.html`, `aula04-relatorio.html` |
| Aula 05 (Semana 36) — Gestão de erros e bugs | Aula 04 — arquitetura, C4, pipeline e ATAM | `atam-q2-a05` | `quiz-seed-aula05-atam.sql` | `pages/qualidade2/quiz/aula05-quiz.html`, `aula05-painel.html`, `aula05-relatorio.html` |

### Histórico das turmas

A mesma sala é jogada pelas três turmas de Qualidade 2026.2, uma por dia da
semana, e o professor reinicia entre elas. Antes de apagar, `reiniciar` grava a
rodada em `quiz_relatorios`, no grão de **uma linha por estudante e questão** —
de onde qualquer agregação pode ser refeita depois. São três colunas: `ts`
(unixtime do arquivamento), `data` (as linhas, em `jsonb`) e `data_tag`
(`2026-2-atam-q2-a05`). O `ts` distingue as rodadas e as ordena na ordem em que
as turmas jogaram. Ele **não identifica com segurança qual turma** foi cada uma:
o reinício acontece entre as aulas e pode cair no dia seguinte ao da rodada que
está arquivando. Por isso o banco público rotula "Rodada 1, 2, 3", não a turma.

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

### Desenho de acesso (resumo)

Só `quiz_sessions` é legível pela API — é o que permite ao Realtime avisar os
celulares quando a pergunta abre. Gabarito, jogadores, respostas e o token do
professor ficam em tabelas com RLS habilitada e **nenhuma policy**: nada é lido
ou escrito por chamada direta. Tudo passa pelas funções `security definer`, que
devolvem veredito e placar — nunca o gabarito antes da revelação, nunca a
credencial de outro jogador.

#### Armadilha dos grants (ler antes de criar função nova)

`revoke all on function ... from public` **não basta** aqui. O Supabase concede
`EXECUTE` a `anon` e `authenticated` por *default privilege* em toda função nova
do schema `public`, e esse grant sobrevive ao revoke de `PUBLIC`. Uma função
interna deixada assim vira RPC aberta: `quiz_linhas` chegou a responder a
`POST /rest/v1/rpc/quiz_linhas` com a chave publicável, devolvendo nome,
escolha e gabarito de cada estudante. Toda função que não é para ser chamada de
fora precisa de:

```sql
revoke all on function minha_funcao(...) from public, anon, authenticated;
```

Funções `security definer` chamadas de dentro de outra continuam funcionando: ali
o executor é o dono. Conferir depois de aplicar qualquer arquivo novo:

```sql
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like 'quiz%' order by 2 desc, 1;
```

Só estas devem sair com `t`: `quiz_entrar`, `quiz_responder`, `quiz_estado`,
`quiz_host`, `quiz_relatorio`, `quiz_gabarito`, `quiz_publicar`, `quiz_banco` e
`quiz_banco_salas`. `tests/quiz-banco.test.js` guarda o lado do repositório.

### Conduzindo a sessão

1. Abrir o painel pelo botão **Painel** no topo do slide da aula, pela central em
   `pages/qualidade2/quiz/index.html`. (No card da home o quiz é um chip que leva à
   tela do aluno — o caminho do professor é o slide ou a central.) Digitar o
   token uma vez — ele fica guardado neste navegador.
2. Projetar o lobby: QR code e endereço do quiz; os nomes aparecem conforme
   a turma entra.
3. `Abrir pergunta` → cronômetro de 90 s no celular de cada aluno → o painel
   **revela sozinho** assim que todos respondem ou o tempo acaba (mostra
   distribuição, explicação e placar) → repetir. `Revelar resposta` continua no
   rodapé para adiantar.
4. `Encerrar sessão` na última: cada aluno vê os temas que precisa retomar.
5. `Relatório` para a leitura por tema, questão e estudante — e a aba
   *Perguntas e gabarito*, que mostra as oito questões com a correta e a explicação.
6. `Reiniciar`, no painel, abre a confirmação que oferece **Baixar CSV** antes de
   apagar. O CSV é conveniência: o reinício **arquiva sozinho** a rodada em
   `quiz_relatorios` e informa quantas respostas guardou.
7. **Publicar banco**, no painel, e só **depois que as três turmas jogaram**:
   arquiva a rodada corrente, zera a sala e libera o banco público da aula.
   Publicar antes entregaria o gabarito a quem ainda vai jogar.

### Banco de questões e relatórios (a leitura dos alunos)

`pages/qualidade2/quiz/banco.html` é a página pública, ligada por um botão
próprio na home da disciplina. Mostra, de cada aula **publicada**: as oito
questões com a alternativa correta e a explicação, o desempenho por tema e por
questão somando todas as rodadas, e cada rodada em separado — quantos
participaram, a taxa de acerto e a distribuição por alternativa.

**Nunca há resultado individual.** `quiz_banco` agrega dentro da função; o nome
do estudante entra apenas para contar participantes e não aparece na resposta.
Duas salvaguardas sustentam isso:

- Rodadas com menos de `quiz_banco_piso()` participantes (**3**) ficam fora — com
  dois jogadores, "1 escolheu B" volta a identificar alguém. É também o que
  mantém rodada de teste fora da vista dos alunos.
- A página não pede token e não tem como pedir: `quiz_banco` recusa qualquer sala
  cujo `publicado_em` seja nulo, então nada vaza antes da hora.

Publicar é `quiz_publicar(slug, token, 'publicar')` — o botão **Publicar banco**
do painel. Para recolher uma aula sem perder o histórico:

```sql
select quiz_publicar('atam-q2-a05', '<token-do-professor>', 'despublicar');
```

As perguntas vêm das tabelas ao vivo (a sala continua cadastrada depois de
zerada), e as estatísticas, de `quiz_relatorios`. Consequência a conhecer: se um
seed for reescrito com outras perguntas sob o **mesmo slug**, as rodadas antigas
passam a ser exibidas ao lado das perguntas novas, casadas por `ordem`. Aula nova,
slug novo.

## Quadro de avisos

Suporte do sino que aparece em toda página do Hub (`js/avisos.js`) e da página
`pages/avisos.html`. O professor entra com usuário e senha, publica um recado e
os alunos veem na próxima vez que abrirem qualquer página — sem commit, sem deploy.

### Ordem de execução

1. `avisos-schema.sql` — tabelas (`avisos`, `avisos_admin`, `avisos_sessoes`), RLS e
   as funções `avisos_*`. **Idempotente e não destrutivo**: reexecutar preserva os
   avisos publicados e a conta do professor (ao contrário de `quiz-schema.sql`).
2. `avisos-admin.sql` — cria (ou redefine) a conta do professor. **Troque
   `SENHA-AQUI` pela senha real antes de executar e não versione essa edição**:
   este repositório é público. Só o hash salgado chega ao banco.

### Aplicando por `psql` em vez do SQL Editor

Com `SUPABASE_DB_URL` no `.env`, dá para aplicar direto:

```bash
set -a; . ./.env; set +a
export PGOPTIONS='-c lock_timeout=10s -c statement_timeout=60s -c idle_in_transaction_session_timeout=30s'
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 --single-transaction -f supabase/avisos-schema.sql
```

**Não pule o `PGOPTIONS`.** A conexão passa pelo pooler: matar o `psql` local **não**
encerra a sessão do lado do servidor. Uma execução interrompida no meio deixa um backend
`idle in transaction` segurando o lock da tabela, e a tentativa seguinte fica pendurada
para sempre no primeiro `create table`. Com os timeouts acima, a sessão órfã se mata
sozinha em 30 s. Para inspecionar:

```sql
select pid, state, now()-state_change as parado_ha, left(query, 60)
  from pg_stat_activity where datname = current_database() and state like '%transaction%';
```

A conta do professor não pode ir por `-c` (psql não expande `:'variavel'` em `-c`) —
mande por stdin, para a senha não virar arquivo:

```bash
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -v senha='<senha>' <<'SQL'
with nova as (select 'afonsolelis'::text as usuario, avisos_novo_token() as salt, :'senha'::text as senha)
insert into avisos_admin (usuario, salt, senha_hash)
select usuario, salt, avisos_hash(salt, senha) from nova
on conflict (usuario) do update set salt = excluded.salt, senha_hash = excluded.senha_hash,
                                    falhas = 0, bloqueado_ate = null;
SQL
```

### Desenho de acesso

Nenhuma das três tabelas tem policy: `anon` não lê nem escreve uma linha por
chamada direta — nem os avisos, que saem só por `avisos_listar`, já filtrados
(sem removidos, sem expirados). Não há Realtime aqui, então nem a exceção de
leitura que `quiz_sessions` precisa existe.

A senha nunca sai do servidor e nunca entra no JavaScript: o navegador manda
usuário e senha para `avisos_login`, que compara com `sha256(salt || ':' || senha)`
e devolve um token de sessão de 12 h. Cinco erros seguidos bloqueiam a conta por
15 minutos — é o que torna defensável uma senha curta. Para destravar antes:

```sql
update avisos_admin set falhas = 0, bloqueado_ate = null where usuario = 'afonsolelis';
```

Vale a mesma armadilha de grants descrita acima. Depois de aplicar o schema:

```sql
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like 'avisos%' order by 2 desc, 1;
```

Devem sair com `t` apenas: `avisos_listar`, `avisos_login`, `avisos_sair`,
`avisos_trocar_senha`, `avisos_publicar`, `avisos_editar`, `avisos_remover`,
`avisos_restaurar` e `avisos_painel`. As internas — `avisos_hash`,
`avisos_novo_token` e `avisos_usuario` — precisam sair com `f`.

### Operação

- Publicar: sino em qualquer página → **Área do professor** → entrar → escrever.
  O campo *Para quem* limita o aviso a uma disciplina; *Sumir do quadro em* dá
  validade (some sozinho, sem precisar remover).
- Remover é **lógico** (`removido_em`): o aviso sai da vista e o botão **Restaurar**
  o traz de volta. Nada é apagado de fato.
- **Trocar a senha** pela própria interface (mínimo 8 caracteres) derruba as outras
  sessões abertas. Como a senha inicial é curta, esta é a primeira coisa a fazer
  depois de instalar.

Validação depois de aplicar os dois arquivos:

```bash
node scripts/avisos-e2e.mjs <senha-do-professor>
```

Além do caminho feliz, ele confere o lado negativo: `avisos_hash`, `avisos_usuario` e
`avisos_novo_token` precisam recusar a chave publicável, e `avisos_admin` não pode
devolver linha alguma por leitura direta.

```sql
-- o que está publicado agora
select id, escopo, fixado, publicado_em, expira_em, titulo from avisos
 where removido_em is null order by fixado desc, publicado_em desc;
```
