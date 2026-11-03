# 4 IMPLEMENTAÇÃO DO PIPELINE

Neste capítulo, é apresentada a implementação do protótipo desenvolvido a partir do pipeline descrito no Capítulo 3. A aplicação materializa o percurso da imagem clínica, as interações do profissional da saúde e a comunicação entre os módulos computacionais. O objetivo desta etapa consiste em verificar a organização e a continuidade do fluxo, incluindo correções, retornos, respostas da nuvem e apresentação dos resultados demonstrativos.

A descrição considera o código da aplicação registrado no commit `765c732` e a documentação técnica correspondente. As interfaces apresentadas ilustram estados produzidos pela aplicação Flutter com entradas controladas. Portanto, essas imagens representam o funcionamento visual do protótipo, mas não constituem evidência isolada de processamento remoto, desempenho diagnóstico ou avaliação com profissionais da saúde.

## 4.1 Escopo da Implementação

A etapa metodológica anterior estabeleceu as responsabilidades dos módulos e os caminhos previstos para a análise. Na implementação, essas definições foram organizadas em uma aplicação denominada Pipeline Bucal, destinada a dispositivos Android e iOS. O profissional pode selecionar uma imagem, conferir sua região de interesse, verificar a qualidade visual, avaliar uma sugestão de classe, preencher informações demonstrativas e consultar um resultado categórico de risco.

Os módulos de detecção, foco, classificação, análise multimodal e sistema inteligente permanecem simulados, sendo também denominados módulos fantasmas. Eles reproduzem as entradas e saídas necessárias à integração, sem executar modelos treinados de inteligência artificial. A transmissão de dados entre aplicativo e servidor, por sua vez, foi implementada. Essa distinção permite investigar o funcionamento técnico do pipeline antes da integração dos algoritmos reais.

A Figura 1 do capítulo anterior representa a organização conceitual do processo, mas conserva elementos de uma versão anterior do desenho. Nela, constam quatro tipos genéricos, uma saída binária relativa a câncer e a raia denominada “Especialista”. A implementação segue as definições textuais das Seções 3.8 a 3.11: seis classes de lesões elementares, três categorias de risco e um sistema inteligente computacional. O quadro a seguir explicita essa correspondência, preservando o fluxograma original como documento da evolução do projeto.

| Bloco ou decisão do fluxograma original | Correspondência na implementação |
| --- | --- |
| Entradas Usuário; Imagem bucal | Aquisição e pré-visualização da fotografia vinculada à análise. |
| YOLO; Crop da imagem | Solicitação de detecção simulada, região de interesse e recorte automático. |
| is image ok?; Crop manual | Conferência do recorte, ajuste manual ou substituição da imagem. |
| Foco da imagem; is foco ok? | Avaliação simulada de foco e decisão visual do profissional. |
| Reenviar foto | Retorno à aquisição e reinício da detecção. |
| CNN; Tipo I, II, III e IV | Sugestão simulada entre seis classes nominadas. |
| concorda? | Concordância, escolha alternativa ou continuidade provisória em caso de incerteza. |
| Questionário I, II, III ou IV | Seis questionários demonstrativos, vinculados à classe utilizada. |
| Multimodal Neural Network | Encaminhamento ao componente multimodal específico da classe. |
| É câncer; Não câncer; mensagens finais | Resultados demonstrativos de risco baixo, médio ou alto, sem conclusão diagnóstica. |
| Avaliação da imagem | Registro e confirmação simulada de feedback de recorte e classificação; não há curadoria clínica implementada. |
| Avaliação da análise | Perspectiva futura; não foi implementada validação do risco multimodal por especialista ou módulo inteligente real. |
| Retreino YOLO; Retreino CNN; Retreino Multimodal | Possibilidades futuras; nenhum modelo é treinado ou atualizado nesta versão. |

## 4.2 Organização da Aplicação e Integração com a Nuvem

