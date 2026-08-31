# Táticas Arquiteturais de Len Bass — análise completa para ATAM

**Disciplina:** Qualidade de Software · 2026.2 · Senac
**Aula:** 04 — Arquitetura e Análise ATAM com IA Agêntica
**Case de aula:** Foot Fanatics (API de conteúdo esportivo com assinatura)
**Projeto avaliado:** Organização de Recursos (alocação de salas, professores e materiais sem conflito)
**Referência primária:** BASS, L.; CLEMENTS, P.; KAZMAN, R. *Software Architecture in Practice*. 3ª ed. (2013, caps. 5–11) e 4ª ed. (2021). Addison-Wesley.

> **Cobertura:** as seções 4.1 a 4.7 reproduzem integralmente o catálogo da 3ª edição — sete atributos, todas as famílias e todas as táticas nomeadas por Bass, Clements e Kazman. A seção 4.8 é um acréscimo da 4ª edição e está marcada como tal.

---

## Sumário

1. [Como usar este documento](#1-como-usar-este-documento)
2. [O que é uma tática arquitetural](#2-o-que-é-uma-tática-arquitetural)
3. [A ponte: cenário de atributo de qualidade](#3-a-ponte-cenário-de-atributo-de-qualidade)
4. [Catálogo analisado por atributo de qualidade](#4-catálogo-analisado-por-atributo-de-qualidade)
   - [4.1 Disponibilidade](#41-disponibilidade-availability)
   - [4.2 Interoperabilidade](#42-interoperabilidade-interoperability)
   - [4.3 Modificabilidade](#43-modificabilidade-modifiability)
   - [4.4 Desempenho](#44-desempenho-performance)
   - [4.5 Segurança](#45-segurança-security)
   - [4.6 Testabilidade](#46-testabilidade-testability)
   - [4.7 Usabilidade](#47-usabilidade-usability)
   - [4.8 Atributos acrescentados na 4ª edição](#48-atributos-acrescentados-na-4ª-edição)
5. [Tabela-síntese: tática → trade-off → evidência de teste](#5-tabela-síntese-tática--trade-off--evidência-de-teste)
6. [Táticas dentro do ATAM](#6-táticas-dentro-do-atam)
7. [Aplicação no case de aula: Foot Fanatics](#7-aplicação-no-case-de-aula-foot-fanatics)
8. [Aplicação no projeto avaliado: Organização de Recursos](#8-aplicação-no-projeto-avaliado-organização-de-recursos)
9. [Checklist de uso na análise](#9-checklist-de-uso-na-análise)
   - [9.1 Apêndice: categorias, relações e trade-offs recorrentes](#91-apêndice--categorias-relações-e-trade-offs-recorrentes)
10. [Referências](#10-referências)

---

## 1. Como usar este documento

Este documento é um **catálogo de trabalho**, não um resumo para leitura passiva. Na análise ATAM ele cumpre três funções:

| Momento do ATAM | Como o catálogo entra |
|---|---|
| Apresentar as abordagens arquiteturais | Nomear a tática usada em cada decisão, em vez de descrever a implementação. |
| Analisar cenários prioritários | Perguntar, para cada cenário da utility tree, **qual tática responde por ele** — e o que acontece se ela não existir. |
| Registrar descobertas | Toda tática carrega um custo. Esse custo é o candidato natural a **ponto de sensibilidade** ou **trade-off**. |

**Regra de uso:** uma decisão arquitetural sem tática nomeada é uma decisão sem justificativa explícita. Uma tática sem cenário associado é otimização especulativa.

---

## 2. O que é uma tática arquitetural

Bass define tática como uma **decisão de projeto que influencia a resposta do sistema a um estímulo, visando um único atributo de qualidade**. Três consequências práticas:

1. **Tática ≠ padrão arquitetural.** Um padrão (camadas, microsserviços, publish-subscribe) é um pacote de várias táticas com estrutura definida. A tática é o átomo; o padrão é a molécula. *Circuit breaker* é padrão; as táticas dentro dele são **Timeout**, **Degradação** e **Monitoramento**.
2. **Tática é focada em um atributo.** Isso é o que a torna útil no ATAM: quando duas táticas de atributos diferentes competem pelo mesmo recurso, você achou um trade-off.
3. **Tática não é gratuita.** Cada uma tem custo em complexidade, latência, dinheiro ou testabilidade. O catálogo abaixo registra esse custo explicitamente.

```
Estímulo  ──►  [ Arquitetura + Táticas ]  ──►  Resposta (medida)
                        │
                        └── cada tática altera a resposta a um custo
```

---

## 3. A ponte: cenário de atributo de qualidade

Táticas só se tornam avaliáveis quando ligadas a um cenário de seis partes. É a estrutura que a aula usa e a mesma que Bass propõe:

| Parte | Pergunta | Papel na escolha da tática |
|---|---|---|
| **Fonte** | Quem ou o que provoca? | Define se a tática é interna (autoteste) ou de fronteira (autenticação). |
| **Estímulo** | O que acontece? | Falha, pico de carga, ataque, mudança, tentativa de uso. |
| **Ambiente** | Em qual condição? | Operação normal, degradada, sob manutenção, com dependência indisponível. |
| **Artefato** | O que é afetado? | Delimita onde a tática é aplicada (componente, dado, canal, processo). |
| **Resposta** | O sistema faz o quê? | É exatamente a categoria de tática: detectar, resistir, recuperar, prevenir. |
| **Métrica** | Como saberemos? | Vira o critério de aceite do teste automatizado. |

> **Sem métrica não há tática avaliável.** "O sistema deve ser confiável" não seleciona tática nenhuma. "Falha do provedor externo é detectada em ≤ 2 s e respondida com cache de até 15 min" seleciona **Timeout** + **Degradação**.

---

## 4. Catálogo analisado por atributo de qualidade

As tabelas seguem a estrutura analítica usada na tese: **tática → categoria → o que ela controla → atributo primário → custo/trade-off → como verificar**.

---

### 4.1 Disponibilidade (Availability)

**Definição operacional:** disponibilidade trata de **falhas** — quando um erro se propaga para além da fronteira do componente e se torna observável. As quatro categorias formam um ciclo: detectar → recuperar → prevenir.

#### 4.1.1 Detectar falhas

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Ping/Echo** | Um componente pergunta a outro se ele responde, dentro de um prazo. | Tráfego adicional; falso positivo sob latência de rede. | Teste de integração com dependência derrubada (Testcontainers `stop()`). |
| **Monitor** | Componente dedicado observa saúde do sistema (processos, filas, recursos). | O monitor vira ponto único de falha; precisa ser monitorado. | Verificação de health endpoint e alerta disparado. |
| **Heartbeat** | O componente monitorado emite sinal periódico; a ausência indica falha. | Intervalo curto = detecção rápida + custo; longo = detecção tardia. | Teste que suspende o emissor e mede tempo até a detecção. |
| **Timestamp** | Marca eventos com tempo/sequência para detectar ordem incorreta em sistemas distribuídos. | Exige relógio confiável ou contador lógico. | Teste de ordenação com eventos fora de ordem. |
| **Sanity Checking (verificação de sanidade)** | Valida se saída ou estado é plausível segundo conhecimento do domínio. | Requer modelo de domínio explícito; pode rejeitar caso legítimo raro. | Testes de propriedade e casos-limite. |
| **Condition Monitoring** | Verifica invariantes e condições do processo (checksums, contadores). | Custo em cada operação; a própria checagem pode conter defeito. | Assertivas executáveis em ambiente de teste. |
| **Voting (redundância replicada, funcional ou analítica)** | Múltiplas versões calculam o mesmo resultado; a divergência revela falha. | Caro (2–3× recursos); replicação idêntica não detecta bug comum. | Teste com implementação alternativa injetada. |
| **Exception Detection** — *system exception, parameter fence, parameter typing, timeout* | Detecta condição que altera o fluxo normal de execução. | *Parameter fence* consome memória; *timeout* mal calibrado gera falso positivo. | Testes de contrato de API e injeção de latência (WireMock delay). |
| **Self-Test** | O componente executa rotina própria de verificação, sob demanda ou periodicamente. | Consome recurso em produção; pode mascarar erro se for superficial. | Execução programada da rotina em ambiente de homologação. |

#### 4.1.2 Recuperar de falhas — preparação e reparo

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Active Redundancy (hot spare)** | Réplicas processam tudo em paralelo; troca é quase instantânea. | Custo total de infraestrutura duplicado; exige sincronismo estrito. | Teste de failover com medição de tempo de indisponibilidade. |
| **Passive Redundancy (warm spare)** | A réplica recebe atualizações periódicas de estado e assume na falha. | Janela de perda de estado entre sincronizações. | Teste de failover verificando perda máxima de dados. |
| **Spare (cold spare)** | Recurso reserva ligado apenas quando necessário. | Recuperação lenta (minutos); mais barato. | Ensaio de recuperação cronometrado. |
| **Exception Handling** | Trata a exceção detectada: corrige, reporta ou mascara. | Tratamento genérico esconde defeito; virou fonte de bug silencioso. | Testes que exigem exceção específica, não `catch (Exception)`. |
| **Rollback** | Retorna a um estado bom conhecido após falha. | Precisa de checkpoint e de operações reversíveis. | Teste transacional com falha injetada no meio da operação. |
| **Software Upgrade** | Atualiza executável em serviço, sem parar (in-service upgrade). | Complexidade alta; exige compatibilidade entre versões. | Teste de compatibilidade de contrato entre versões N e N+1. |
| **Retry** | Repete a operação supondo falha transitória. | Amplifica carga na falha; sem idempotência, duplica efeitos. | Teste de idempotência com repetição forçada. |
| **Ignore Faulty Behavior** | Ignora mensagens de uma fonte considerada espúria. | Risco de ignorar sinal verdadeiro. | Teste com fonte marcada como ruidosa. |
| **Degradation (degradação graciosa)** | Mantém funções críticas e desliga as menos importantes. | Exige classificação de criticidade acordada com o negócio. | Teste de modo degradado com dependência indisponível. |
| **Reconfiguration** | Reatribui responsabilidades aos recursos que continuam funcionando. | Complexidade de coordenação; pode induzir instabilidade. | Ensaio de perda de nó com verificação de reatribuição. |

#### 4.1.3 Recuperar de falhas — reintrodução

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Shadow** | Componente reparado opera em modo sombra antes de voltar ao serviço. | Duplica processamento durante a janela de observação. | Comparação de saídas sombra × produção. |
| **State Resynchronization** | Ressincroniza o estado do componente reintroduzido. | Custo proporcional ao volume de estado. | Teste de convergência de estado após reingresso. |
| **Escalating Restart** | Reinicia no menor nível possível, escalando só se necessário. | Exige granularidade de reinício projetada desde o início. | Ensaio por nível: thread → processo → nó. |
| **Non-Stop Forwarding** | Separa plano de controle e plano de dados; o dado continua fluindo durante falha do controle. | Arquitetura mais complexa; típica de rede. | Teste de continuidade de tráfego durante falha do controle. |

#### 4.1.4 Prevenir falhas

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Removal from Service** | Retira o componente proativamente para manutenção (ex.: reinício preventivo contra vazamento de memória). | Reduz capacidade durante a janela; exige automação. | Ensaio de manutenção sem impacto perceptível. |
| **Transactions** | Agrupa operações em unidade atômica (ACID) para evitar estado inconsistente. | Custo de lock e contenção; limita escalabilidade. | Teste de concorrência com transações competindo. |
| **Predictive Model** | Monitora tendências para prever falha antes que ocorra. | Falsos positivos; exige histórico. | Validação do modelo com dados históricos. |
| **Exception Prevention** | Evita a exceção na origem (tipos seguros, *smart pointers*, wrappers). | Restringe expressividade; custo em tempo de projeto. | Análise estática e verificação de tipos. |
| **Increase Competence Set** | Amplia o conjunto de estados que o componente sabe tratar como normais. | Aumenta complexidade do componente. | Testes de casos antes tratados como excepcionais. |

> **Trade-off recorrente:** toda tática de disponibilidade compra tolerância pagando com **recursos, latência ou complexidade**. É o principal gerador de pontos de trade-off contra desempenho e custo no ATAM.

---

### 4.2 Interoperabilidade (Interoperability)

**Definição operacional:** capacidade de dois ou mais sistemas trocarem informação com significado preservado, e usarem a informação trocada.

| Tática | Categoria | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|---|
| **Discover Service** | Localizar | Encontra o serviço em tempo de execução por diretório/registro. | Introduz dependência do registro; latência extra na resolução. | Teste com registro indisponível e com serviço movido. |
| **Orchestrate** | Gerenciar interfaces | Coordena a sequência de chamadas entre serviços (workflow, BPEL, saga). | O orquestrador concentra conhecimento e vira gargalo/ponto único. | Teste de fluxo ponta a ponta com falha em uma etapa. |
| **Tailor Interface** | Gerenciar interfaces | Adiciona/remove capacidade da interface sem alterar a API (interceptadores, filtros, tradução). | Comportamento implícito difícil de depurar. | Teste de contrato antes e depois do interceptador. |

> **Leitura para a aula:** a integração com fonte esportiva externa é interoperabilidade pura. A ausência de **Tailor Interface** costuma aparecer no ATAM como risco: qualquer mudança do provedor externo vaza para o domínio interno.

---

### 4.3 Modificabilidade (Modifiability)

**Definição operacional:** custo e risco de mudar. Bass organiza as táticas por **acoplamento, coesão, tamanho e momento do binding**.

| Tática | Categoria | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|---|
| **Split Module** | Reduzir tamanho | Divide módulo grande em partes com responsabilidade menor. | Mais módulos = mais integração e navegação. | Métrica de tamanho/complexidade (SonarCloud). |
| **Increase Semantic Coherence** | Aumentar coesão | Agrupa no mesmo módulo o que muda pela mesma razão. | Exige entender as razões de mudança do domínio. | Análise de coocorrência de mudanças no histórico do Git. |
| **Encapsulate** | Reduzir acoplamento | Interface explícita esconde detalhes internos. | Indireção; pode esconder custo de desempenho. | Teste que só usa a interface pública. |
| **Use an Intermediary** | Reduzir acoplamento | Quebra dependência direta (broker, adapter, façade, DI). | Latência e complexidade; dificulta rastrear fluxo. | Teste com implementação substituta injetada. |
| **Restrict Dependencies** | Reduzir acoplamento | Limita com quem cada módulo pode falar (camadas, módulos JPMS). | Pode gerar rodeios e código de passagem. | Teste de arquitetura (ArchUnit) verificando as regras. |
| **Refactor** | Reduzir acoplamento | Elimina duplicação e responsabilidade dispersa. | Exige rede de testes antes; risco se feito sem cobertura. | Cobertura JaCoCo estável antes/depois. |
| **Abstract Common Services** | Reduzir acoplamento | Extrai o que é comum para um serviço parametrizável. | Abstração prematura acopla clientes ao denominador comum. | Teste dos clientes contra o serviço abstrato. |
| **Defer Binding** | Adiar decisão | Move a decisão para build, deploy, inicialização ou execução (configuração, plugins, feature flags). | Mais flexibilidade = mais caminhos possíveis = mais testes e mais falhas em produção. | Matriz de teste por configuração relevante. |

**Defer Binding — mecanismos por momento de binding.** Bass organiza a tática pelo instante em que o valor é amarrado; quanto mais tarde, menor o custo de mudar depois e mais caro o mecanismo. A regra de decisão é econômica:

> `N × custo_da_mudança_sem_mecanismo  ≥  custo_de_instalar_o_mecanismo + N × custo_da_mudança_com_mecanismo`

| Momento do binding | Mecanismos | Quem passa a poder mudar |
|---|---|---|
| Compilação / build | Substituição de componente no script de build, parametrização em tempo de compilação, *aspects* | Desenvolvedor, sem tocar no módulo cliente |
| Implantação (deploy) | Binding por configuração de implantação | Equipe de operação |
| Inicialização | Arquivos de recurso lidos no startup | Instalador ou administrador |
| Execução | Registro em runtime, *dynamic lookup*, interpretação de parâmetros, *name servers*, plug-ins, publish-subscribe, repositórios compartilhados, polimorfismo | Usuário ou outro sistema, sem novo deploy |

> **Direção de uso:** *externalizar a mudança* — instalar o mecanismo permite que **outro stakeholder** (instalador, operador, usuário) faça a alteração sem alterar código.

> **Trade-off clássico:** modificabilidade compra flexibilidade com **indireção**, e indireção custa desempenho e testabilidade. No ATAM, "usar um intermediário" quase sempre vira ponto de sensibilidade quando existe cenário de latência apertada.

---

### 4.4 Desempenho (Performance)

**Definição operacional:** capacidade de atender eventos dentro de restrições de tempo. O tempo de resposta é sempre **tempo de processamento + tempo bloqueado**; as táticas atacam um dos dois.

#### 4.4.1 Controlar a demanda por recursos

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Manage Sampling Rate** | Reduz a frequência de amostragem/captura de eventos. | Perda de fidelidade da informação. | Teste comparando resultado em taxas diferentes. |
| **Limit Event Response** | Impõe teto de eventos processados (throttling, rate limit). | Eventos descartados ou enfileirados; afeta usabilidade. | Teste de carga (JMeter) atingindo o limite. |
| **Prioritize Events** | Trata eventos críticos primeiro. | Inanição da fila de baixa prioridade. | Teste de carga misto verificando latência por classe. |
| **Reduce Overhead** | Elimina intermediários e indireção do caminho crítico. | Colide frontalmente com modificabilidade. | Perfilamento antes/depois. |
| **Bound Execution Times** | Limita o tempo gasto por evento. | Resposta parcial ou aproximada. | Teste com timeout e verificação da saída degradada. |
| **Increase Resource Efficiency** | Melhora algoritmo/estrutura de dados no caminho crítico. | Esforço concentrado; ganho limitado ao trecho. | Benchmark do trecho isolado. |

#### 4.4.2 Gerenciar recursos

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Increase Resources** | Mais CPU, memória, rede, réplicas. | Custo financeiro direto; nem sempre escala linearmente. | Teste de carga com dimensionamentos diferentes. |
| **Introduce Concurrency** | Processa em paralelo o que era sequencial. | Condições de corrida, deadlock, não determinismo — ataca testabilidade. | Teste de concorrência e detecção de corrida. |
| **Maintain Multiple Copies of Computations** | Réplicas de serviço atrás de balanceador. | Exige ausência de estado local ou sessão distribuída. | Teste com múltiplas instâncias e afinidade desligada. |
| **Maintain Multiple Copies of Data** | Cache e réplicas de leitura. | **Consistência eventual** — o maior trade-off do catálogo. | Teste de invalidação e de leitura obsoleta. |
| **Bound Queue Sizes** | Limita a fila de eventos pendentes. | Perda de eventos ao encher; exige política de descarte. | Teste de saturação verificando comportamento no limite. |
| **Schedule Resources** | Política de escalonamento (FIFO, prioridade fixa, dinâmica). | Complexidade e risco de inanição. | Teste de latência por classe sob carga. |

**Schedule Resources — variantes de política.** Uma política de escalonamento combina *atribuição de prioridade* + *despacho*, arbitrando entre critérios competitivos: uso ótimo do recurso, importância semântica, latência, throughput, justiça e ausência de inanição.

| Política | Critério de prioridade | Consequência |
|---|---|---|
| **FIFO** | Nenhum — todos os pedidos são iguais | Simples; um pedido longo atrasa todos os seguintes |
| **Prioridade fixa — importância semântica** | Importância atribuída no projeto | Pedido crítico sempre passa na frente; risco de inanição |
| **Prioridade fixa — *deadline monotonic*** | Prazo mais curto tem prioridade maior | Adequado a tarefas periódicas com prazo ≠ período |
| **Prioridade fixa — *rate monotonic*** | Período mais curto tem prioridade maior | Ótima entre as políticas de prioridade fixa para tarefas periódicas |
| **Dinâmica — *round-robin*** | Rodízio entre pedidos | Justa; ruim para prazos apertados |
| **Dinâmica — *earliest deadline first*** | Prazo absoluto mais próximo | Melhor aproveitamento; custo de recálculo constante |
| **Dinâmica — *least slack first*** | Menor folga restante | Sensível a estimativas de tempo restante |
| **Estática (executivo cíclico)** | Agendamento definido offline | Elimina o custo do escalonador; rígido a mudanças |

> **Trade-off recorrente:** cache (**Maintain Multiple Copies of Data**) melhora desempenho e disponibilidade, mas cria janela de dado obsoleto — que pode ser problema de **segurança** quando o dado é permissão ou status de assinatura. Esse é o exemplo canônico de ponto de trade-off para a aula.

---

### 4.5 Segurança (Security)

**Definição operacional:** proteger a informação contra acesso ou modificação não autorizados, preservando confidencialidade, integridade e disponibilidade (CIA). O ciclo é detectar → resistir → reagir → recuperar.

#### 4.5.1 Detectar ataques

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Detect Intrusion** | Compara tráfego/comportamento com assinaturas ou padrões conhecidos. | Falsos positivos; base de assinaturas envelhece. | Teste com payloads maliciosos conhecidos. |
| **Detect Service Denial** | Compara padrão de tráfego com perfil de negação de serviço. | Pode bloquear pico legítimo. | Teste de carga distinguindo pico legítimo de abuso. |
| **Verify Message Integrity** | Checksums, hashes e assinaturas em mensagens. | Custo criptográfico por mensagem. | Teste com mensagem adulterada. |
| **Detect Message Delivery Anomalies** | Detecta atraso/variação suspeita (possível ataque *man-in-the-middle*). | Ruído de rede gera alarme falso. | Teste com latência injetada. |

#### 4.5.2 Resistir a ataques

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Identify Actors** | Identifica a origem de qualquer entrada externa. | Rastreabilidade × privacidade (LGPD). | Teste de log de origem sem dado pessoal excedente. |
| **Authenticate Actors** | Garante que o ator é quem afirma ser (senha, MFA, certificado, token). | Atrito de usabilidade; MFA reduz conversão. | Teste de autenticação positivo e negativo. |
| **Authorize Actors** | Garante que o ator autenticado pode fazer aquilo (RBAC/ABAC). | Complexidade do modelo de permissões. | Matriz papel × endpoint em teste automatizado. |
| **Limit Access** | Reduz superfície: firewall, DMZ, portas fechadas, rede privada. | Dificulta operação e diagnóstico legítimos. | Teste de varredura de portas/superfície. |
| **Limit Exposure** | Distribui e minimiza o que cada componente pode expor se comprometido. | Mais componentes, mais custo operacional. | Revisão de blast radius por componente. |
| **Encrypt Data** | Cifra dados em trânsito e em repouso. | Custo de CPU e gestão de chaves (novo ponto único). | Teste de transporte (TLS obrigatório) e de repouso. |
| **Separate Entities** | Separa por servidor, rede, container ou máquina virtual. | Custo de infraestrutura e latência entre entidades. | Teste de isolamento entre contextos. |
| **Change Default Settings** | Elimina credenciais e configurações padrão. | Trivial de fazer, trivial de esquecer. | Verificação automatizada em pipeline. |

#### 4.5.3 Reagir a ataques

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Revoke Access** | Suspende acesso de ator ou recurso sob suspeita. | Falso positivo bloqueia usuário legítimo. | Teste de revogação e de reativação. |
| **Lock Computer** | Bloqueia após N tentativas falhas. | Vira vetor de negação de serviço contra o usuário. | Teste de bloqueio e desbloqueio. |
| **Inform Actors** | Notifica operadores e usuários afetados. | Excesso de alerta gera dessensibilização. | Teste de disparo de notificação. |

#### 4.5.4 Recuperar de ataques

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Restore** | Restaura o serviço — reutiliza as táticas de disponibilidade. | Restaurar backup comprometido reintroduz o ataque. | Ensaio de restauração a partir de ponto anterior íntegro. |
| **Audit** | Mantém trilha de auditoria das ações dos atores. | Volume de log; a própria trilha vira dado sensível. | Teste de completude e imutabilidade da trilha. |

> **Trade-off recorrente:** segurança compra proteção pagando com **usabilidade e desempenho**. Autenticar, autorizar e cifrar em cada requisição é o caso mais comum de conflito com um cenário de latência.

---

### 4.6 Testabilidade (Testability)

**Definição operacional:** facilidade com que o software revela suas falhas quando testado. Bass estima 30–50% do custo de desenvolvimento em teste — testabilidade é economia direta. Duas categorias: controlar/observar estado e limitar complexidade.

#### 4.6.1 Controlar e observar o estado do sistema

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Specialized Interfaces** | Interface dedicada para inspecionar/definir estado durante o teste. | Superfície extra que **não pode** vazar para produção — vira risco de segurança. | Teste que usa a interface + verificação de que ela está desligada em produção. |
| **Record/Playback** | Grava a informação que cruza a interface e a reproduz no teste. | Cassetes envelhecem e escondem mudança do provedor real. | Reprodução com cassete + execução periódica contra o real. |
| **Localize State Storage** | Concentra o estado para poder colocar o sistema num estado conhecido. | Restringe distribuição do estado. | Teste que parte de estado conhecido e determinístico. |
| **Abstract Data Sources** | Substitui a fonte de dados real por dublê. | Dublê divergente do real produz teste verde e produção vermelha. | Contrato verificado contra a fonte real periodicamente. |
| **Sandbox** | Isola a execução do mundo real (tempo, dinheiro, dados). | Simulação diverge da realidade; custo de manter o ambiente. | Testcontainers/ambiente efêmero por execução. |
| **Executable Assertions** | Assertivas no código verificam invariantes durante a execução. | Custo em tempo de execução; ruído se mal posicionadas. | Execução com assertivas ligadas em ambiente de teste. |

#### 4.6.2 Limitar a complexidade

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Limit Structural Complexity** | Reduz acoplamento e dependências cíclicas; isola o domínio. | Coincide com as táticas de modificabilidade — reforço mútuo. | Métrica de complexidade e ciclos (SonarCloud). |
| **Limit Nondeterminism** | Elimina não determinismo: concorrência não controlada, relógio, ordem, aleatoriedade, estado compartilhado. | **Conflita diretamente** com "Introduce Concurrency" do desempenho. | Execução repetida da suíte procurando teste instável (*flaky*). |

> **Ponto central da disciplina:** testabilidade é o atributo que transforma todos os outros em algo verificável. Um cenário ATAM sem tática de testabilidade correspondente não tem como virar critério de aceite.

---

### 4.7 Usabilidade (Usability)

**Definição operacional:** facilidade de realizar a tarefa e tipo de suporte oferecido ao usuário. Bass separa o que o **usuário inicia** do que o **sistema inicia**.

**Tática estruturante anterior às duas famílias: separar a interface de usuário.** Como a UI é a parte que mais sofre revisão, Bass recomenda isolá-la do resto do sistema (MVC, Arch/Slinky, Seeheim, PAC). A separação é sustentada por táticas de modificabilidade — **Increase Semantic Coherence**, **Restrict Dependencies** e **Defer Binding** — e é o que torna barato iterar sobre a experiência sem tocar no domínio.

#### 4.7.1 Apoiar a iniciativa do usuário

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Cancel** | O sistema escuta o pedido de cancelamento, libera recursos e informa colaboradores. | Exige operações interrompíveis e limpeza consistente. | Teste de cancelamento no meio da operação, sem estado órfão. |
| **Undo** | Mantém histórico suficiente para reverter. | Custo de memória/armazenamento do histórico; nem tudo é reversível. | Teste de desfazer em sequência de N passos. |
| **Pause/Resume** | Suspende e retoma operação longa, liberando recursos temporariamente. | Complexidade de estado suspenso. | Teste de pausa/retomada preservando progresso. |
| **Aggregate** | Trata coleção de objetos como um só, aplicando a operação em lote. | Erro em lote tem consequência ampliada. | Teste de operação em lote com falha parcial. |

#### 4.7.2 Apoiar a iniciativa do sistema

| Tática | O que controla | Custo / trade-off | Como verificar |
|---|---|---|---|
| **Maintain Task Model** | Modela a tarefa para saber o contexto e ajudar (ex.: autocorreção sensível ao contexto). | Modelo errado atrapalha mais que ajuda. | Teste de comportamento assistivo por cenário de tarefa. |
| **Maintain User Model** | Modela conhecimento, comportamento e ritmo do usuário. | Risco de privacidade e de perfilamento indevido (LGPD). | Teste de personalização + revisão de dado coletado. |
| **Maintain System Model** | Modela o próprio sistema para prever e comunicar comportamento (ex.: tempo restante). | Estimativa errada corrói confiança. | Teste de precisão da previsão exibida. |

> **Trade-off recorrente:** usabilidade colide com segurança (atrito de autenticação) e com desempenho (feedback e histórico custam recursos).

---

### 4.8 Atributos acrescentados na 4ª edição

A 4ª edição (2021) reorganiza o catálogo e acrescenta atributos que a prática de DevOps e sistemas ciberfísicos tornou centrais. **Nada aqui pertence ao catálogo clássico dos capítulos 5–11 da 3ª edição** — é extensão, útil para os cenários de pipeline e implantação que o projeto de vocês vai enfrentar.

#### Implantabilidade (Deployability)

| Tática | Categoria | O que controla | Trade-off |
|---|---|---|---|
| **Scale Rollouts** | Gerenciar o pipeline | Libera para uma fração dos usuários (canário, blue/green) e amplia gradualmente. | Exige convivência de versões e observabilidade fina. |
| **Roll Back** | Gerenciar o pipeline | Retorna à versão anterior quando o indicador piora. | Migração de banco irreversível quebra o rollback. |
| **Script Deployment Commands** | Gerenciar o pipeline | Deploy é código versionado e repetível. | Custo inicial; script vira sistema a manter. |
| **Manage Service Interactions** | Gerenciar o sistema implantado | Controla compatibilidade entre versões coexistentes. | Complexidade de contrato e de roteamento. |
| **Package Dependencies** | Gerenciar o sistema implantado | Empacota o serviço com suas dependências (contêiner, imagem). | Tamanho e gestão de imagem; superfície de vulnerabilidade. |

#### Integrabilidade (Integrability)

| Tática | Categoria | O que controla | Trade-off |
|---|---|---|---|
| **Encapsulate / Use an Intermediary / Restrict Dependencies / Abstract Common Services** | Limitar dependências | Reduz o número e a força das dependências entre sistemas. | As mesmas trocas de modificabilidade: indireção × desempenho. |
| **Discover / Tailor Interface / Configure Behavior** | Adaptar | Ajusta o sistema à interface do outro sem alterar o núcleo. | Comportamento configurável explode a matriz de teste. |
| **Orchestrate / Manage Resources** | Coordenar | Coordena a interação entre sistemas independentes. | Coordenador concentra conhecimento e vira gargalo. |

#### Eficiência energética (Energy Efficiency)

| Tática | Categoria | O que controla | Trade-off |
|---|---|---|---|
| **Metering / Static and Dynamic Classification** | Monitorar recursos | Mede e classifica o consumo por componente. | Instrumentação consome o que mede. |
| **Reduce Usage / Discovery / Scheduling** | Alocar recursos | Desliga, descobre ou escalona recursos conforme demanda. | Religar custa latência (cold start). |
| **Manage Event Arrival / Limit Event Response / Prioritize Events / Reduce Overhead / Bound Execution Times / Increase Efficiency** | Reduzir demanda | Mesmas táticas de desempenho, com objetivo energético. | Menos energia geralmente significa menos desempenho. |

#### Segurança física / Safety

| Tática | Categoria | O que controla | Trade-off |
|---|---|---|---|
| **Substitution, Predictive Model, Timeout, Timestamp, Sanity Checking, Condition Monitoring, Comparison** | Evitar e detectar falhas perigosas | Identifica estado inseguro antes do dano. | Custo de verificação contínua. |
| **Redundancy (replicação, funcional, analítica)** | Conter a falha | Mantém a função apesar da falha. | Custo multiplicado. |
| **Abort, Degradation, Masking, Barrier (firewall, interlock)** | Limitar consequências | Impede que a falha se propague para o mundo físico. | Abortar pode ser, em si, uma condição insegura. |
| **Rollback, Repair State, Reconfiguration, Retry, Ignore Faulty Behavior, Degradation** | Recuperar | Retorna a estado seguro. | Compartilha os custos das táticas de disponibilidade. |

> **Observação de leitura:** *security* protege o sistema do mundo; *safety* protege o mundo do sistema. Muitas táticas se repetem; a diferença está no cenário e na métrica.

---

## 5. Tabela-síntese: tática → trade-off → evidência de teste

Esta é a tabela de trabalho da análise ATAM. Cada linha agrupa as táticas por intenção e nomeia o conflito típico.

| Intenção arquitetural | Táticas representativas | Atributo primário | Conflita tipicamente com | Evidência de teste esperada |
|---|---|---|---|---|
| Perceber que algo quebrou | Ping/Echo, Heartbeat, Monitor, Timeout | Disponibilidade | Desempenho (overhead), custo | Teste de integração com dependência derrubada; medição do tempo de detecção |
| Continuar servindo apesar da falha | Redundância ativa/passiva, Degradação, Reconfiguração | Disponibilidade | Custo, consistência | Teste de failover e de modo degradado |
| Não corromper o estado | Transações, Rollback, Idempotência (via Retry seguro) | Disponibilidade / integridade | Desempenho (lock), escalabilidade | Teste transacional com falha injetada; teste de reexecução |
| Absorver mudança sem efeito cascata | Encapsular, Intermediário, Restringir dependências, Adiar binding | Modificabilidade | Desempenho, testabilidade | Teste de arquitetura (regras de dependência) e de substituição de implementação |
| Responder dentro do prazo | Limitar resposta a eventos, Priorizar, Concorrência, Cache | Desempenho | Consistência, testabilidade, segurança | Teste de carga com percentis (p95/p99) e teste de invalidação de cache |
| Impedir acesso indevido | Autenticar, Autorizar, Cifrar, Limitar acesso e exposição | Segurança | Usabilidade, desempenho | Matriz papel × recurso automatizada; teste negativo por endpoint |
| Saber o que aconteceu | Auditoria, Monitor, Timestamp, Assertivas executáveis | Segurança / disponibilidade | Custo de armazenamento, privacidade | Teste de completude da trilha e de ausência de dado pessoal excedente |
| Tornar o sistema testável | Interfaces especializadas, Sandbox, Abstrair fontes, Limitar não determinismo | Testabilidade | Desempenho (concorrência), segurança (superfície extra) | Suíte determinística repetida N vezes sem falha intermitente |
| Manter o usuário no controle | Cancelar, Desfazer, Pausar/Retomar, Agregar | Usabilidade | Desempenho, complexidade de estado | Teste de cancelamento e desfazer sem estado órfão |
| Entregar com segurança operacional | Rollout gradual, Rollback, Empacotar dependências | Implantabilidade | Complexidade de pipeline, custo | Ensaio de canário e de rollback com migração reversível |

---

## 6. Táticas dentro do ATAM

### 6.1 Onde cada uma entra nos passos do método

| Passo do ATAM | Uso do catálogo |
|---|---|
| 4. Identificar abordagens arquiteturais | Nomear a **tática** por trás de cada abordagem apresentada. |
| 5. Gerar a utility tree | Cada folha é um cenário; anotar a tática candidata ao lado. |
| 6. Analisar as abordagens | Perguntar: a tática cobre o cenário? Qual métrica prova? Qual custo ela impõe? |
| 7–8. Brainstorm e reanálise | Cenários dos stakeholders costumam revelar **táticas ausentes**. |
| 9. Apresentar resultados | Riscos, não-riscos, sensibilidades e trade-offs, todos ancorados em táticas nomeadas. |

### 6.2 Como uma tática vira cada tipo de descoberta

| Descoberta ATAM | Forma típica no catálogo | Exemplo |
|---|---|---|
| **Risco** | Cenário prioritário **sem** tática correspondente. | Existe cenário de falha do provedor externo, mas nenhuma tática de detecção (Timeout/Heartbeat). |
| **Não-risco** | Tática presente, dimensionada e com métrica verificável. | Retry com backoff **e** idempotência comprovada por teste. |
| **Ponto de sensibilidade** | Um parâmetro da tática determina a resposta de um atributo. | O TTL do cache determina sozinho a taxa de acerto e a janela de dado obsoleto. |
| **Ponto de trade-off** | O mesmo parâmetro move dois atributos em direções opostas. | O mesmo TTL: aumentar melhora desempenho e piora a atualidade da permissão de acesso. |
| **Tema de risco** | Padrão que se repete em várias decisões. | Nenhuma decisão de escrita usa transação — ausência sistemática de tática de prevenção. |

### 6.3 Roteiro de pergunta por decisão

Para cada decisão arquitetural, responda em uma linha cada:

1. Qual **tática** de Bass está sendo usada? (nome exato)
2. Qual **cenário** ela atende? (as seis partes)
3. Qual é a **métrica** de resposta?
4. Qual **custo** ela impõe e sobre qual atributo?
5. Qual **teste automatizado** prova que ela funciona?
6. O que acontece se ela **não existir**? (esse é o risco)

---

## 7. Aplicação no case de aula: Foot Fanatics

API de conteúdo esportivo com assinatura — escopos **E1** Identidade & Conta, **E2** Sessão & Acesso, **E3** Assinatura, **E4** Conteúdo. Stack Java 21 + Spring Boot 3, PostgreSQL, JUnit 5, JaCoCo, Testcontainers, WireMock, SonarCloud, JMeter.

| Cenário (resumido) | Tática de Bass | Realização no Foot Fanatics | Trade-off exposto | Evidência de teste |
|---|---|---|---|---|
| A fonte esportiva externa não responde durante a partida | **Timeout** + **Degradação** | Prazo curto na chamada externa; conteúdo servido de cache com marca de defasagem | Atualidade × disponibilidade | WireMock com atraso; teste do modo degradado |
| Assinatura expira durante a sessão ativa | **Authorize Actors** + **Maintain Multiple Copies of Data** (cache de permissão) | Verificação de assinatura no acesso ao conteúdo premium, com TTL curto de cache | **Ponto de trade-off**: TTL alto = rápido e permissivo; TTL baixo = correto e caro | Teste de expiração no meio da sessão |
| Pico de acesso no fim do jogo | **Limit Event Response** + **Prioritize Events** + **Increase Resources** | Rate limit por conta; assinante tem prioridade sobre visitante | Usabilidade do visitante × desempenho do assinante | JMeter com carga mista, percentis por classe |
| Tentativa repetida de login inválido | **Authenticate Actors** + **Lock Computer** + **Audit** | Bloqueio temporário após N tentativas e registro em trilha | Bloqueio vira negação de serviço contra o usuário legítimo | Teste de bloqueio, desbloqueio e trilha |
| Job diário de conteúdo falha no meio | **Retry** (idempotente) + **Rollback** + **Transactions** | Watermark/checkpoint só avança ao concluir; reexecução não duplica | Lock e transação reduzem throughput | Teste de idempotência com falha injetada |
| Trocar o provedor de conteúdo externo | **Tailor Interface** + **Abstract Data Sources** | Adaptador isola o contrato externo do domínio | Indireção extra no caminho crítico | Teste de contrato com dublê e com o real |
| Testar sem depender do provedor | **Sandbox** + **Record/Playback** | Testcontainers para PostgreSQL; WireMock para a API externa | Dublê desatualizado esconde mudança do provedor | Suíte determinística + verificação periódica contra o real |

---

## 8. Aplicação no projeto avaliado: Organização de Recursos

> ⚠️ O Foot Fanatics é o case **das aulas**. O trabalho avaliado das equipes é **Organização de Recursos** — alocação de salas, professores e materiais sem conflito. A técnica é demonstrada no Foot Fanatics; a **aplicação avaliada acontece no projeto da equipe**.

| Cenário (resumido) | Tática de Bass | Realização esperada | Trade-off a registrar no ATAM |
|---|---|---|---|
| Duas reservas simultâneas para a mesma sala | **Transactions** + **Schedule Resources** | Restrição de exclusão no banco e transação na confirmação | Lock reduz concorrência e throughput em horário de pico |
| Cancelar uma reserva já confirmada | **Cancel** + **Undo** + **Rollback** | Cancelamento libera o recurso e restaura disponibilidade | Histórico para desfazer custa armazenamento e complexidade |
| Coordenador altera a grade em massa | **Aggregate** + **Transactions** | Operação em lote com atomicidade por lote | Falha parcial em lote grande tem consequência ampliada |
| Professor sem permissão tenta alocar sala especial | **Authenticate Actors** + **Authorize Actors** | Papéis (professor, coordenador, administrador) com matriz explícita | Modelo de permissão granular aumenta atrito e complexidade |
| Consulta de disponibilidade precisa ser instantânea | **Maintain Multiple Copies of Data** (cache de agenda) | Cache da grade consultada, invalidado a cada reserva | Dado obsoleto pode mostrar sala livre que já foi reservada |
| Regras de alocação mudam a cada semestre | **Defer Binding** + **Encapsulate** | Regras em configuração/estratégia, fora do núcleo | Cada configuração nova multiplica a matriz de teste |
| Auditar quem reservou o quê | **Audit** + **Timestamp** | Trilha imutável de reservas e alterações | Volume de log e exposição de dado pessoal (LGPD) |
| Sistema indisponível na semana de matrícula | **Monitor** + **Degradação** + **Redundância** | Consulta continua disponível mesmo quando a escrita falha | Custo de infraestrutura redundante |

---

## 9. Checklist de uso na análise

Antes de fechar o documento de arquitetura, confirme:

- [ ] Cada atributo de qualidade prioritário tem **pelo menos um cenário** com métrica.
- [ ] Cada cenário prioritário tem **pelo menos uma tática nomeada** que responde por ele.
- [ ] Cada tática tem **custo explícito** registrado (sobre qual atributo, em que grandeza).
- [ ] Cada tática tem **um teste automatizado** que a evidencia — ou está marcada como não verificada.
- [ ] Cenários sem tática estão registrados como **risco**, não omitidos.
- [ ] Táticas sem cenário estão marcadas como **decisão sem requisito correspondente**.
- [ ] Parâmetros que sozinhos determinam a resposta estão marcados como **pontos de sensibilidade**.
- [ ] Parâmetros que movem dois atributos em direções opostas estão marcados como **pontos de trade-off**.
- [ ] Ausências que se repetem em várias decisões estão consolidadas como **temas de risco**.
- [ ] Suposições continuam identificadas como suposições — nenhuma virou fato sem evidência.

---

## 9.1 Apêndice — categorias, relações e trade-offs recorrentes

- **Cada capítulo de táticas parte de um cenário geral** (fonte, estímulo, artefato, ambiente, resposta, medida da resposta) e termina em um *design checklist* organizado por: alocação de responsabilidades, modelo de coordenação, modelo de dados, mapeamento entre elementos arquiteturais, gestão de recursos, momento do binding e escolha de tecnologia.
- **Tática ≠ padrão.** Um padrão arquitetural realiza várias táticas simultaneamente, com trade-offs já fixados. A tática é a primitiva de projeto; o padrão é a combinação.
- **Trade-offs que reaparecem em quase toda avaliação:**

| Tensão | Origem |
|---|---|
| Modificabilidade ↔ Desempenho | Intermediários e separação de responsabilidades custam latência |
| Disponibilidade ↔ Custo | Redundância ativa é cara; reserva fria é barata e lenta |
| Segurança ↔ Usabilidade | Autenticação e autorização adicionam atrito |
| Testabilidade ↔ Desempenho / Segurança | Interfaces de teste e assertivas em produção custam recurso e ampliam superfície |
| Testabilidade ↔ Desempenho | Limitar não determinismo conflita com introduzir concorrência |
| Disponibilidade ↔ Evolução | Tipagem rígida de parâmetros protege em runtime e endurece a interface |

---

## 10. Referências

- BASS, L.; CLEMENTS, P.; KAZMAN, R. **Software Architecture in Practice**. 3ª ed. Upper Saddle River, NJ: Addison-Wesley (SEI Series in Software Engineering), 2013. ISBN 978-0-321-81573-6. *(Capítulos 5–11, pp. 79–184: disponibilidade, interoperabilidade, modificabilidade, desempenho, segurança, testabilidade e usabilidade.)*
- BASS, L.; CLEMENTS, P.; KAZMAN, R. **Software Architecture in Practice**. 4ª ed. Addison-Wesley, 2021. *(Acrescenta implantabilidade, integrabilidade, eficiência energética e safety.)*
- KAZMAN, R.; KLEIN, M.; CLEMENTS, P. **ATAM: Method for Architecture Evaluation**. Technical Report CMU/SEI-2000-TR-004, Software Engineering Institute, 2000.
- CLEMENTS, P.; KAZMAN, R.; KLEIN, M. **Evaluating Software Architectures: Methods and Case Studies**. Addison-Wesley, 2002.
- ISO/IEC 25010 — **Systems and software Quality Requirements and Evaluation (SQuaRE)**: modelo de qualidade de produto.

---

*Material de apoio da Aula 04 — Qualidade de Software 2026.2 · Senac. Uso didático.*
