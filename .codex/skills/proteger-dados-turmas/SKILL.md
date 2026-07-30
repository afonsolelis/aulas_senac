---
name: proteger-dados-turmas
description: Proteger dados pessoais nas páginas públicas de turmas do Hub de Aulas Senac. Usar sempre que cadastrar, importar, editar, revisar ou exibir alunos, nomes, matrículas, listas de chamada ou outros dados de turma em HTML, JSON, testes, documentação ou exemplos do projeto.
---

# Proteger dados das turmas

Tratar todo conteúdo do repositório e do site como público. Nunca gravar dados pessoais completos, nem temporariamente, em arquivos versionados.

## Mascarar antes de escrever

Aplicar estas regras aos dados recebidos fora do repositório:

- Nome: preservar as duas primeiras letras do primeiro nome e somente a primeira letra dos demais nomes; substituir cada caractere ocultado por `*`.
- Matrícula: preservar somente os três últimos caracteres; substituir todos os anteriores por `*`.
- Nome com um único caractere: substituir por `*`.
- Matrícula com até três caracteres: preservar somente o último e mascarar os anteriores.
- E-mail, telefone, CPF, endereço, data de nascimento e outros identificadores: não publicar.

Exemplos fictícios:

| Entrada privada | Saída permitida |
|---|---|
| `Mariana Souza Lima` | `Ma***** S**** L***` |
| `Jo Li` | `Jo L*` |
| `202612345` | `******345` |
| `AB7` | `**7` |

Nunca incluir a entrada privada em comentários, atributos HTML, JavaScript, fixtures, snapshots, mensagens de commit ou documentação.

## Atualizar páginas

1. Trabalhar somente com os valores já mascarados.
2. Usar os cabeçalhos `Nome mascarado` e `Matrícula mascarada`.
3. Não adicionar links ou atributos que revelem o dado original.
4. Manter apenas informações acadêmicas necessárias à operação da turma.
5. Preservar os placeholders quando os dados mascarados ainda não estiverem disponíveis.

## Validar antes de publicar

1. Revisar o diff completo procurando nomes ou matrículas integrais.
2. Confirmar que cada nome contém `*`.
3. Confirmar que cada matrícula mostra no máximo os três últimos caracteres e contém `*`.
4. Rodar `npm test`.
5. Interromper a publicação se houver dúvida sobre identificação ou exposição de um aluno.
