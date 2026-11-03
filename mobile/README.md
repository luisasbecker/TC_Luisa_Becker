# Pipeline Bucal — Flutter para iOS e Android

Versão 0.3.0+4. Protótipo acadêmico de apoio à avaliação de lesões bucais, com temas claro/escuro, navegação guiada e módulos de IA simulados. As chamadas HTTPS para o Google Cloud Run permanecem no fluxo principal. Classe e risco variam por análise; repetir uma requisição mantém sua identidade e resultado. Não há diagnóstico, modelo real ou retreinamento.

## Executar

Para editar e acompanhar as mudanças no iPhone pela IDE, consulte o [guia do Antigravity com hot reload](../docs/desenvolvimento-antigravity.md).

Ambiente usado: Flutter 3.41.7 / Dart 3.11.5; Xcode para iOS; JDK 17 e Android SDK para Android. As versões dos pacotes são fixadas por `pubspec.lock`.

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d <identificador-do-dispositivo>
```

Para preparar o workspace de assinatura no iPhone:

```sh
flutter build ios --config-only
cd ios
pod install
open Runner.xcworkspace
```

Selecione a equipe e o destino no Xcode, com a conta Apple autenticada e o aparelho autorizado para desenvolvimento. As configurações geradas (`Generated.xcconfig`, `.dart_tool`, `local.properties`) não são versionadas; regenere-as com seu Flutter habitual. O registro histórico de instalação em 22/10/2026 foi preservado em `README_2026-10-22.md`; não comprova instalação desta nova interface.

## Usar o aplicativo

- **Início → Nova análise:** selecione uma imagem da câmera, galeria ou biblioteca. A prévia exige confirmação antes do envio da imagem à cloud.
- **Conferir recorte:** aprove a região ou escolha recorte manual/novo envio. O editor ocupa uma área fixa, sem rolagem da página, ajusta a imagem por largura e altura e mantém confirmação/cancelamento visíveis. Arraste as alças ou o centro; a lupa alterna ampliação e edição. Ajustes acessíveis e ajuda abrem separadamente. A confirmação materializa os novos pixels; o recorte segue para as etapas seguintes.
- **Verificar qualidade:** a sugestão automática de foco, adequada ou inadequada, é recebida do módulo fantasma e aparece explicitamente como fictícia. A decisão é do profissional. Ao rejeitar a qualidade, o fluxo retorna à aquisição, na mesma análise, e a nova imagem passa novamente pela detecção.
- **Comparar lesão:** consulte as referências e concorde, escolha outra das cinco classes ou registre “Não consigo determinar”. A incerteza continua com a sugestão original como classe provisória e permanece visível até o resultado.
- **Informações clínicas:** responda às seções do questionário demonstrativo da classe utilizada; avance, volte, edite e revise antes de confirmar.
- **Resultado:** somente risco baixo/médio/alto, sem porcentagem. Toda categoria exibe orientação de avaliação médica e aviso de simulação. Conclua ou inicie outra análise.

O menu flutuante Início / Análise / Biblioteca preserva a análise em andamento. A seta de retorno e os botões de revisão permitem rever decisões. Alterações de imagem, recorte, classe ou resposta invalidam os dados dependentes; respostas antigas da rede não sobrescrevem o estado atual.

Durante o recorte manual, o menu flutuante cede espaço à imagem e aos controles fixos; volta ao sair do editor. Uma **Nova análise** normal sempre inicia na cloud e encerra o cenário fixo anterior. Uma referência escolhida enquanto a análise aguarda uma imagem mantém a sessão e seu modo explicitamente selecionado, inclusive após rejeitar a qualidade.

Detecção, foco, CNN e multimodal fazem chamadas HTTPS separadas ao serviço existente. A interface identifica a etapa em processamento e o retorno recebido. O histórico informa operação, origem, módulo fantasma validado e duração da comunicação; não inclui os pixels da imagem. Veja [comunicação por etapa](../docs/ux/validation/CLOUD_STAGE_COMMUNICATION.md).

Em **⋯ → Sobre e configurações**, escolha tema claro, escuro ou sistema. A redução de movimento do aparelho é respeitada. **Configurar próxima análise** permite escolher Cloud Run ou demonstração offline; falhas de rede não ativam offline automaticamente.

## Biblioteca e origem das imagens

A biblioteca contém nove fotografias distribuídas pelas seis classes, extraídas de Gomes et al. (2023), Figura 2, com rótulos explícitos da fonte e licença CC BY 4.0. Há também dois exemplos de foco de Souza et al., sem classe ou risco atribuídos. Consulte a origem ao ampliar uma imagem. A resolução limitada vem da publicação; não houve melhoria artificial.

Consultar referências é local. O comando **Usar em uma análise** seleciona uma entrada de teste; o envio só ocorre após a confirmação da prévia. O aplicativo não infere risco a partir das referências.

A biblioteca canônica e seu extrator verificável estão em `../design/reference_library/`. O pacote do app copia somente os ativos e o manifesto para `assets/references/`.

## Modo de demonstração

Abra **⋯ → Sobre e configurações → Painel de demonstração** antes de iniciar uma análise. Os quinze roteiros locais reproduzíveis ficam separados do fluxo normal:

1. Percurso completo.
2. Correção manual do recorte.
3. Recorte e novo envio.
4. Falha de detecção e recorte manual.
5. Falha de detecção e novo envio.
6. Imagem inadequada.
7. Concordância com a sugestão.
8. Escolha de outra classe.
9. Incerteza com continuidade provisória.
10. Risco baixo.
11. Risco médio.
12. Risco alto.
13. Revisão das decisões.
14. Arquivo inválido e recuperação.
15. Percurso com feedback.

Os cenários fixam as saídas dos módulos, mas as decisões são executadas pelo usuário. Um aviso identifica o cenário durante o percurso. **Voltar ao sorteio normal** inicia outra análise normal após a confirmação. No uso habitual, tanto cloud quanto offline sorteiam classe/risco por análise; repetições são possíveis.

## Histórico e exportação

O ícone de relógio abre os eventos da análise atual, incluindo entradas/saídas de etapas, tempo ativo, decisões, retornos, erros e feedback. **Exportar histórico JSON** abre o compartilhamento nativo do sistema.

O JSON contém identificadores técnicos, hashes, decisões e eventos, sem bytes de imagem, nome de arquivo local, nome de paciente ou campos clínicos de identificação. Sessões anteriores concluídas ou interrompidas permanecem arquivadas em memória e acompanham a exportação. Fechar o processo pode perder esse histórico; não há persistência recuperável garantida. Nenhum evento representa validação clínica. Testes automatizados/fixtures são identificados separadamente de sessões manuais.

## Cloud e integração futura

A UI atual utiliza o contrato `/v2` em `lib/core/services/analysis_transport.dart`. Os adaptadores `/v1` e a tela legada permanecem isolados para regressão de compatibilidade; o ponto de entrada de produção é `lib/main.dart`.

```sh
flutter run --dart-define=CLOUD_API_URL=https://URL_VERIFICADA_DO_CLOUD_RUN
```

O endpoint padrão é `https://pipeline-bucal-qpkmvmtgra-uc.a.run.app`. A nova UI requer o backend v2 publicado nesse serviço; se a revisão for antiga, o app mostra um erro recuperável e não inventa um resultado local. Estado de implantação e limites estão em `../cloud/README.md` e `../docs/CLOUD_REQUIREMENTS.md`. Não se deve confundir limites de instância com garantia permanente de custo zero.