A aplicação foi desenvolvida em Flutter, com código em Dart compartilhado entre Android e iOS. Sua organização separa componentes visuais, telas, modelos de dados, controle do fluxo, transporte de informações e registro de eventos. O controlador concentra as transições e as regras de consistência, enquanto as telas apresentam o estado atual e encaminham as ações do usuário. Essa divisão evita que cada componente visual mantenha uma interpretação independente da mesma análise.

A comunicação remota utiliza HTTPS e mensagens JSON encaminhadas ao serviço existente no Google Cloud Run. O contrato possui operações específicas para detecção, foco, classificação, obtenção do questionário, análise multimodal e feedback. No modo de nuvem, a detecção recebe a imagem original preparada; foco, classificação, questionário e multimodal recebem os pixels do recorte confirmado. Assim, a integração não se limita ao envio de coordenadas ou à troca de rótulos demonstrativos.

As requisições incluem identificadores da análise, da imagem e da solicitação, revisões do recorte, da decisão e das respostas, além do resumo SHA-256 da imagem. O cliente verifica esses campos no retorno, juntamente com a identificação do módulo e o modo de execução. Uma resposta incompatível ou pertencente a um estado anterior é recusada. O servidor não mantém o histórico da sessão; cabe ao controlador preservar o estado e invalidar informações dependentes.

Em caso de falha de rede, a interface informa o problema e oferece uma nova tentativa. Não ocorre substituição silenciosa pela simulação local. A demonstração offline depende de escolha explícita e é identificada separadamente. A documentação de implantação registra mínimo de zero e máximo de uma instância no serviço remoto; essa configuração reduz a utilização de recursos, mas não constitui garantia de custo nulo ou medição atual do consumo da conta.

## 4.3 Interface Inicial e Aquisição da Imagem

A tela inicial apresenta a identidade do aplicativo, o acesso à nova análise e a indicação de que os resultados são simulados. A navegação inferior flutuante reúne Início, Análise e Biblioteca. O percurso principal é acompanhado por indicadores de etapa em linguagem compreensível, como selecionar imagem, conferir recorte e verificar qualidade, sem exigir conhecimento prévio das arquiteturas computacionais envolvidas.

Na aquisição, o profissional pode capturar uma fotografia, selecionar um arquivo existente ou utilizar uma imagem de referência disponível no projeto. A pré-visualização permite verificar a escolha antes de iniciar a detecção. A possibilidade de substituir a fotografia evita que uma entrada incorreta seja mantida apenas por ter sido selecionada. Arquivos que não podem ser interpretados como imagem geram uma mensagem de recuperação, sem avanço para os módulos seguintes.

{{FIG:acquisition_preview}}

Cada análise recebe uma identidade própria. Dentro dela, a fotografia possui outro identificador, que permanece associado às suas transformações. O recorte representa uma revisão da imagem em uso, enquanto um novo envio estabelece uma nova identidade de fotografia. Essa diferenciação permite conservar o contexto da sessão sem confundir a imagem anterior com aquela efetivamente encaminhada ao processamento.

A biblioteca local contém nove fotografias distribuídas entre as seis classes e dois exemplos destinados à comparação de foco. As classes foram associadas às fotografias a partir das identificações explícitas na fonte, sem inferência automática pela aparência. Os exemplos classificados foram extraídos da figura publicada por Gomes et al. (2023), com registro de origem e atribuição. A ampliação não acrescenta detalhes ausentes nas pequenas imagens originais, e sua utilização no protótipo não fornece uma referência verdadeira para o risco sorteado.

## 4.4 Detecção e Validação da Região de Interesse

Depois da confirmação da imagem, a aplicação apresenta o estado de processamento e solicita a detecção. O módulo fantasma retorna a indicação de presença ou ausência de região, uma caixa delimitadora normalizada e, quando aplicável, os pixels do recorte. A localização demonstrativa não resulta de reconhecimento da lesão. Sua função atual é permitir a verificação da estrutura de resposta e da participação do profissional na confirmação da região de interesse.

