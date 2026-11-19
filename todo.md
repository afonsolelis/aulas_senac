# TODO · Qualidade de Software 2027.1 (`qualidade3`)

Pendências deixadas em 19/11/2026, depois de montar a disciplina (slides, materiais,
trabalhos, entrega e cronograma). Fazer de casa: o wifi do Senac bloqueia SSH.

## 1. Aplicar os formulários de entrega no banco da VPS (Hostinger)

O banco é o Postgres + PostgREST do projeto `aulas_senac` no Coolify da VPS Hostinger
(não o Supabase; a pasta `supabase/` só guarda o nome histórico). O arquivo só insere
dois formulários em `entrega_formularios`; é idempotente e não altera nada existente.

Conexão SSH: a chave, o host, o usuário e a porta ficam no `.env` do repositório
`~/repos/hostinger` (variáveis `HOSTINGER_SSH_KEY`, `HOSTINGER_HOST`, `HOSTINGER_USER`,
`HOSTINGER_PORT`; a senha do banco é `SENAC_PG_ADMIN_PASSWORD`). Nada disso vai para este
repositório, que é público. A skill `vps-ops` do repositório `hostinger` usa o mesmo comando.

```bash
cd ~/repos/aulas_senac && git pull
set -a && . ~/repos/hostinger/.env && set +a

# terminal 1: túnel até o Postgres do Senac (só escuta em 127.0.0.1:55433 na VPS)
ssh -i "$HOSTINGER_SSH_KEY" -p "$HOSTINGER_PORT" -N -L 55433:127.0.0.1:55433 "$HOSTINGER_USER@$HOSTINGER_HOST"

# terminal 2 (carregue o .env de novo nele)
psql "postgresql://postgres:$SENAC_PG_ADMIN_PASSWORD@127.0.0.1:55433/aulas" \
  -v ON_ERROR_STOP=1 -f supabase/entregas-qualidade3-2027-1.sql
psql "postgresql://postgres:$SENAC_PG_ADMIN_PASSWORD@127.0.0.1:55433/aulas" \
  -c "notify pgrst, 'reload schema'"
```

Ou direto na VPS: `docker exec -i postgres-y1hatznx1a0b19hjjoenxmvr psql -U postgres -d aulas < supabase/entregas-qualidade3-2027-1.sql`.

Alternativa sem SSH: terminal web do Coolify no container do Postgres, `psql -U postgres -d aulas`,
colar o conteúdo do arquivo e rodar `notify pgrst, 'reload schema';`.

Conferir (de qualquer rede):

```bash
curl -s -X POST https://aulas-senac-api.afonsolelis.tech/rpc/entrega_formulario \
  -H 'Content-Type: application/json' -d '{"p_slug":"senac-qs-2027-1-trabalho-1"}'
```

Deve voltar o formulário com `"aceitando": true`. O Trabalho 2 nasce fechado: abrir na
semana 17 em `pages/qualidade3/entrega/professor.html`.

- [ ] SQL aplicado
- [ ] `entrega_formulario` responde para os dois slugs
- [ ] `pages/qualidade3/entrega/entrega.html` mostra o Trabalho 1 aberto

## 2. Testar o opencode num Codespace real antes da Aula 01

Os comandos e o `opencode.json` dos slides foram escritos sem rodar num Codespace.

- [ ] `curl -fsSL https://opencode.ai/install | bash` funciona no `postCreateCommand`
- [ ] `opencode auth login` lista a OpenRouter
- [ ] `{env:OPENROUTER_API_KEY}` é lido a partir do secret do Codespaces
- [ ] modelo padrão `openrouter/qwen/qwen3-coder` existe (ou trocar nos slides e materiais)
- [ ] `opencode models openrouter` e `opencode run -m ...` com a sintaxe dos slides
- [ ] provedor OpenLLM (`@ai-sdk/openai-compatible`, `baseURL` em `localhost:3000/v1`)

## 3. Decisões tomadas sem confirmação

- [ ] Pesos de avaliação em `pages/qualidade3/trabalho-1.html` e `trabalho-2.html`
- [ ] Regra "a prova oral confirma a autoria" e os limitadores de nota
- [ ] Case das demonstrações: `biblioteca-campus` (empréstimo de livros)
- [ ] Ordem de chamada da prova oral publicada no quadro de avisos

## 4. Calendário

- [ ] Carga horária: o cronograma tem 18 encontros (60h); o bloco `calendario` de 2027.1 em
      `config/semestres.json` fala em 22 encontros e 72h
- [ ] Dia da semana, sala e feriados quando sair o calendário oficial do Senac
      (Sexta-feira Santa 26/03 cai em prova oral do T1; Tiradentes 21/04 na Aula 12;
      Corpus Christi 27/05 na revisão, conforme o dia da aula)
- [ ] Siglas das turmas de 2027.1 (o campo `turma` dos formulários está como `2027.1`)
