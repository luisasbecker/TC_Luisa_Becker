# Pipeline para Detecção, Processamento e Classificação de Lesões Bucais

Projeto acadêmico baseado no TCC **“Integração de Diferentes Algoritmos de Inteligência Artificial Através de um Pipeline para Detecção, Processamento e Classificação de Lesões Bucais em Imagens Clínicas”**. A implementação atual combina um aplicativo Flutter para Android/iOS e uma API Python no Google Cloud Run. O protótipo original Python/Streamlit permanece preservado na seção de legado.

O objetivo é validar o fluxo de imagens e informações, as decisões do profissional e a experiência de uso. YOLO, foco, CNN, sistema inteligente e os seis modelos multimodais continuam **simulados**. Não há IA real, inferência clínica, treinamento ou retreinamento.

## Aplicativo atual — 0.3.0+4

A pasta [`mobile/`](mobile/README.md) contém a interface com temas claro/escuro, fonte Inter, novo ícone, menu inferior flutuante e navegação guiada por etapas. O recorte manual é feito sobre a imagem e seus pixels confirmados seguem para as próximas etapas.

No uso normal, a classe de lesão e o risco variam com o identificador aleatório de cada nova análise; resultados podem se repetir. O resultado de uma mesma requisição permanece estável em uma nova tentativa. Os cenários do painel de demonstração e os mockups têm saídas determinísticas para reproduzir percursos.

A saída final contém exclusivamente **risco baixo, risco médio ou risco alto**, sem porcentagens. Esses níveis não expressam um diagnóstico nem a probabilidade real de câncer. São resultados demonstrativos, independentes da imagem e das respostas, acompanhados de orientação para avaliação médica. O aplicativo não deve ser usado para decisões clínicas.

Utilize imagens de exemplo do TCC, sintéticas ou autorizadas que não identifiquem pessoas. Não envie rostos, nomes ou dados identificáveis de pacientes.

### Fluxo e consistência

1. Selecionar/capturar uma imagem, conferir a prévia e confirmar seu uso.
2. Receber uma região de interesse simulada e validar o recorte.
3. Corrigir o recorte manualmente ou enviar outra imagem. Falha de detecção oferece essas mesmas opções; não avança sem região válida.
4. Confirmar a qualidade visual. Imagem inadequada retorna à aquisição e reinicia a detecção.
5. Comparar a classe sugerida com referências dos artigos e concordar, escolher outra classe ou declarar incerteza.
6. Responder e revisar o questionário correspondente à classe usada no fluxo.
7. Acionar o componente multimodal dessa classe e apresentar um dos três riscos simulados.
8. Concluir a sessão ou iniciar nova análise; exportar o histórico JSON quando desejado.

**“Não consigo determinar” não interrompe o fluxo.** A sugestão original segue como referência provisória, identificada como não confirmada, sem transformar incerteza em concordância. A sugestão da CNN e a decisão do profissional são registradas separadamente. Trocas de imagem, recorte, classe ou respostas invalidam os resultados posteriores dependentes.

As seis classes são pápula/nódulo, mácula/mancha, vesícula/bolha, erosão, úlcera e placa. Cada classe possui um questionário demonstrativo e um componente multimodal separado. Perguntas e orientações ainda dependem de revisão por especialista.

### Estado de compilação e distribuição

| Plataforma/serviço | Última verificação registrada |
| --- | --- |
| iOS | Versão 0.3.0/build 4 compilada, assinatura verificada, instalada e aberta no iPhone em 29/10/2026. |
| Android | APK **debug** 0.3.0/build 4 compilado, instalado e aberto em Samsung com Android 16 em 30/10/2026; mínimo Android 7.0/API 24. |
| Distribuição Android | A usuária enviou o APK manualmente ao OneDrive. A cópia baixada foi comparada por SHA-256 e corresponde ao build 4 validado. Acesso de terceiros à pasta ainda depende do compartilhamento. |
| Release Android build 5 | Preparado, mas ainda não produzido: faltam dependências do release no cache disponível para a execução restrita. |
| Lojas | Nenhuma versão publicada na App Store, TestFlight ou Google Play. TestFlight permanece uma etapa futura. |
| Google Cloud Run | API v2 publicada na revisão `pipeline-bucal-00003-kx2`, com compatibilidade v1 preservada. |

SHA-256 do APK debug distribuído: `b414f94736c6276862d490926873a7a5afa46b1537dba0d3963cae283a73f8ff`.