Na conferência, a imagem original é exibida com a delimitação proposta. A área de pré-visualização é centralizada e possui dimensão nominal de 300 por 300 unidades lógicas, respeitando o espaço disponível. O ajuste proporcional por contenção preserva a relação entre largura e altura da fotografia. A caixa é posicionada em relação à área efetivamente ocupada pela imagem, considerando eventuais margens, para evitar deslocamento entre a região indicada e o conteúdo visual.

{{FIG:detection_crop}}

Caso o recorte seja considerado adequado, o fluxo segue para a qualidade. Se houver necessidade de correção, o profissional pode ajustar a região manualmente ou enviar outra fotografia. O editor apresenta a seleção diretamente sobre a imagem, com movimentação, redimensionamento e ampliação. Sua área de trabalho permanece fixa, evitando que o gesto destinado ao recorte provoque a rolagem da página. A confirmação produz uma nova imagem processada, cujos pixels passam a ser utilizados nas etapas posteriores.

{{FIG:manual_failure}}

A correção também gera feedback candidato à avaliação futura do detector. Quando não há detecção, as mesmas alternativas de recorte manual e novo envio são disponibilizadas, sem classificação automática de uma imagem sem região válida. O novo envio retorna à aquisição, reinicia a detecção e invalida os resultados anteriores. O recorte manual, por outro lado, preserva a fotografia original e permite continuar pela avaliação de foco.

## 4.5 Avaliação da Qualidade Visual

A etapa de qualidade corresponde aos blocos “Foco da imagem” e “is foco ok?” do fluxograma. O aplicativo encaminha o recorte confirmado ao serviço e apresenta o indicador demonstrativo recebido. Não é executado o algoritmo baseado na Transformada de Fourier discutido na fundamentação teórica; o retorno fantasma apenas representa o lugar ocupado por esse processamento na arquitetura.

{{FIG:focus}}

A decisão de continuidade permanece explícita para o profissional, que visualiza a imagem em uso e informa se sua qualidade é suficiente. O indicador simulado não é tratado como aprovação clínica. Se a imagem for aceita, inicia-se a classificação. Se for rejeitada, registra-se a decisão e retorna-se à aquisição. Também é possível revisar o recorte. Se a região for alterada, as informações posteriores que dependem do recorte anteriormente confirmado são invalidadas.

## 4.6 Classificação e Participação do Profissional

A classificação utiliza uma das seis classes de lesões elementares previstas no trabalho: pápula/nódulo, mácula/mancha, vesícula/bolha, erosão, úlcera e placa. A tela apresenta a imagem processada, a classe sugerida e exemplos correspondentes em uma galeria horizontal. As referências podem ser ampliadas, com acesso à sua atribuição, para apoiar a compreensão visual da categoria apresentada.

{{FIG:cnn_alternative}}

O resultado é descrito como uma semelhança com determinada classe, sem assumir diagnóstico. A concordância registra a confirmação e encaminha o profissional ao questionário correspondente. A discordância preserva a sugestão original e apresenta as demais classes, permitindo selecionar uma alternativa. Dessa forma, o registro distingue o que foi sugerido pelo módulo daquilo que foi escolhido pelo profissional, em vez de substituir silenciosamente a primeira informação.

A opção “Não consigo determinar” permite continuar sem confirmação da classe. Nesse caso, uma política configurável utiliza provisoriamente a sugestão original para escolher o questionário e o componente multimodal. O estado de incerteza é conservado nas etapas seguintes e gera feedback específico. Essa regra organiza a navegação do protótipo e não representa validação clínica nem transformação da discordância em concordância.

## 4.7 Questionários e Integração Multimodal