As imagens preparadas e os recortes são enviados por HTTPS, sem persistência funcional do serviço. A imagem selecionada perde metadados e é limitada a 1600 pixels. Os seis contratos de classificação/questionário/modelo multimodal, decisões e revisões permitem substituir módulos simulados sem refazer a UI. O pipeline Python original não é alterado pela camada visual.

## Organização e design

- `lib/design_system/`: temas, componentes e tokens Dart gerados do JSON.
- `lib/core/`: modelos, contratos, transporte cloud/offline, política de incerteza e eventos.
- `lib/features/analysis/`: controlador de fluxo e apresentação por etapa.
- `lib/features/app/`: shell, navegação global, configurações e histórico.
- `lib/features/library/`: repositório local, galerias e fontes.
- `lib/features/demo/`: fixtures e roteiros separados do uso normal.
- `assets/branding/` e `assets/fonts/`: logo e Inter com licença OFL.
- `../design/tokens/`: valores primitivos/semânticos e relatório de contraste.
- `../design/figma/`: mockups SVG, protótipo navegável e documentação do fallback. O arquivo Figma foi criado, mas a integração atingiu sua cota antes da construção da biblioteca nativa; os SVGs não são apresentados como componentes Figma nativos.
- `../docs/ux/`: arquitetura, auditoria de referências, roteiro futuro de avaliação e evidências.

## Validação e capturas

A suíte cobre estado, contratos, fluxos v1/v2, pixels após recorte, riscos, incerteza, invalidação, temas, navegação, redução de movimento e layouts com fonte ampliada. Para executar também o contrato real contra o Python local, forneça `PIPELINE_PYTHON` e `PYTHONPATH` apontando para um ambiente com Pillow; sem eles esse teste específico é explicitamente omitido.

```sh
flutter analyze
flutter test
PIPELINE_PYTHON=/caminho/python PYTHONPATH=/caminho/dependencias flutter test test/analysis_backend_contract_test.dart
flutter test --update-goldens tool/capture_ui_test.dart
```

O último comando gera dez capturas dos widgets reais em `../docs/ux/screenshots/flutter/`: home, classificação e três riscos nos dois temas. São fixtures de renderização, não evidência de testes com profissionais ou instalação em um aparelho.

## Distribuição posterior

Os identificadores são `br.com.luisabecker.pipelineBucal` (iOS) e `br.com.luisabecker.pipeline_bucal` (Android). O ícone personalizado já foi preparado. Publicar nas lojas exige os respectivos registros, assinatura de distribuição, política de privacidade e metadados.

```sh
flutter build ipa --release
flutter build apk --debug
flutter build appbundle --release
```

Para Android release, copie `android/key.properties.example` para `android/key.properties` e configure a chave de upload sem versionar senhas/chaves. O build release é bloqueado sem essa configuração. Não confunda a equipe pessoal de desenvolvimento Apple com inscrição de distribuição. A confirmação final de builds/dispositivos deve ser consultada nas evidências da entrega atual.
