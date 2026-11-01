# Diagnóstico do repositório e materiais do TCC

Levantamento realizado antes da evolução da interface e atualizado em 29/10/2026 com os recursos posteriormente disponibilizados. Este documento registra o ponto de partida e as evidências usadas para projetar a evolução. A existência de novos arquivos durante o desenvolvimento não constitui, por si, confirmação de compilação, instalação ou conclusão de todas as fases.

## Organização encontrada

O workspace contém duas pastas com funções diferentes:

- `TC_Luisa_Becker/`: repositório de código e documentação de implementação, com aplicativo Flutter em `mobile/`, protótipo Python original na raiz e serviço cloud em `cloud/`.
- `TC2_Luisa/`: materiais acadêmicos — relatório, fluxograma, proposta/orientação e a pasta `Referências/` com seis PDFs científicos. Esses originais não são destinos de edição da interface.

O repositório já continha alterações locais da integração cloud ainda não commitadas. Elas integram a base a preservar; não devem ser confundidas com arquivos descartáveis. A evolução reutiliza `mobile/`, sem criar uma segunda aplicação Flutter desconectada do fluxo existente.

## Base de software anterior à evolução visual

| Área | O que existia | Consequência para a evolução |
| --- | --- | --- |
| `app.py`, `src/pipeline/` e `src/ui/` | Protótipo Python/Streamlit e módulos fantasma de detecção, foco, CNN, questionário, multimodal e feedback | Preservar a lógica original e a metodologia; não implementar IA ou retreinamento real |
| `mobile/` | Aplicativo Flutter Android/iOS, versão anterior registrada como 0.2.1+3 | Evoluir o aplicativo existente, preservando plataformas e aquisição de imagem |
| `mobile/lib/domain/pipeline.dart` | Etapas, recorte materializado, identidade de sessão, classes, respostas e resultado aceito separado da configuração | Preservar a correção do recorte e impedir retorno silencioso ao risco médio |
| `mobile/lib/services/` | Cliente HTTPS, URL do Cloud Run e orquestração validando sessão/hash | Chamadas reais são parte obrigatória da experiência nova; não trocar a cloud por uma animação local |
| `mobile/lib/ui/crop_editor.dart` | Editor sobre a imagem, com seleção e redimensionamento visual | Coordenadas internas são um contrato técnico; a pessoa edita diretamente a imagem |
| `mobile/lib/main.dart` | Interface concentrada num fluxo principal, controles e estado próximos dos widgets | Separar apresentação, navegação e controlador antes de ampliar os caminhos |
| `cloud/` | Serviço Python com API v1 e recorte real; resultados de IA fictícios | Preservar compatibilidade do app anterior durante eventual ampliação de contrato |
| `mobile/test/`, `mobile/tool/`, `cloud/tests/` | Testes de domínio, widgets, risco, contrato Dart/Python e serviço | Manter regressões existentes e acrescentar testes dos novos retornos e decisões |

Dependências declaradas no Flutter incluem `image`, `image_picker`, `crypto` e `share_plus`, além do SDK e ferramentas de teste/lint. A base utiliza Dart/Flutter e componentes Material. Não havia biblioteca de design system, galeria clínica documentada ou fonte Inter incorporada no início do levantamento.

Os registros de compilação/instalação e testes da versão 0.2.1+3 estão em `docs/CLOUD_REQUIREMENTS.md`. Eles documentam uma entrega anterior; não substituem testes da interface redesenhada. O build Android possuía bloqueio de download do Gradle no ambiente anterior, também registrado ali.

## Integração cloud que precisa permanecer funcional

A implantação anterior utiliza o serviço `pipeline-bucal`, região `us-central1`, com URL configurada em `mobile/lib/services/cloud_endpoint.dart`. O contrato v1 tem as operações `detect`, `focus`, `classify`, `questionnaire` e `multimodal`, além de verificação de disponibilidade. As imagens preparadas e o recorte confirmado são enviados por HTTPS; o retorno deve corresponder à sessão e aos bytes enviados.

O recorte é uma transformação real de pixels. Detecção, foco, classificação, avaliação de feedback e risco permanecem simulados. O resultado de risco é independente de regras clínicas e de qualquer suposto diagnóstico das fotografias de referência. Nova análise permite novo sorteio; repetir a mesma operação não deve alterar o resultado da mesma execução.

A nova interface acrescenta falha de detecção recuperável, incerteza, revisões e feedback explícito. Esses casos exigem contratos próprios; preservar `/v1` evita quebrar o aplicativo previamente instalado. A arquitetura da evolução está em [ARCHITECTURE.md](ARCHITECTURE.md). Este diagnóstico não publica serviço nem altera faturamento. A condição confirmada é custo financeiro zero, sem upgrade pago ou contratação de infraestrutura; saldo/prazo observados numa sessão anterior não comprovam disponibilidade financeira atual.

Consultar imagens da biblioteca é uma operação local. Escolher uma imagem como entrada e confirmar seu uso na análise é uma ação distinta. Não enviar fotografias por simples navegação ou ampliação de referências. Os registros de uso permanecem em memória e a exportação JSON é manual, sem pixels e sem identificação desnecessária.

## Relatório e fluxograma

O relatório disponível é `TC2_Luisa/TCC_II__Luisa_Becker_v1.pdf`, com 28 páginas, criado em 21/10/2026 segundo seus metadados. Foram examinados objetivo, fundamentação, metodologia e referências. Ele contém uma única figura, o fluxograma; não constitui a fonte das fotografias clínicas extraídas.

