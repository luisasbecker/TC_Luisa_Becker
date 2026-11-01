# Evolução UX/UI — decisões e arquitetura

Atualizado em 29/10/2026. Documento de preparação; a nova interface e a API descritas abaixo **ainda não foram implementadas**. O aplicativo existente permanece na versão 0.2.1+3. Esta proposta incorpora o prompt de UX e as respostas posteriores da usuária.

## Decisões confirmadas

- Manter o nome **Pipeline Bucal** e criar logo/ícone próprio para instalação no celular.
- A aplicação continua sorteando classe e risco por análise. Exemplos fixos pertencem aos mockups; testes automatizados usam respostas controladas para verificar cada caminho. Não expor escolha de risco no fluxo normal.
- Manter comunicação HTTPS real com Google Cloud Run, inclusive nos novos caminhos. Offline continua explícito; erro de rede não muda o modo automaticamente.
- Preservar a condição de custo financeiro zero. Não ativar conta paga, contratar serviços, criar banco ou ampliar infraestrutura. Antes de qualquer publicação, conferir o estado da avaliação/franquias; as condições observadas em 22/10 não comprovam saldo atual.
- As imagens dos artigos disponibilizados podem aparecer na biblioteca de referência e ser escolhidas pela usuária como entradas de teste, inclusive com envio à cloud. Exibir a origem; consultar a biblioteca não dispara upload. A referência selecionada só segue à cloud como parte de uma análise iniciada explicitamente.
- Criar arquivo Figma dedicado ao TCC com as sete páginas solicitadas. O arquivo foi criado e está referenciado em `design/figma/README.md`; biblioteca, páginas e protótipo ainda não construídos. A conta consultada informa equipe “A equipe de Gilberto Júnior”, plano Starter e assento View; a criação foi possível, sem alteração de plano.
- Adotar menu inferior flutuante conforme a captura indicada. Sua aparência específica e a paleta original aguardam arquivos acessíveis; não foram inferidas.
- Usar seis classes, três riscos categóricos, perguntas demonstrativas e módulos fantasma. Sem modelos de IA reais, treinamento, porcentagem de risco ou regras clínicas inventadas.
- Dados e histórico de uso em memória, com exportação manual JSON. Nenhuma persistência clínica na cloud.

## Organização proposta

Reutilizar `mobile/`, sem criar outra aplicação Flutter paralela. Preservar o trabalho local ainda não commitado e os arquivos acadêmicos originais.

| Área | Responsabilidade |
| --- | --- |
| `design/tokens/` | JSON de valores primitivos, semânticos e modos claro/escuro; origem cromática documentada |
| `design/figma/` | Referência ao arquivo, mapeamento de componentes e documentação da biblioteca |
| `mobile/lib/design_system/` | Tokens derivados, temas e componentes reutilizáveis |
| `mobile/lib/core/models/` | Entradas, resultados e histórico tipados |
| `mobile/lib/core/policies/` | Continuidade na incerteza e invalidação de dados dependentes |
| `mobile/lib/core/services/` | Contratos e cliente HTTPS; adaptadores de simulação |
| `mobile/lib/core/events/` | Registro em memória, relógio injetável, duração e exportação |
| `mobile/lib/features/analysis/` | Controlador da análise e telas por etapa |
| `mobile/lib/features/reference_library/` | Galeria local, visualizador e fontes das imagens |
| `mobile/test/fixtures/` | Respostas controladas e imagens sintéticas para testes e previews |

Usar `ChangeNotifier` com estado tipado e widgets observadores do Flutter, sem acrescentar biblioteca de estado por conveniência. Widgets emitem ações; controlador decide transições, invalidações e chamadas. Não acoplar regras de fluxo aos componentes visuais.

## Navegação e estados

Menu proposto: **Início · Análise · Referências · Sobre**. É uma proposta de organização, não uma reprodução da captura ainda indisponível. A análise vive acima das abas: alternar aba preserva entradas e decisões; voltar a “Análise” retoma a etapa atual. Nova análise, conclusão e abandono são ações explícitas.

