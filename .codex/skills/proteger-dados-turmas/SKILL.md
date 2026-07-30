---
name: proteger-dados-turmas
description: Proteger dados pessoais nas páginas públicas de turmas do Hub de Aulas Senac. Usar sempre que cadastrar, importar, editar, revisar ou exibir alunos, nomes, matrículas, listas de chamada ou outros dados de turma em HTML, JSON, testes, documentação ou exemplos do projeto.
---

# Proteger dados das turmas

Tratar todo conteúdo do repositório e do site como público. Exibir o nome do aluno somente quando necessário à identificação acadêmica e nunca publicar a matrícula completa.

## Mascarar antes de escrever

Aplicar estas regras aos dados recebidos fora do repositório:

- Nome: pode ser exibido completo.
- Matrícula: preservar somente os três últimos caracteres; substituir todos os anteriores por `*`.
- Matrícula com até três caracteres: preservar somente o último e mascarar os anteriores.
- E-mail, telefone, CPF, endereço, data de nascimento e outros identificadores: não publicar.

Exemplos fictícios:

| Entrada privada | Saída permitida |
|---|---|
| `Mariana Souza Lima` | `Mariana Souza Lima` |
| `202612345` | `******345` |
| `AB7` | `**7` |

Nunca incluir a matrícula completa em comentários, atributos HTML, JavaScript, fixtures, snapshots, mensagens de commit ou documentação.

## Atualizar páginas

1. Mascarar a matrícula antes de escrever qualquer dado do aluno no repositório.
2. Usar os cabeçalhos `Nome` e `Matrícula`; os asteriscos tornam o mascaramento visível.
3. Não adicionar links ou atributos que revelem o dado original.
4. Manter apenas informações acadêmicas necessárias à operação da turma.
5. Preservar os placeholders quando os dados mascarados ainda não estiverem disponíveis.

## Validar antes de publicar

1. Revisar o diff completo procurando matrículas integrais e outros dados pessoais desnecessários.
2. Confirmar que cada matrícula mostra no máximo os três últimos caracteres e contém `*`.
3. Rodar `npm test`.
4. Interromper a publicação se houver dúvida sobre identificação ou exposição de um aluno.