As confirmações de instalação e abertura não substituem o teste manual completo no aparelho nem uma avaliação com profissionais. Os relatórios distinguem testes automatizados, inspeção do artefato e execução em dispositivos: [iOS](docs/ux/validation/IOS_BUILD.md), [Android](docs/ux/validation/ANDROID_BUILD.md), [distribuição Android](docs/ux/validation/ANDROID_DISTRIBUTION.md) e [resultados consolidados](docs/ux/validation/FINAL_RESULTS.json).

### Executar e verificar o Flutter

Ambiente já utilizado: Flutter 3.41.7 e Dart 3.11.5, com as ferramentas nativas exigidas por cada plataforma.

```sh
cd mobile
flutter pub get
flutter run
flutter analyze
flutter test
```

O app usa o endpoint HTTPS v2 publicado como padrão. O modo offline é uma escolha explícita; falhas de rede não produzem um resultado local silencioso. Consulte [`mobile/README.md`](mobile/README.md) para o painel de demonstração, exportação do histórico, testes de contrato Python e geração dos artefatos Android/iOS.

## Cloud e dados

A comunicação HTTPS, o envio da imagem e o recorte dos pixels são reais. Imagens e respostas são processadas em memória durante cada requisição; o serviço não usa banco ou bucket de pacientes nem registra os corpos enviados. Logs técnicos do provedor podem conter metadados das chamadas. O histórico do aplicativo permanece em memória, com exportação manual em JSON sem pixels ou nomes de pacientes.

O Cloud Run mantém mínimo zero e máximo uma instância, com CPU por requisição. A restrição do projeto é manter **custo financeiro zero**; limites de instância não são um teto de cobrança. Conferir as condições gratuitas antes de novas implantações, sem upgrade de faturamento não autorizado. Contratos, limites e verificação HTTPS estão em [`cloud/README.md`](cloud/README.md) e [`docs/CLOUD_REQUIREMENTS.md`](docs/CLOUD_REQUIREMENTS.md).

## Organização e documentação atual

| Local | Conteúdo |
| --- | --- |
| [`mobile/`](mobile/README.md) | Aplicativo Flutter, fluxo, serviços, biblioteca de referências e testes. |
| [`cloud/`](cloud/README.md) | API Python v1/v2 e seis componentes multimodais simulados. |
| [`design/tokens/`](design/tokens/) | Tokens JSON primitivos/semânticos e geração do tema. |
| [`mobile/lib/design_system/`](mobile/lib/design_system/) | Temas e componentes Flutter reutilizáveis. |
| [`design/figma/`](design/figma/README.md) | 72 mockups SVG, pranchas e protótipo HTML; não são componentes Figma nativos. |
| [`design/reference_library/`](design/reference_library/README.md) | Imagens extraídas das fontes, atribuições e mapeamento documentado das classes. |
| [`docs/ux/DELIVERY.md`](docs/ux/DELIVERY.md) | Recursos entregues, capturas e limites de validação. |
| [`docs/ux/validation/PROTOCOL.md`](docs/ux/validation/PROTOCOL.md) | Roteiro para futura avaliação com profissionais. |

## Legado — protótipo original Python/Streamlit

As seções a seguir descrevem a implementação original em `app.py` e `src/pipeline/`, preservada como parte do histórico do projeto. Suas configurações determinísticas, cartões sintéticos e acesso móvel pelo navegador pertencem a esse protótipo; o fluxo Flutter atual é descrito acima. Nenhuma alteração metodológica ou implementação de IA real está implícita na nova interface.

### Fluxo implementado

1. Upload de imagem clínica simulada.
2. Detecção e recorte por YOLO fantasma, tratando “lesão” como classe única.
3. Validação do recorte automático pelo profissional da saúde.
4. Correção visual arrastando os pontos sobre a imagem ou envio de imagem corrigida.
5. Registro do recorte manual pelo sistema inteligente para curadoria futura.
6. Processamento e avaliação interna de foco por stub.
7. Validação subjetiva da qualidade visual.
8. Encerramento com solicitação de nova imagem quando a qualidade for rejeitada.
9. Classificação fantasma em uma das seis classes de lesão elementar.
10. Exibição de cartões sintéticos e decisão de concordância.
11. Em discordância, seleção de classe corrigida e registro de feedback.
12. Questionário simulado específico da classe final.
13. Execução do modelo multimodal específico por classe.
14. Saída final em risco baixo, médio ou alto, em caráter demonstrativo, acompanhada de orientação médica.
15. Visualização e download do histórico completo em JSON.
16. Acesso móvel local com layout responsivo, recorte por toque e QR gerado no computador.

As seis classes de lesão elementar são:

- pápula/nódulo;
- mácula/mancha;
- vesícula/bolha;
- erosão;
- úlcera;
- placa.

