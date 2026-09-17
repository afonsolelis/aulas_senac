---
name: supabase-compartilhado
description: Regras obrigatórias antes de tocar no banco Supabase do Hub (projeto lwamaovuxcevsjfvtqhf), que é COMPARTILHADO com o projeto irmão do Einstein. Use SEMPRE que for rodar SQL, aplicar schema ou seed, conectar pelo SUPABASE_DB_URL, criar tabela ou função, trazer SQL de outro repositório (aulas, einstein) ou quando aparecer drop, truncate, alter, delete ou "create or replace". Nunca dropar nem alterar objeto existente.
---

# Supabase compartilhado: nunca mexer no que já existe

O projeto Supabase `lwamaovuxcevsjfvtqhf` **não é só do Hub**. As aulas do **Einstein**
(repositório irmão `~/repos/einstein`, SQL em `supabase/tbl-aula-06.sql`) usam o mesmo banco.
Um `drop` ou um `create or replace` com nome repetido derruba a aula de outra turma, sem erro
nenhum deste lado.

## Quem é dono de quê

| Prefixo | Dono | Objetos (levantados em 17/09/2026) |
|---|---|---|
| `tbl_*` | **Einstein. Não tocar.** | tabelas `tbl_sessions`, `tbl_participants`, `tbl_votes`; funções `tbl_distribution`, `tbl_enter`, `tbl_host`, `tbl_host_state`, `tbl_phase`, `tbl_state`, `tbl_timeline`, `tbl_vote` |
| `quiz_*` | Hub (quiz ao vivo) | `quiz_sessions`, `quiz_questions`, `quiz_answer_key`, `quiz_answers`, `quiz_players`, `quiz_strikes`, `quiz_host_tokens`, `quiz_relatorios` e as RPCs `quiz_*` |
| `avisos*` | Hub (quadro de avisos) | `avisos`, `avisos_admin`, `avisos_sessoes` e as RPCs `avisos_*` |

A lista envelhece. **Antes de escrever, levante de novo** (consulta abaixo). Objeto que não
estiver em `quiz_*`/`avisos*` e não tiver sido criado nesta conversa é de outro projeto.

## Proibido, sem exceção

- `drop table`, `drop function`, `drop view`, `drop ... cascade`, `drop schema`.
- `truncate`, e `delete`/`update` em tabela de outro projeto.
- `alter table` / `alter function` / `alter publication ... drop` em objeto existente.
- `create or replace function` com nome (e assinatura) que **já existe** e não é do Hub. O
  `replace` sobrescreve a função do Einstein em silêncio.
- `revoke` ou `grant` em objeto que não é do Hub.
- Rodar `supabase/quiz-schema.sql`: ele começa com `drop table` e apaga as salas de quiz com
  histórico real. Serve só a um banco novo, que este não é mais.
- Aplicar SQL trazido de outro repositório **sem adaptar**. O TBL de `~/repos/aulas`
  (`tbl-schema.sql`, `tbl-funcoes.sql`) nasceu em outro projeto Supabase (`lcyxqwdgsrbcpecqyqje`),
  começa com `drop table if exists tbl_sessions cascade` e usa o prefixo `tbl_`. Aplicado aqui, ele
  **apaga as tabelas do Einstein** e sobrescreve `tbl_host`.

Se a tarefa parecer exigir qualquer item acima, **pare e pergunte ao professor**. Não contorne.

## Permitido

- Leitura: `select`, `\d`, consultas a `pg_tables`, `pg_proc`, `pg_publication_tables`.
- Criar objetos **novos**, com prefixo próprio que ainda não exista no banco (confira antes).
  Prefixo de feature nova do Hub: escolha um nome que não comece com `tbl_`, `quiz_` nem `avisos`.
- `create table if not exists`, `create index if not exists`, `create function` com nome novo.
- `alter publication supabase_realtime add table <tabela nova do Hub>` (só adicionar).
- Seeds que fazem `insert ... on conflict` nas tabelas do **próprio** Hub, restritos ao `slug` da sala.

## Checklist antes de executar qualquer SQL de escrita

1. Levante o que existe:
   ```sql
   select 'tabela', tablename from pg_tables where schemaname = 'public'
   union all
   select 'funcao', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
   union all
   select 'realtime', tablename from pg_publication_tables where pubname = 'supabase_realtime'
   order by 1, 2;
   ```
2. Procure no script: `grep -niE 'drop|truncate|alter|delete|create or replace|revoke' arquivo.sql`.
   Cada ocorrência precisa atingir **só** objeto novo ou do Hub.
3. Confirme que nenhum nome criado pelo script aparece na lista do passo 1, a não ser que seja do Hub.
4. Mostre ao professor a lista de objetos que o script cria ou altera e **espere o ok explícito**.
5. Execute dentro de `begin; ... commit;` e, depois, repita o passo 1 para provar que os
   objetos `tbl_*` do Einstein continuam lá, com as mesmas funções.

## Conexão

A URL fica em `SUPABASE_DB_URL` no `.env` (ignorado pelo git). **Nunca** escreva a senha em
arquivo versionado, em commit ou em página: o repositório é público. Nas páginas vai apenas a
chave **publicável**, e quem limita o acesso é a RLS.
