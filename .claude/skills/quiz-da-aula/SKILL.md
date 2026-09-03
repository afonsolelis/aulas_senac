---
name: quiz-da-aula
description: Criar o quiz ao vivo (estilo Kahoot, hospedado no próprio Hub) que abre uma aula cobrando a aula anterior. Use ao pedir "quiz da aula N", "kahoot interno", "quiz de retomada", ou ao criar uma aula nova que precise abrir com revisão. Cobre as oito questões, o seed SQL, as três páginas, o link na home e a validação ponta a ponta.
---

# Quiz da aula

Cada aula do Hub abre com um quiz de **retomada**: oito questões de 90 segundos sobre **a aula anterior**, respondidas no celular e projetadas no telão. No fim, cada aluno recebe os temas que precisa retomar e o professor recebe um relatório por tema, questão e estudante.

A regra que não muda: **a aula N cobra a aula N−1.** Nunca cobre o conteúdo que ainda vai ser dado.

## Antes de escrever qualquer coisa

1. Descubra as duas aulas na home da disciplina (`pages/home_<disciplina>.html`): a aula **alvo** (onde o quiz vai ficar) e a **anterior** (de onde saem as questões). Confira pelo card — título, número e semana.
2. Leia **por inteiro** o slide e o material da aula anterior. Os nomes de arquivo nem sempre batem com o título do card: confirme pelo `href` do card, não pelo palpite.
3. Anote 8 temas testáveis. Prefira o que foi *ensinado com exemplo* — distinções (X × Y), critérios, invariantes, sequências. Descarte o que é puro roteiro operacional.

## As oito questões

O que separa um quiz que ensina de um que decora:

- **Situação, não definição.** Apresente um caso e peça a classificação, o diagnóstico ou a intervenção. "O que é X?" é a pior pergunta possível.
- **Distratores reais.** Cada alternativa errada reproduz uma confusão que a turma comete de verdade (idempotência × lock, sensibilidade × trade-off, cobertura como prova de proteção). Alternativa absurda é alternativa desperdiçada.
- **Sem atalho de forma.** Comprimentos parecidos (nada de a correta ser sempre a mais longa) e a posição da correta distribuída entre A, B, C e D — com 8 questões, duas de cada.
- **Explicação que ensina.** Dois ou três períodos: por que a correta está certa **e** por que o distrator mais atraente está errado. É o texto que aparece projetado na revelação.
- **`tema` e `secao` em toda questão.** São eles que viram o relatório "o que retomar" — sem isso o quiz vira placar e perde a função pedagógica.
- Oito questões, `segundos = 90`, quatro alternativas.

## Passo a passo

### 1. Seed SQL

Copie o seed mais recente (`supabase/quiz-seed-*.sql`) e troque conteúdo e slug. Convenção do slug: `<assunto-cobrado>-q2-a<NN>` (`caixa-q2-a04` = a Aula 04 cobra as caixas; `atam-q2-a05` = a Aula 05 cobra o ATAM). O arquivo já termina gravando o token do professor — **`080909`, fixo para todas as salas**.

Cabeçalho do seed: registre de onde as questões saíram (caminhos do slide e do material) e o critério dos distratores. Quem for reaproveitar no semestre que vem precisa disso.

Valide o JSON das alternativas antes de rodar:

```bash
python3 - <<'EOF'
import re, json
s = open('supabase/quiz-seed-<arquivo>.sql', encoding='utf-8').read()
for i, b in enumerate(re.findall(r"'(\[.*?\])'::jsonb", s, re.S), 1):
    a = json.loads(b.replace("''", "'"))
    assert len(a) == 4, (i, len(a))
    print(i, [len(x) for x in a])   # comprimentos equilibrados?
EOF
```

### 2. Aplicar no Supabase

O esquema e a função de relatório já existem no projeto `lwamaovuxcevsjfvtqhf`; só o seed precisa rodar. Pela senha do banco (peça ao professor, **nunca** versione):

```bash
PGPASSWORD='<senha>' psql "postgresql://postgres.lwamaovuxcevsjfvtqhf@aws-0-us-west-2.pooler.supabase.com:6543/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/quiz-seed-<arquivo>.sql
```

Sem a senha, entregue o arquivo para colar no SQL Editor do painel. Em projeto novo, rode antes `supabase/quiz-schema.sql`, `supabase/quiz-relatorio.sql`, `supabase/quiz-ingestao.sql` e `supabase/quiz-gabarito.sql` (nessa ordem). A sessão precisa do campo `periodo` (`2026-2`) no `insert into quiz_sessions` — é ele que compõe a `data_tag` do histórico.

### 3. As três páginas

Copie o conjunto mais recente de `pages/<slug>/quiz/` e substitua, em todos os três arquivos:

