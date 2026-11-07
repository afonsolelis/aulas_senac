# PostgREST do Senac na VPS

Desde 07/11/2026, o quiz, o TBL, as entregas, o depósito do TCC2 e o quadro de
avisos rodam no Postgres + PostgREST do projeto `aulas_senac` no Coolify da VPS
Hostinger, e não mais no Supabase cloud (`lwamaovuxcevsjfvtqhf`). O desenho é o
mesmo do `aulas_mackenzie`, em projeto separado.

| Item | Valor |
|------|-------|
| API | `https://aulas-senac-api.afonsolelis.tech` |
| Cliente das páginas | `js/api_aulas.js` (`window.aulasApi.cliente()`) |
| Coolify | projeto `aulas_senac` (`ulcy9nnyuhsaq6womhwbklda`), service `y1hatznx1a0b19hjjoenxmvr` |
| Compose | `hostinger/aulas-senac/docker-compose.yml` (repositório de infraestrutura) |
| Banco | `aulas`, timezone UTC, dados em `/data/aulas-senac/pgdata` na VPS |
| Porta | sem porta pública; só `127.0.0.1:55433` na VPS |
| Senhas | `SENAC_PG_*` no `.env` do repositório `hostinger` |

## O que mudou para as páginas

- O supabase-js saiu. As páginas carregam `js/api_aulas.js`, que imita `db.rpc()`
  e `db.storage.from(...)` do supabase-js. Não há chave: a API só aceita o papel
  `anon`, e o que ele alcança continua definido por grants e RLS, copiados do Supabase.
- Não há Realtime. `db.channel(...)` existe só para não quebrar o código; quiz,
  painéis e TBL consultam o estado a cada segundo. O quiz mostra "Conectado por
  consulta periódica".
- O PDF do TCC2 fica no próprio Postgres (`hubdeposito_arquivos`), porque o PostgREST
  não tem storage. `hubdeposito_subir` recebe o arquivo em base64 e
  `GET /rpc/hubdeposito_pdf?p_caminho=<turma>/<uuid>.pdf` devolve o PDF, que é o
  link público usado pelo comprovante, pelo professor e pela coordenação. SQL em
  `postgrest/hubdeposito-arquivos.sql`. Upload que não vira depósito é apagado
  depois de um dia.

## Aplicar SQL (seed de quiz ou TBL, ajuste de função)

Os arquivos de `supabase/` continuam valendo como fonte das questões e das funções,
mas agora rodam com `psql` no banco da VPS, não no SQL Editor do Supabase. Não
rode `quiz-schema.sql`: ele recria as tabelas.

Pelo túnel SSH (precisa da chave da VPS):

```bash
ssh -N -L 55433:127.0.0.1:55433 root@<ip-da-vps>
psql "postgresql://postgres:<SENAC_PG_ADMIN_PASSWORD>@127.0.0.1:55433/aulas" -v ON_ERROR_STOP=1 -f supabase/quiz-seed-<aula>.sql
psql "postgresql://postgres:<SENAC_PG_ADMIN_PASSWORD>@127.0.0.1:55433/aulas" -c "notify pgrst, 'reload schema'"
```

Na VPS, sem túnel: `docker exec -i postgres-y1hatznx1a0b19hjjoenxmvr psql -U postgres -d aulas`.

Depois de criar ou trocar função, rode `notify pgrst, 'reload schema'` para o
PostgREST enxergar a mudança.

## Validação

- `node scripts/quiz-e2e.mjs <prefixo> <slug-da-sala>`, `node scripts/tbl-e2e.mjs aula07 ff-q2-a07-tbl`
  e `node scripts/avisos-e2e.mjs <senha>` falam com esta API. Eles descartam a sala no fim:
  não rode em aula.
- Na virada (07/11/2026), passaram o ensaio de carga com 20 alunos no TBL (5 questões) e no quiz
  (8 perguntas), o depósito de um PDF de 25 MB e a carga das 30 páginas alteradas.