| Etapa | Ações e destino |
| --- | --- |
| Início | Nova análise; retomar a análise atual; informações sobre o protótipo |
| Aquisição | Câmera/galeria ou exemplo de referência escolhido; validar arquivo; mostrar prévia |
| Prévia | Confirmar e enviar à detecção; substituir sem enviar a foto anterior |
| Detecção | Aguardar cloud; conferir recorte encontrado ou escolher recuperação se não houver região |
| Recorte | Aprovar; editar sobre a original; enviar outra fotografia |
| Editor | Zoom, mover e redimensionar; confirmar pixels corrigidos e seguir ao foco |
| Sem detecção | Recorte manual ou outra fotografia; nunca seguir sem região válida |
| Qualidade | Aprovar para classificação; rejeitar e retornar à aquisição com motivo registrado |
| Comparação | Galeria da classe sugerida; concordar; discordar e escolher alternativa ou incerteza |
| Questionário | Seções por classe, avanço/retorno, respostas editáveis e progresso |
| Revisão | Conferir respostas e decisão de classe; confirmar envio ao multimodal correspondente |
| Resultado | Risco categórico, orientação demonstrativa, aviso de classe provisória quando aplicável |
| Conclusão | Encerrar explicitamente, exportar histórico ou iniciar nova análise |

Processamento e erro pertencem à operação atual. Uma falha preserva a última etapa válida, mostra mensagem compreensível e oferece nova tentativa. Uma resposta tardia de operação invalidada não deve alterar a tela.

## Incerteza não equivale a concordância

Preservar separadamente `suggestedClass`, `professionalDecision`, `selectedClass` e `effectiveClass`. Para “Não consigo determinar”: decisão `uncertain`, confirmação falsa e classe efetiva igual à sugestão original, com uso provisório explícito no questionário, resultado e histórico.

Isolar essa regra em uma política substituível, inicialmente `UseSuggestedClassProvisionally`. Registrar feedback ao sistema inteligente fantasma; sua confirmação de recebimento não significa validação clínica.

## Identidade e invalidação

- `analysisId`: constante durante a mesma análise, incluindo retornos e novas fotografias.
- `imageId`: novo a cada fotografia recebida; não equivale ao hash.
- `cropRevision`, `decisionRevision`, `answersRevision`: identificam versões dos dados dependentes.
- `imageHash`: identifica os bytes efetivamente enviados. Após recorte manual, o hash e os pixels corrigidos acompanham as etapas seguintes.

| Alteração | Invalidar | Preservar |
| --- | --- | --- |
| Outra fotografia | Detecção, recorte, foco, classe, decisão, respostas e resultado atuais | Identidade da análise, motivo e histórico das tentativas anteriores |
| Novo recorte | Foco, classe, decisão, respostas e resultado | Original e histórico de recortes |
| Outra classe efetiva | Questionário/respostas incompatíveis e resultado | Sugestão original da CNN e trilha das decisões |
| Decisão diferente, mesma classe efetiva | Resultado e seus metadados anteriores | Respostas ainda compatíveis com o questionário |
| Resposta editada | Resultado multimodal | Demais respostas e referência à classe |
| Apenas navegar para trás ou trocar de aba | Nada | Dados válidos e progresso |

Toda chamada captura a identidade e as revisões de suas entradas. Aplicar a resposta somente se essas entradas ainda forem atuais. O risco aceito permanece separado de configurações mutáveis, preservando a correção introduzida em 0.2.1.

## Evolução da cloud

A implementação acrescenta `/v2` no **mesmo serviço**, preservando `/v1` e seu comportamento para o aplicativo anterior. O cliente 0.2.1 exige detecção positiva e os rótulos antigos; alterar esses retornos em v1 quebraria sua compatibilidade. `src/pipeline/` e a metodologia acadêmica foram preservados. O contrato definitivo está em `cloud/CONTRACT_V2.md`, na raiz do repositório.

O envelope v2 deve incluir versão, análise, imagem, revisões relevantes, operação, identidade da requisição, hash, indicador de simulação e `dataStored=false`.