### Arquitetura

| Arquivo | Responsabilidade |
|---|---|
| `app.py` | Assistente Streamlit e visualização temporária das imagens. |
| `GUIA_DE_INSTALACAO.md` | Manual completo para baixar, instalar, executar, testar e atualizar o protótipo em outro computador. |
| `GUIA_APRESENTACAO_MOBILE.md` | Passo a passo para abrir o fluxo no iPhone/Android pela mesma rede ou pelo hotspot do Windows. |
| `INICIAR_PIPELINE_MOBILE.bat` | Iniciador de duplo clique para preparar o ambiente, escolher a rede e exibir o endereço móvel. |
| `src/pipeline/enums.py` | Classes de lesão, qualidade, decisões, risco, feedback e etapas. |
| `src/pipeline/models.py` | Dataclasses que representam entradas, resultados e eventos. |
| `src/pipeline/state.py` | Estado completo da sessão e erro de transição. |
| `src/pipeline/yolo_stub.py` | Detecção e recorte automáticos simulados. |
| `src/pipeline/focus_stub.py` | Processamento e avaliação interna de foco simulados. |
| `src/pipeline/cnn_stub.py` | Classe de lesão elementar e exemplos sintéticos simulados. |
| `src/pipeline/questionnaire_stub.py` | Perguntas genéricas, específicas por classe e marcadas como simuladas. |
| `src/pipeline/multimodal_stub.py` | Seis modelos multimodais fantasmas separados, um por classe. |
| `src/pipeline/intelligent_system.py` | Eventos para curadoria e possível retreinamento futuro. |
| `src/pipeline/pipeline_controller.py` | Regras do fluxo, transições e resumo JSON. |
| `src/pipeline/ui_helpers.py` | Conversão da configuração e recorte seguro da prévia visual. |
| `src/ui/image_cropper.py` e `src/ui/cropper/index.html` | Seletor visual de recorte com pontos arrastáveis, executado localmente. |
| `src/ui/image_preparation.py` | Orientação EXIF, remoção de metadados e redução preventiva da cópia de trabalho. |
| `src/ui/mobile_access.py` | Validação do endereço local e geração local do QR. |
| `tests/` | Testes automatizados do domínio, stubs, fluxo e segurança da saída. |

O núcleo não depende do Streamlit. Isso permite testar o pipeline diretamente e substituir a interface no futuro.

### Pré-requisitos

- Python 3.11 a 3.14, com Python 3.14.x recomendado;
- `pip` disponível;
- Git, caso seja utilizado o método recomendado de clonagem;
- navegador atualizado.

O protótipo foi verificado com Python 3.14, Streamlit 1.66 e Pillow 11.3. Versões futuras do Python devem ser validadas antes do uso.

> **Primeira instalação ou computador novo?** Siga o [Guia completo de instalação e execução](GUIA_DE_INSTALACAO.md). Ele explica desde o download do Python e do Git até a solução dos problemas mais comuns.

> **Apresentação pelo iPhone ou Android?** Depois da instalação, siga o [Guia de apresentação móvel](GUIA_APRESENTACAO_MOBILE.md). No Windows, também é possível dar dois cliques em `INICIAR_PIPELINE_MOBILE.bat`.

### Instalação rápida

Clone o repositório e acesse a pasta do projeto:

```powershell
git clone https://github.com/luisasbecker/TC_Luisa_Becker.git
cd TC_Luisa_Becker
```