Cada classe está associada a um formulário demonstrativo identificado e versionado. Os seis questionários possuem duas seções e três perguntas, com respostas estruturadas. A interface apresenta progresso, permite retornar entre seções e mantém as escolhas para revisão. As perguntas cumprem a função de demonstrar a circulação de dados; os instrumentos clínicos definitivos dependem de elaboração e revisão por especialista em estomatologia.

{{FIG:questionnaire_uncertain}}

No modo remoto, o aplicativo obtém a estrutura do formulário pela operação de questionário. A classe efetiva considera a confirmação, a correção ou a política provisória de incerteza. Se a classe for alterada, respostas incompatíveis são invalidadas, evitando o envio de um formulário pertencente a outra categoria. Quando não existe confirmação profissional, a interface conserva um aviso visível durante o preenchimento e a revisão.

Antes da análise multimodal, uma página reúne as respostas e a classe utilizada. O profissional pode editar as informações ou confirmar o encaminhamento. A requisição inclui a imagem processada, a identidade e a versão do questionário, suas respostas e os metadados da decisão. O serviço verifica a correspondência entre esses elementos, rejeitando formulários incompletos ou incompatíveis com a classe efetiva.

{{FIG:review_multimodal}}

Foram definidos seis componentes multimodais separados, com uma interface comum. Cada um representa o módulo associado a uma classe de lesão elementar. Nesta etapa, nenhum deles combina características clínicas para inferir risco: a saída é simulada, sem regras diagnósticas inventadas. A separação estabelece um ponto de integração para implementações futuras, preservando o contrato utilizado pela interface.

## 4.8 Apresentação do Resultado e Encerramento

O resultado utiliza exclusivamente as categorias risco baixo, risco médio e risco alto. A tela combina texto, ícone e cor semântica, sem apresentar porcentagens ou afirmar que a lesão é ou não câncer. Cada categoria possui uma mensagem demonstrativa específica e orientação para avaliação médica. Mesmo o risco baixo não é apresentado como garantia de ausência de doença.

{{FIG:risks}}

Na utilização normal, novas análises recebem identificadores aleatórios. A sugestão de classe e o risco são derivados separadamente dessa identidade, possibilitando combinações variadas e também repetições. Uma nova tentativa da mesma solicitação conserva a saída correspondente à análise. O mecanismo não utiliza a aparência da imagem ou as respostas do formulário para estimar risco e, portanto, não permite interpretar seus resultados como desempenho de um classificador clínico.

Se o fluxo prosseguiu em situação de incerteza, o resultado mantém o aviso de classe não confirmada. A classificação de risco não apaga essa informação. A conclusão encerra a sessão de forma explícita e permite iniciar outra análise; a revisão das respostas permanece acessível antes do encerramento. A página de conclusão apresenta o término do percurso sem sugerir que houve confirmação diagnóstica.

{{FIG:uncertain_completed}}

## 4.9 Rastreabilidade, Feedback e Revisão de Decisões

A consistência do pipeline depende das relações entre suas etapas. Trocar a fotografia invalida detecção, recorte, qualidade, classificação, questionário e resultado. Alterar o recorte invalida as etapas seguintes; modificar a classe invalida formulários incompatíveis e resultados; editar respostas remove a validade do resultado multimodal anterior. Essas regras são executadas pelo controlador, impedindo a apresentação de uma conclusão produzida com dados que deixaram de representar o estado atual.

O histórico registra entradas e saídas de etapas, decisões, correções, retornos, operações, erros e conclusão. Também diferencia o tempo decorrido do tempo ativo, considerando pausas registradas durante a utilização. A duração de uma operação inclui a comunicação e a validação no cliente, não correspondendo exclusivamente ao processamento do servidor. A exportação manual em JSON conserva identificadores e eventos técnicos, sem incluir fotografias, conteúdo em base64 ou nomes dos arquivos selecionados.

{{FIG:history_errors}}

