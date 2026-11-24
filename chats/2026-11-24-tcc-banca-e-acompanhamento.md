# Banca do TCC2 2026.2 e acompanhamento do TCC1 2027.1

Registro da sessão de 24/11/2026 com o Claude Code. Guarda as decisões, o que foi construído e como
operar. O repositório é público: **nenhum token ou senha aparece aqui**. O token da coordenação fica no
`.env` local, na variável `TCC2_COORDENACAO_TOKEN`; o acesso à VPS segue `postgrest/README.md`.

## 1. Token da coordenação

- O banco guarda só `sha256(sal || token)` em `hubdeposito_acesso` (papel `coordenacao`). Não dá para
  recuperar um token esquecido, só trocar.
- O token foi redefinido nesta sessão e gravado no `.env` (`TCC2_COORDENACAO_TOKEN`). O comando de troca
  está no cabeçalho de `supabase/hubdeposito-coordenacao.sql`.
- O mesmo token abre a coordenação do TCC2 2026.2 e a do TCC1 2027.1. Cinco erros seguidos bloqueiam por
  15 minutos.

## 2. Banca do TCC2 2026.2

Commit `9580010` (mais a documentação em `0fca89d`).

**Pedido:** na área da coordenação, alocar professores à banca de cada trabalho, gerar um acesso só
àquele TCC e deixar o professor escrever considerações a qualquer momento, até durante a banca.

**Decisões do professor Afonso:**

- Sem e-mail nem SMTP: a página gera o link e o token para a coordenação copiar e mandar.
- A coordenação copia as considerações e repassa aos alunos por conta própria.
- O texto do professor não trava: pode ser editado sempre.

**O que existe:**

- `pages/tcc2/entrega/coordenacao.html`: coluna Banca; diálogo para alocar professor (gera convite com
  link e token), gerar novo token, remover e copiar as considerações de todos.
- `pages/tcc2/entrega/banca.html`: o professor entra com o token, abre o PDF e escreve as considerações
  com salvamento automático.
- `postgrest/hubbanca.sql`: tabela `hubbanca_avaliadores` e funções `hubbanca_*`. Também redefine
  `hubdeposito_coordenacao` para devolver o slug da turma.
- Token do professor: `<codigo>-<segredo>`, com o hash no banco. Token perdido se troca.

Testado pela API e no navegador com um depósito fictício, depois apagado. O professor Afonso também
testou e aprovou.

## 3. Acompanhamento do TCC1 2027.1

Commit `1838543`.

**Pedido:** replicar para o TCC1 2027.1 a estrutura de depósito e banca, mais o acompanhamento dos
orientadores, a alocação de orientadores pela coordenação e um painel para o aluno ver status,
orientador, notícias e ajustes. Só para 2027.1.

**Correções do professor Afonso à primeira proposta:**

- Grupos e orientadores **não existem antes**: nascem na entrega de acompanhamento, no fim do primeiro
  mês de aulas (Semana 8 da home).
- O TCC é individual, em dupla ou em trio.
- Quem aloca os orientadores é o Tiago (coordenação).
- No formulário, o aluno escolhe o orientador num dropdown com os professores cadastrados pela
  coordenação, informa os integrantes e sobe o PDF da primeira versão.
- O orientador tem página com token própria, registra considerações e libera ou não o aluno para a
  banca, com avaliação **grave, esperado ou supera**, dada várias vezes e guardada em histórico.

**Fluxo construído:**

1. A coordenação cadastra os professores (cada um recebe link e token para o semestre todo, que valem
   para orientação e banca) e abre a entrega.
2. Entrega de acompanhamento (`entrega.html`): título, 1 a 3 integrantes, orientador da lista, PDF. O
   comprovante mostra o token do painel do aluno.
3. A coordenação confirma o orientador indicado ou troca.
4. O orientador (`professor.html`) registra considerações com avaliação e decide a liberação; não
   liberar exige comentário ao aluno.