Se preferir não instalar o Git, entre na [página do projeto no GitHub](https://github.com/luisasbecker/TC_Luisa_Becker), selecione **Code > Download ZIP**, extraia o arquivo e abra um terminal na pasta extraída. Repositórios privados exigem que a conta autorizada esteja conectada ao GitHub.

No Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

No Linux ou macOS:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

### Execução

```powershell
python -m streamlit run app.py
```

O terminal exibirá o endereço local da aplicação, normalmente `http://localhost:8501`. Abra esse endereço no navegador caso a interface não seja aberta automaticamente.

Nenhuma imagem é gravada automaticamente: os bytes permanecem apenas na sessão em memória do Streamlit. O resumo JSON contém somente identificadores e metadados do fluxo.

Para encerrar a aplicação, pressione `Ctrl+C` no terminal em que o Streamlit está sendo executado.

#### Execução no celular pela rede local

No Windows, conecte o celular e o computador à mesma rede — ou ative primeiro o Hotspot móvel do computador — e dê dois cliques em:

```text
INICIAR_PIPELINE_MOBILE.bat
```

O iniciador seleciona o endereço de rede, abre o Streamlit para acesso local e mostra um QR na barra lateral. O computador e seu terminal devem permanecer ligados. O cabo USB é opcional e não substitui a conexão Wi-Fi. Consulte o [guia móvel](GUIA_APRESENTACAO_MOBILE.md) para os passos completos e a solução de problemas de firewall.

### Configuração da simulação

Na barra lateral, é possível fixar:

- sucesso ou falha do YOLO fantasma;
- bounding box e confiança fictícias;
- escore e status internos de foco;
- classe sugerida pela CNN fantasma;
- confiança fictícia da CNN;
- risco retornado pelo modelo multimodal.

Esses valores não resultam de análise da imagem. Eles existem apenas para reproduzir cenários de navegação e teste.

### Cenários manuais principais

#### 1. Fluxo concordante

1. Mantenha a configuração padrão.
2. Envie uma imagem.
3. Execute o YOLO fantasma e aceite o recorte.
4. Execute o foco e aceite a qualidade.
5. Execute a CNN e concorde com a classe.
6. Responda o questionário simulado.
7. Execute o modelo multimodal.

Resultado esperado: risco configurado, mensagem médica e JSON completo.

#### 2. Correção manual do recorte

1. Rejeite o recorte automático.
2. Na opção **Recortar diretamente na imagem**, arraste os pontos dos cantos ou das bordas para ajustar a área. Arraste o interior do retângulo para movê-lo.
3. Confira a prévia, atualizada ao soltar, e clique em **Confirmar recorte manual**. Como alternativa, selecione **Enviar imagem corrigida**.
4. Continue o fluxo.

O seletor começa com a área proposta pelo YOLO fantasma, limitada às bordas da imagem. O recorte usa a resolução original, mesmo quando a imagem aparece reduzida na tela. Também é possível focar o retângulo com `Tab` e usar as setas para movê-lo; `Shift` + setas ajusta o tamanho. O componente funciona localmente com as dependências existentes.

Resultado esperado: eventos de recorte manual, curadoria e candidatura ao retreinamento futuro da YOLO.

#### 3. Qualidade inadequada

1. Execute o módulo de foco.
2. Informe que a qualidade visual não é suficiente.

Resultado esperado: encerramento antes da CNN e solicitação de novo envio.

#### 4. Discordância da CNN

1. Rejeite a classe de lesão elementar sugerida.
2. Compare os cartões sintéticos das demais classes.
3. Escolha uma classe corrigida.

Resultado esperado: eventos de discordância, correção e candidatura ao retreinamento futuro da CNN; a classe corrigida orienta questionário e multimodal.

### Testes automatizados

Os testes do núcleo usam somente a biblioteca padrão:

```powershell
python -m unittest discover -s tests -v
```

A suíte verifica, entre outros pontos:

- recorte automático aceito, foco adequado e concordância com a CNN;
- recorte automático rejeitado e feedback do recorte manual;
- encerramento por qualidade inadequada;
- discordância, seleção de classe alternativa e feedback;
- roteamento para seis modelos multimodais separados;
- saída limitada aos três riscos permitidos;
- ausência de porcentagem na saída final;
- orientação médica em todas as classes de risco;
- ausência de bytes de imagem no JSON;
- bloqueio de transições fora de ordem;
- vínculo entre imagem original e recortes;
- conversão da seleção visual para a resolução original e validação de seus limites.
- correção da orientação EXIF, remoção de metadados e limite de dimensão da cópia de trabalho;
- geração local do QR e presença dos recursos necessários à apresentação móvel.

### Dados, feedback e privacidade

O sistema inteligente apenas cria registros em memória. Recortes manuais e discordâncias são marcados como candidatos à avaliação/curadoria e ao retreinamento futuro; nada é incorporado automaticamente e nenhum retreinamento é executado.

O protótipo não inclui base de pacientes, autenticação, banco de dados ou persistência de imagens. O download do JSON ocorre somente quando solicitado pelo usuário.

### Limitações e trabalho futuro

- YOLO, foco, CNN e multimodais são stubs sem inferência real.
- As perguntas são placeholders claramente marcadas como simuladas.
- Os questionários clínicos reais serão definidos futuramente por profissional especialista em estomatologia.
- As regras clínicas e os limiares reais das classes de risco ainda não foram definidos ou validados.
- Imagens candidatas exigirão curadoria antes de qualquer uso futuro.
- Uma etapa posterior deverá tratar consentimento, anonimização, segurança, descarte e LGPD antes de receber dados reais.
- O acesso móvel deste legado Streamlit depende do computador servidor e da mesma rede local. O aplicativo Flutter atual, descrito acima, é uma implementação separada.