O sistema inteligente recebe eventos de correção, falha, discordância e incerteza. Seu retorno confirma apenas o recebimento simulado. O código do serviço não implementa persistência de imagens, respostas ou feedback em banco de dados ou armazenamento de arquivos. Também não há curadoria real, deduplicação persistente ou atualização de modelos. Falhas de envio mantêm os eventos pendentes em memória para nova tentativa. O encerramento forçado do aplicativo pode perder esse histórico; não é garantido o registro recuperável de todo abandono de sessão.

## 4.10 Recursos de Demonstração e Verificação Técnica

Além do percurso principal, a aplicação oferece Biblioteca, Sobre o sistema, configurações de execução, histórico e painel de demonstração. Esses recursos apoiam a compreensão e a inspeção do protótipo, embora não correspondam a módulos de reconhecimento no fluxograma. A página Sobre explicita as limitações dos resultados e permite selecionar tema claro, escuro ou acompanhamento da preferência do aparelho.

{{FIG:support}}

O design system reúne cores, tipografia, espaçamentos, componentes e estados interativos reutilizáveis. Os temas possuem superfícies próprias e mantêm os significados das ações. A interface utiliza áreas de toque confortáveis, descrições semânticas e tratamento da preferência por redução de movimento. Os recursos de mockup incluem SVG importáveis e tokens; sua existência não equivale à produção de uma biblioteca nativa completa no Figma.

O painel de demonstração permite escolher percursos reproduzíveis para erros, recorte, discordância, incerteza e diferentes riscos. Esses cenários executam respostas locais controladas e são separados da utilização normal, aleatória por análise. As capturas deste capítulo foram preparadas nesse contexto, para permitir comparação visual entre os estados sem atribuir aos exemplos uma conclusão clínica ou comprovação de chamada HTTPS. Os provedores local e remoto compartilham os contratos do fluxo, mas podem apresentar textos demonstrativos distintos nos questionários; não se pressupõe identidade de conteúdo entre eles.

{{FIG:themes_demo}}

Na verificação automatizada realizada para este registro, foram aprovados 116 testes Flutter, considerando duas execuções complementares: 115 testes da suíte e o teste de contrato com a implementação Python, executado separadamente após a preparação de sua dependência. Também foi gerado com sucesso o pacote de recursos da aplicação em modo de depuração, a partir de seu ponto de entrada principal. Essa verificação de compilação Flutter não equivale à geração de novos binários nativos para Android e iOS. Os testes exercitam controle do fluxo, circulação do recorte, decisões, invalidação, recuperação, temas e navegação. Esses resultados técnicos não equivalem a uma avaliação de usabilidade com profissionais reais.

A documentação conserva verificações anteriores de compilação Android e de comunicação HTTPS em 1º de novembro de 2026. Também registra instalação e abertura no iPhone nessa data, além de compilação em modo de depuração e hot reload em 2 de novembro. São evidências históricas com escopos delimitados, não testes repetidos durante a redação. A instalação e a atualização visual no aparelho, isoladamente, não comprovam todos os caminhos do pipeline.

## 4.11 Limitações da Implementação Atual

A implementação permite demonstrar a integração entre interface, decisões e serviços, mantendo explícita a natureza simulada dos resultados. Ainda permanecem pendentes os modelos reais de detecção, foco, classificação e análise multimodal, a curadoria computacional e os mecanismos de retreinamento. Os questionários e as mensagens requerem revisão especializada antes de qualquer utilização clínica, e as imagens de referência não constituem um conjunto próprio de validação diagnóstica.

Não foi realizada, no escopo aqui documentado, avaliação sistemática com profissionais da saúde. A estrutura de eventos e os cenários disponíveis preparam essa etapa, permitindo observar tarefas, retornos, dificuldades e consistência do estado. A substituição dos módulos fantasmas deverá respeitar os contratos e exigir validações próprias. O resultado alcançado nesta fase corresponde a um protótipo funcional do fluxo de informações, com comunicação remota implementada e limites claramente definidos para a interpretação de suas saídas.