O relatório define apoio ao profissional da saúde não especialista, seis classes elementares, questionários futuros, multimodais por classe, três níveis de risco e ausência de diagnóstico definitivo. Ele descreve etapas metodológicas ainda futuras; não atribuir ao texto validação experimental ou testes com profissionais que não ocorreram.

O `Fluxograma_Pipeline_v7.png` ainda apresenta quatro tipos, saída binária “É câncer / Não câncer” e raia denominada “Especialista”. Essas diferenças não foram usadas para mudar o escopo: o prompt mais recente e as decisões da usuária estabelecem seis classes, risco baixo/médio/alto e sistema inteligente computacional. A continuidade com classe provisória após incerteza também é uma decisão recente explícita. Não há necessidade de editar os documentos acadêmicos originais para implementar essa regra de navegação.

## Recursos científicos e visuais

O levantamento inicial não encontrou os artigos, a paleta ou fotografias categorizadas. Esses fatos foram revistos quando os materiais ficaram disponíveis; não são pendências atuais.

| Recurso disponível agora | Evidência e destino |
| --- | --- |
| Seis PDFs em `TC2_Luisa/Referências/` | Leitura textual, inspeção das figuras e legendas, com inventário em [REFERENCE_AUDIT.md](REFERENCE_AUDIT.md) |
| Figura 2 de Gomes et al. (2023) | Nove fotografias sob rótulos explícitos cobrindo as seis classes; recursos nativos em `design/reference_library/photos/` |
| Figura 1 do artigo de foco de Souza et al. | Dois exemplos identificados como nítido/desfocado, sem classe atribuída; `design/reference_library/quality/` |
| Paleta PNG e SVG | Arquivos localizados em Downloads e copiados para `design/sources/`; trinta tons vinho-terroso/rosé/neutros conferidos no SVG |
| Tokens do sistema visual | Primitivos, semânticos, valores resolvidos e relatório de contraste em `design/tokens/`; fonte e complementos documentados |
| Fonte Inter | `mobile/assets/fonts/Inter-Variable.ttf` e licença `OFL-Inter.txt`; uso local, sem consulta a serviço de fontes durante o aplicativo |
| Fotografias no pacote Flutter | `mobile/assets/references/`; manifesto e hashes comparados com a biblioteca documental |

As fotos categorizadas têm aproximadamente 100 × 80 pixels no material publicado. Essa resolução é um limite real da fonte. A biblioteca não inventa detalhes, classes ou riscos e não usa aprimoramento por IA. As imagens nítida/desfocada não entram numa classe clínica por aparência. A atribuição, recortes e hashes estão no manifesto; nenhuma cópia integral dos artigos foi adicionada à biblioteca.

O trabalho de foco deixa a definição de um ponto de corte para pesquisa futura. Consequentemente, não se introduz limiar fictício de aprovação clínica; a decisão visual do profissional é explícita, com recurso de ampliação e retorno para nova imagem.

## Referências de interface e Figma

Os quatro links Mobbin foram tentados. O acesso efetivo limitou-se à página inicial/login, sem telas internas de Withings Health Mate, Stoic, One Year ou Insight Timer. Minimalismo, clareza e organização são diretrizes descritas pela usuária, não conclusões de uma inspeção visual não realizada.

A preferência por menu inferior flutuante é explícita. A captura específica continua indisponível; a composição usa uma identidade própria e não é apresentada como reprodução dessa captura.

A integração Figma permitiu criar o arquivo `hzwZXkdUf8RE0bY45KAWbx`, mas a quota do plano Starter impediu as mutações seguintes. O arquivo criado não contém a biblioteca nativa pronta. O caminho alternativo usa tokens, SVGs e protótipo HTML, com o estado real em `design/figma/README.md`. SVGs e páginas HTML não equivalem a variantes, Auto Layout ou conexões de protótipo nativas já produzidas no Figma.

## Lacunas que orientaram a implementação

- Separar controlador/estado dos widgets para suportar navegação reversível e invalidação de dados dependentes.
- Diferenciar sugestão da CNN, decisão profissional, classe efetiva e uso provisório na incerteza.
- Acrescentar recuperação de detecção, rejeição de qualidade, nova imagem e novo recorte sem reutilizar resultados obsoletos.
- Organizar seis questionários demonstrativos em seções com revisão; manter metadados de decisão no multimodal e no resultado.
- Integrar a biblioteca local com atribuição e limitação de resolução, preservando seleção explícita para upload.
- Aplicar tokens/temas e componentes reutilizáveis, incluindo menu flutuante, estados de erro, fonte ampliada e redução de movimento.
- Registrar entrada/saída, duração, correções, incerteza, feedback, conclusão/abandono explícito e exportação manual.
- Distinguir mockups com exemplos fixos e testes automatizados controlados do sorteio do aplicativo e de futura avaliação com profissionais.

## Limite das conclusões

Este diagnóstico e a preparação dos recursos não demonstram eficácia clínica, precisão de modelos, capacidade diagnóstica ou validação com participantes. Os módulos continuam fantasmas e nenhuma inferência científica foi acrescentada às fotografias. O [protocolo de avaliação](validation/PROTOCOL.md) é um roteiro futuro; seus resultados não foram coletados. Testes automatizados, quando executados, devem ser identificados separadamente dos testes humanos e acompanhados de seus resultados efetivos.