| Trocar | Por |
|---|---|
| `const SLUG = ... \|\| '<slug-antigo>'` | o slug novo (duas ocorrências no painel: a constante e o `urlDoQuiz`) |
| `aula0X-quiz.html` / `-painel.html` / `-relatorio.html` | os nomes novos, inclusive no `new URL(...)` do QR |
| links de material e slide | os da **aula anterior** (é o que o aluno vai reler) |
| `<title>`, `meta description`, badge de semana, título do cabeçalho | os da aula alvo |
| "material da Aula 0X" nos textos | a aula anterior |

Depois confirme que não sobrou referência antiga:

```bash
grep -c "aula0<antiga>\|<slug-antigo>" pages/<slug>/quiz/aula0<nova>-*.html   # tem que dar 0
```

### 4. Como se chega até lá (não pule)

Um quiz que ninguém acha não existe. São três portas, cada uma para um público — e **nenhuma delas acrescenta um terceiro botão ao card**:

1. **No slide da aula**, topo à direita, um único controle (o deck é a tela de quem projeta):

```html
<div class="position-absolute top-0 end-0 m-4 d-flex gap-2" style="z-index:6">
  <a href="quiz/aula0NN-painel.html" class="btn btn-dark rounded-pill"><i class="fas fa-sliders me-2" aria-hidden="true"></i> Painel do quiz</a>
</div>
```

Nunca mexa no `footer.slide-footer` para isso: ele precisa ter exatamente quatro filhos.

2. **No card do cronograma**, um **chip** ao lado do badge de semana — nunca um botão, que competiria com "Ver slide" e "Ver material":

```html
<a href="qualidade2/quiz/aula0NN-quiz.html"
   class="badge rounded-pill bg-danger-subtle text-danger-emphasis border border-danger-subtle fw-semibold text-decoration-none d-inline-flex align-items-center py-2"
   aria-label="Entrar no quiz ao vivo da Aula NN, com as questões de retomada da aula anterior">
  <i class="fas fa-bolt me-1" aria-hidden="true"></i> Quiz</a>
```

`text-danger-emphasis` não é decoração: `text-danger` sobre `bg-danger-subtle` dá 3,39:1 e reprova no WCAG AA; com emphasis vai a 10,2:1.

3. **Na central** `pages/<slug>/quiz/index.html` — acrescente a sala à lista, com painel, tela do aluno, relatório e slides.

### 5. Material da aula

Abra o material da aula alvo com um aviso curto: que a aula começa com o quiz, o que ele cobra e o link para o material da aula anterior. É o que faz o aluno reler antes de entrar na sala.

### 6. Validar

```bash
node scripts/quiz-e2e.mjs aula0NN <slug-da-sala>            # local, contra o Supabase real
node scripts/quiz-e2e.mjs aula0NN <slug-da-sala> 080909 https://afonsolelis.github.io/aulas_senac/pages/qualidade2/quiz/
npx jest                                                    # logo, links internos, estrutura
```

O script percorre lobby → pergunta → resposta → revelação → encerramento → relatório, confere cronômetro, gabarito, explicação e temas, e **descarta a sala no fim** (`descartar` zera sem arquivar) — nunca deixe jogador de teste no placar da turma nem na série histórica. Ele lê o gabarito pelo painel do professor, então serve para qualquer sala sem edição.

Se a suíte reclamar de link quebrado ou logo ausente, é porque a página nova precisa do logo Senac (`alt` contendo "senac") e de todo `href` relativo resolvendo no disco.

### 7. Fechar

Commit com o resumo das questões e do que foi validado, e push — a turma acessa pelo GitHub Pages, então sem push não existe quiz.

## Conduzir em aula

Painel → token `080909` → projetar o lobby com o QR → `Abrir pergunta` → discutir a distribuição na revelação → repetir → `Encerrar sessão` → `Relatório` → `Reiniciar`, que abre a confirmação com **Baixar CSV** antes de apagar. O reinício **arquiva sozinho** a rodada em `quiz_relatorios` e diz quantas respostas guardou; o CSV é conveniência, não seguro.

## Armadilhas conhecidas

- **Não nomeie os arquivos `slide_*.html`** dentro de `pages/<slug>/quiz/`: o `specs/slide-structure.spec.js` passaria a exigir capa, agenda e rodapé de quatro filhos.
- O relatório mostra um item por `tema` distinto: temas repetidos entre questões se fundem numa linha só.
- A aba **Perguntas e gabarito** do relatório (RPC `quiz_gabarito`, exige token) lista as oito questões com a
  correta e a explicação — é por ali que se confere o quiz antes da aula, sem abrir pergunta por pergunta.
- A chave publicável do Supabase fica escrita no HTML — é pública por desenho, quem limita o alcance é a RLS. A senha do banco, não: ela nunca entra no repositório.
- Reiniciar apaga tudo daquela sala — mas arquiva antes, no histórico. Só reinicie entre turmas, não no meio de uma.

Detalhes do esquema, das RPCs e do desenho de acesso: `supabase/README.md`.