| Operação | Contrato adicional necessário |
| --- | --- |
| Detecção | Encontrada/não encontrada; ROI opcional; bytes e hash do recorte quando válido |
| Foco | Recorte ativo e origem manual/automática; indicador simulado separado da decisão visual |
| Classificação | Sugestão original identificada; nenhuma confirmação profissional implícita |
| Questionário | Classe efetiva, decisão, uso provisório, versão do formulário, seções e opções demonstrativas |
| Multimodal | Recorte, classe, respostas, versão do questionário e metadados da decisão; seis módulos separados com interface comum |
| Feedback | Eventos de correção, falha, discordância, incerteza e retorno; referências suficientes, sem reenviar pixels desnecessariamente |

A identidade aleatória de uma nova análise alimenta sorteios independentes para classe e risco. Tentativas da mesma operação permanecem estáveis; reprocessar entradas não obriga o risco a mudar. Nenhuma imagem, classe ou resposta recebe significado clínico no sorteio.

Se a operação de feedback falhar, conservar o evento em memória como pendente e distinguir tentativa de envio de confirmação recebida. Não afirmar persistência remota nem treinamento. Mudanças de contrato devem passar pelos testes de compatibilidade v1 antes de publicar.

## Eventos e métricas

Registrar identificação da análise/imagem, entrada e saída de etapas, duração, decisões, retornos, erros, correções, incerteza, feedback, resultado, conclusão e abandono explícito. Separar tempo total de tempo ativo, descontando pausas da aplicação e consulta a outras abas quando o objetivo for medir a tarefa ativa.

Exportar JSON sem bytes de imagens, nomes de arquivos de origem, EXIF ou dados pessoais desnecessários. Distinguir execução automatizada, mockup e futuro teste com profissional. Não afirmar que houve avaliação com profissionais.

Limitação: sem persistência, encerramento forçado do processo não permite recuperar/exportar a sessão nem garantir registro de abandono. Não adicionar armazenamento silenciosamente para contornar isso.

## Verificação prevista

Cobrir os 28 estados de mockup e os 15 percursos definidos no pedido, em ambos os temas. Testar materialização do recorte, nova detecção após troca de foto, incerteza até o resultado, seis questionários/multimodais, invalidação, respostas atrasadas, erros, exportação, leitores de tela, fonte ampliada, telas pequenas e redução de movimento.

Fixtures controladas verificam todos os caminhos sem alterar o sorteio do aplicativo. Testes HTTPS usam poucas requisições e imagens sintéticas, preservando limites de consumo. As imagens científicas escolhidas pela usuária são entradas possíveis para seus testes manuais; não foram enviadas durante este levantamento.

## Estado da implementação em 29/10/2026

- Diagnóstico do código e das fontes realizado; ver `REPOSITORY_DIAGNOSIS.md` e `REFERENCE_AUDIT.md`.
- Biblioteca incorporada ao Flutter: nove fotografias categorizadas e dois exemplos de foco, com manifesto e verificação dos pixels em `design/reference_library/`.
- Paleta original PNG/SVG localizada e preservada em `design/sources/`; 30 tons extraídos, tokens primitivos/semânticos e temas completos. As telas Mobbin e a captura específica de menu não ficaram acessíveis; a navegação flutuante atende à descrição da usuária, sem alegação de reprodução da captura.
- Controlador, contratos v2, componentes, telas, questionários, seis módulos multimodais, cenários e registro em memória implementados. Históricos de sessões anteriores permanecem em memória e acompanham a exportação, com origem por sessão.
- Novo ícone incorporado aos catálogos iOS/Android e tipografia Inter incluída localmente.
- Figma: arquivo dedicado criado; a cota Starter impediu a criação da biblioteca nativa. Alternativa entregue: 72 SVGs editáveis, pranchas e protótipo HTML com 15 percursos. Limitações em `design/figma/README.md`.
- Protocolo para futura avaliação com profissionais em `validation/PROTOCOL.md`; avaliação não realizada.
- Evidências de execução, publicação e limites de build constam em `DELIVERY.md` e `validation/`; capturas Flutter em `screenshots/flutter/` são renderizações dos widgets reais, sem alegação de captura do iPhone.