5. A coordenação aloca a banca; os professores escrevem; a coordenação libera o texto ao aluno.
6. O aluno (`aluno.html`) vê orientador, andamento, histórico, liberação, banca, versões do PDF (nova
   versão e, quando aberta, a final) e os avisos da disciplina.

**Arquivos:**

- `pages/tcc1/acompanhamento/{entrega,aluno,professor,coordenacao}.html`
- `js/hubtcc.js`: helpers comuns das quatro páginas.
- `js/api_aulas.js`: agora tem dois baldes, `hub-tcc2-depositos` e `hub-tcc`.
- `postgrest/hubtcc.sql`: tabelas e funções `hubtcc_*`, separadas por edição (`tcc1-2027-1`).
- `pages/home_tcc1_2027_1.html`: botão Entregar na Semana 8, Meu painel na Semana 26 e dois atalhos
  no topo.

**Escolhas de projeto:**

- Banco separado por **edição**: o TCC2 de 2027.2 reaproveita as páginas trocando `data-edicao` e
  inserindo a edição em `hubtcc_edicoes`.
- Um token por professor, não por banca.
- PDFs em `hubtcc_arquivos`, fora de `hubdeposito_arquivos`, porque a limpeza do TCC2 apaga arquivo que
  não está em `hubdeposito_respostas`.

**Validação:** 36 verificações pela API (regras e bloqueios) e o fluxo inteiro nas quatro páginas com
Playwright, aluno em tela de celular, sem erros. `npm test` com 4373 testes verdes. Dados de teste
apagados; em produção a edição está com a entrega fechada e sem professores.

## 4. Como operar

- **Antes da Semana 8:** a coordenação cadastra os professores em
  `pages/tcc1/acompanhamento/coordenacao.html` e só depois abre a entrega.
- **Aplicar SQL na VPS:** `postgrest/hubbanca.sql` antes de `postgrest/hubtcc.sql`, com `psql` no
  container do Postgres (ver `postgrest/README.md`). Os dois são idempotentes.
- **Limpar dados de teste:** apagar por nome ou título de teste, nesta ordem: `hubtcc_bancas`,
  `hubtcc_registros`, `hubtcc_versoes`, `hubtcc_arquivos`, `hubtcc_trabalhos`, `hubtcc_professores`.
  Conferir antes o que existe, para não apagar trabalho real.

## 5. Pendências

- A home do TCC1 ainda chama a Semana 8 de "Entrega formal da proposta"; trocar para "Entrega de
  acompanhamento" se for o nome oficial.
- A alteração em `js/api_aulas.js` mantém o caminho do TCC2, mas não houve novo envio real de PDF pela
  entrega do TCC2 depois dela.
- O script de teste ponta a ponta do TCC1 ficou fora do repositório, porque a limpeza exige acesso
  direto ao banco.

## 6. Mensagem para o Tiago (modelo)

> Oi, Tiago, tudo bem?
>
> Os depósitos finais do TCC2 2026.2 ficam em
> https://afonsolelis.github.io/aulas_senac/pages/tcc2/entrega/coordenacao.html. O token de acesso eu
> mando em separado.
>
> A tabela mostra o envio mais recente de cada grupo. Na coluna "Banca", "Alocar banca" pede o nome do
> professor e gera um texto com o link e o token dele, para você copiar e mandar. O token só aparece
> nessa hora; se perder, "Gerar novo token". O professor abre só aquele trabalho e escreve as
> considerações quando quiser, até durante a banca. Em "Gerenciar banca" você lê tudo e usa "Copiar
> considerações" para repassar ao grupo.
>
> Para o TCC1 2027.1, a coordenação fica em
> https://afonsolelis.github.io/aulas_senac/pages/tcc1/acompanhamento/coordenacao.html, com o mesmo
> token. Antes da entrega de acompanhamento, cadastre os professores; a lista de orientadores do
> formulário sai desse cadastro.
