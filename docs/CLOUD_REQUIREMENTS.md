# Integração cloud fantasma — requisitos aprovados

Atualização: 22/10/2026. O usuário aprovou Google Cloud Run, seis classes, três níveis de risco e curadoria/retreinamento automáticos em modo fantasma, com custo financeiro zero. Serviço publicado e verificado por HTTPS; URL configurada no Flutter. Versão 0.2.1+3 compilada, instalada e iniciada no iPhone após verificar os três riscos por HTTPS no próprio aparelho. A compilação Android e os testes manuais completos de uso nos aparelhos ainda estão pendentes. Documentos conferidos em `../TC2_Luisa/`: `TCC_II__Luisa_Becker_v1.pdf` (28 páginas) e `Fluxograma_Pipeline_v7.png`.

## Decisões confirmadas pelo usuário

- Todos os módulos computacionais demonstrados pelo fluxograma devem executar como stubs na cloud; as decisões do profissional continuam na interface móvel.
- A comunicação pela internet é real. Imagens de teste são efetivamente enviadas: original para a etapa que a exigir e recorte confirmado para as etapas seguintes.
- Mantêm-se as seis classes de lesão existentes e os três resultados finais: risco baixo, médio ou alto. A saída continua identificada como simulação, sem percentuais ou diagnóstico.
- Cada nova simulação deve variar os resultados por sorteio, permitindo repetições. Não pode permanecer fixa na classe úlcera e risco médio como no padrão atual.
- O risco é sorteado independentemente de imagem, classe e respostas. Não se introduzem regras clínicas não validadas.
- A classe confirmada ou corrigida pelo profissional orienta o questionário e o módulo multimodal correspondente.
- O usuário não precisa apresentar registros; o objetivo desta etapa é testar o pipeline e o fluxo ponta a ponta.
- Em falha de conexão, a sessão permanece disponível para tentar novamente. Reenviar a mesma operação não deve sortear outro resultado para a mesma simulação.
- Incluir modo de demonstração offline separado, escolhido explicitamente e identificado na interface. Falhas da cloud não devem ativá-lo silenciosamente. Confirmado na resposta mais recente do usuário.
- A escolha do provedor prioriza custo zero, configuração simples e disponibilidade para as apresentações.

## Conciliação do relatório com o fluxograma

- O desenho v7 representa quatro tipos e saídas binárias “É câncer” / “Não câncer”. O texto do relatório, seções 3.8–3.10, especifica seis classes e risco baixo, médio ou alto. A proposta é seguir o texto e as decisões já confirmadas pelo usuário.
- Na seção 3.11, a avaliação de correções é atribuída a um sistema inteligente computacional. A raia “Especialista” do desenho é interpretada, nesta entrega fantasma, como esse módulo simulado de avaliação/curadoria; não pressupõe novo aplicativo ou autenticação de especialista.
- A seção 3.7 mantém a decisão de aceitar a qualidade visual com o profissional. O indicador de foco continua simulado; não deve bloquear automaticamente o avanço por um limiar clínico inventado.
- A seção 3.9 informa que os questionários clínicos ainda serão definidos por especialista. A proposta mantém formulários demonstrativos por classe, explicitamente sinalizados e sem influência clínica no sorteio do risco.
- Não foi encontrado um banco de fotografias de referência na pasta. O app atual usa exemplos sintéticos sinalizados; mantê-los nesta etapa é a proposta, sem apresentá-los como banco clínico validado.
- O relatório prevê armazenamento futuro de feedback. Para esta entrega, prevalece a decisão do usuário de testar o fluxo sem histórico persistente; avaliação e encaminhamento ao retreinamento serão simulados, sem guardar imagens e sem alterar modelos.

## Mapeamento funcional implementado

| Bloco | Responsabilidade nesta entrega |
| --- | --- |
| Entrada da imagem | Captura/seleção no app e envio HTTPS da imagem preparada. |
| YOLO e recorte automático | Detecção simulada; gerar o recorte efetivo na cloud a partir da região sugerida e devolver a imagem ao app. A região não representa detecção clínica real. |
| Validação e recorte manual | Decisão e edição diretamente sobre a imagem no app; enviar os bytes do recorte confirmado. |
| Avaliação de foco | Serviço simulado na cloud recebe o recorte ativo; aprovação/rejeição visual pelo usuário. Rejeição retorna à entrada de imagem. |
| CNN | Serviço simulado sorteia uma das seis classes. |
| Concordância/correção | Usuário confirma ou escolhe outra classe; correção encaminhada ao sistema inteligente simulado. |
| Questionário | Serviço fornece o formulário demonstrativo correspondente; usuário responde no app. |
| Seis módulos multimodais | Roteamento conforme classe final; recebem recorte ativo, classe e respostas, retornando um dos três riscos simulados. |
| Sistema inteligente | Recebe correção manual, discordância da CNN ou resultado multimodal; simula avaliação e decisão de encaminhamento. |
| Retreinamento YOLO/CNN/MNN | Recebe os encaminhamentos aprovados pela avaliação simulada e devolve confirmação de simulação. Não treina, não persiste conjunto de dados e não altera resultados futuros. |
| Mensagem final | Exibe risco simulado, distinção cloud/offline e orientação já prevista no app. |

As rotas podem pertencer a um único serviço, com módulos internos separados. O requisito de módulos distintos não exige vários serviços ou servidores. A imagem processada deve ser a mesma entrada visual da CNN e da MNN, conforme a seção 3.3.

## Escolhas de implementação

- Google Cloud Run com backend Python aprovado pelo usuário em 22/10/2026. A implantação usa um único serviço com rotas por etapa; detecção simulada, recorte real e demais módulos fantasma.
- A conta existente foi acessada no Safari: avaliação gratuita ativa. Nenhum upgrade foi realizado. Computação, tráfego, build, artefatos e logs precisam ser acompanhados; limite de instâncias e alertas não constituem teto financeiro.
- Sem persistência de imagens, respostas ou resultados na aplicação da cloud. Dados recebidos são usados durante o atendimento da requisição. Logs técnicos do provedor são distintos de histórico funcional; evitar registrar conteúdo de imagens e questionários.
- A sessão do app preserva a identidade da simulação e as respostas recebidas; a API precisa garantir resultados estáveis nas tentativas da mesma operação sem depender de memória global do servidor.
- Não está definida uma exigência acadêmica de Python nem o número de testadores. Python é uma recomendação técnica de reaproveitamento, não uma exigência atribuída ao usuário ou ao relatório.

## Estado da entrega em 22/10/2026

- Implementados serviço WSGI, imagem recortada efetiva, sorteio por sessão, seis rotas multimodais, questionários por classe, curadoria e retreinamento fantasma. Nenhum modelo é alterado.
- Implementados cliente HTTPS no Flutter, verificação de hash/sessão, nova tentativa sem avanço parcial e modo offline explícito. Removido o resultado fixo do modo padrão.
- Testes locais: seis testes Python da API passaram; 14 cenários Dart existentes passaram; teste integrado Dart/Python passou com falhas de rede simuladas, rejeição de resposta com hash divergente e encaminhamento das imagens corrigidas.
- `flutter analyze --no-pub` passou, inclusive após configurar a URL publicada. Build iOS Release pelo Xcode: **Build succeeded**, em 22/10/2026 às 19:42 (America/Sao_Paulo), com a URL publicada. O pacote compilado confirmou versão 0.2.0, build 2, identificador `br.com.luisabecker.pipelineBucal` e a URL HTTPS presente no binário Flutter.
- Build Android continua bloqueado no ambiente pelo download de `services.gradle.org` (`UnknownHostException`).
- O usuário autorizou o Cloud Shell sob a condição de custo financeiro zero. A autorização foi concluída; APIs necessárias ativadas e serviço publicado no projeto `project-9387493a-f6b7-4a38-a3a`, região `us-central1`. A conta permaneceu em avaliação gratuita, sem upgrade de faturamento.
- Criadas identidades separadas de build e execução; somente a primeira recebeu `roles/run.builder`. Nenhum papel da conta pessoal foi alterado. Configuração publicada: cobrança por requisição, 1 vCPU, 512 MiB, concorrência 2, mínimo 0 e máximo 1 instância, timeout de 60 segundos, sem CPU boost.
- Revisão publicada: `pipeline-bucal-00002-kfk`, com 100% do tráfego. URL: `https://pipeline-bucal-qpkmvmtgra-uc.a.run.app`. O teste `cloud/smoke.py` passou contra essa revisão, verificando disponibilidade em `/v1/health`, HTTPS, recorte real, foco, CNN, correção de classe, questionário, MNN, curadoria, encaminhamento ao retreinamento fantasma e estabilidade de nova tentativa. Foram usadas somente imagens sintéticas.
- A URL verificada está definida em `mobile/lib/services/cloud_endpoint.dart`, com possibilidade de sobrescrita por `CLOUD_API_URL`. Nenhuma credencial foi incluída no aplicativo.
- Após o usuário confirmar a conexão, o controle do Xcode voltou e “iPhone de Luisa” apareceu como **Connected**. O destino físico foi selecionado e a execução Release concluiu a instalação: a lista Installed Apps confirmou Pipeline Bucal, build 2, identificador `br.com.luisabecker.pipelineBucal`; a atividade mostrou **Running Runner on iPhone de Luisa**. Sem erros ou avisos de conexão na janela Devices. O aplicativo foi deixado em execução.
- Pendências de validação: testar o fluxo completo por toque no iPhone (a instalação/inicialização não substitui esse teste), concluir build e testes Android quando o download do Gradle estiver disponível e preparar a distribuição pelas lojas em etapa posterior. As alterações cloud ainda não foram commitadas.

## Verificação do relato de risco sempre médio — 22/10/2026

O relato ainda não foi reproduzido. Em 18 novas sessões HTTPS na revisão publicada `pipeline-bucal-00002-kfk`, com imagem sintética e as mesmas respostas, foram observados 5 riscos baixos, 6 médios e 7 altos. Cada resposta correspondeu ao sorteio da respectiva sessão. A sequência incluiu quatro riscos altos consecutivos, mostrando que o sorteio independente permite sequências repetidas.

A verificação do cliente confirmou que respostas baixo/médio/alto substituem corretamente o valor inicial médio e aparecem no resumo. Foram adicionados três testes em `mobile/test/cloud_risk_test.dart`, cobrindo a resposta da cloud, o estado do pipeline, o resumo e o texto efetivamente renderizado. Não foi alterada a regra de sorteio: uma nova sessão sorteia novamente, enquanto uma nova tentativa da mesma sessão preserva o resultado. Não se conclui, apenas com esses testes, qual foi a causa da sequência observada pelo usuário.

Os 20 testes Flutter (domínio e widgets, incluindo os três novos testes de risco) passaram nessa primeira verificação. O teste integrado Dart/Python também passou. A limitação anterior de execução de testes de widgets não se repetiu. Nessa etapa inicial, nenhuma alteração de comportamento foi publicada nem uma nova versão instalada.

### Correção e verificação no iPhone — versão 0.2.1+3

Após a reiteração do relato, foram identificadas e reproduzidas duas fragilidades do cliente: o domínio permitia concluir uma sessão cloud sem receber explicitamente o risco da API, e o resumo/tela dependiam do valor de uma configuração mutável. Dois testes falharam antes da correção. Isso demonstra as fragilidades, mas não comprova que tenham causado a sequência observada pelo usuário.

O resultado aceito agora é armazenado separadamente em `resultRisk`. Uma sessão cloud não conclui sem risco explícito; índice e rótulo da API precisam ser consistentes. Tela, resumo e histórico usam o resultado aceito, que não muda quando a configuração da demonstração é alterada. Não há retorno silencioso ao risco médio em uma sessão cloud.

Verificações concluídas:

- `flutter analyze --no-pub`: sem problemas; `flutter test --no-pub`: **23 testes passaram**; contrato integrado Dart/Python: passou.
- O teste de interface percorreu quatro simulações completas pelos botões, com respostas controladas médio/baixo/alto/médio, quatro sessões diferentes e todas as cinco operações em cada sessão.
- `mobile/tool/verify_device_cloud.dart` foi compilado temporariamente e executado no **iPhone de Luisa**. Usando apenas imagem sintética, o cliente/runner normal chamou as cinco etapas HTTPS reais e confirmou os três riscos, o recorte manual e a correção de classe. O console do Xcode registrou `PASS risk=0`, `PASS risk=1`, `PASS risk=2` e `PASS all three risks through five real HTTPS stages on this device`.
- O diagnóstico seleciona identidades de sessão para cobrir deliberadamente cada ramo de risco; não é uma amostra aleatória de frequência nem altera o sorteio do aplicativo normal. A amostra aleatória da API continua sendo a verificação anterior de 18 sessões.
- Depois do diagnóstico, o alvo foi restaurado para `lib/main.dart`. O pacote Release confirmou versão **0.2.1**, build **3**, URL HTTPS correta e ausência do marcador de diagnóstico no binário. A instalação foi confirmada em **Installed Apps → Pipeline Bucal → 3**, e o Xcode mostrou **Running Runner on iPhone de Luisa**. Binário final gerado em 22/10/2026 às 20:38 (America/Sao_Paulo).

A revisão da cloud permanece `pipeline-bucal-00002-kfk`; não houve nova implantação ou alteração de faturamento. O sorteio continua independente por nova sessão, com repetições permitidas e estabilidade em tentativas da mesma sessão. A verificação no aparelho exercita cliente e rede reais; os toques completos foram automatizados em teste de widgets, não no iPhone físico. Build/testes Android e distribuição pelas lojas continuam pendentes. Alterações ainda não commitadas.

## Critérios de aceitação propostos

- Executar o fluxo completo com chamadas reais à cloud em iOS e Android.
- Confirmar por teste que os bytes recebidos nas etapas posteriores correspondem ao recorte aprovado, inclusive depois de um novo ajuste.
- Verificar cobertura das seis classes e três riscos em testes controlados do sorteio; não exigir variedade garantida em toda amostra pequena ou ausência de repetições.
- Demonstrar que iniciar outra simulação permite outro resultado e que repetir uma requisição da mesma sessão preserva o resultado.
- Validar qualidade rejeitada, correção de classe, questionário incompleto, falha de rede e nova tentativa, conforme o fluxo aprovado.
- Não persistir imagens ou histórico funcional na cloud.
- Exercitar os encaminhamentos simulados de curadoria e retreinamento para YOLO, CNN e MNN, sem afirmar que modelos foram treinados.
- Medir o custo e o tempo das operações com imagens representativas antes de considerar validada a escolha de hospedagem gratuita.

## Decisões posteriores para a evolução UX — 29/10/2026

As chamadas reais à cloud permanecem obrigatórias no novo aplicativo. A usuária confirmou que o aplicativo deve continuar sorteando resultados por análise; exemplos determinísticos pertencem aos mockups. Testes automatizados poderão controlar respostas para verificar os caminhos, sem impor resultados fixos ao fluxo normal.

A usuária também esclareceu que as fotografias presentes nos artigos disponibilizados em `../TC2_Luisa/Referências/` serão usadas tanto como exemplos na biblioteca quanto como entradas escolhidas para testar o aplicativo. Esse uso inclui o envio ao Google Cloud quando a fotografia for selecionada para uma análise; a consulta da biblioteca não deve disparar upload. A autorização refere-se aos materiais fornecidos para o TCC. O levantamento documental não enviou essas fotografias à cloud.

O serviço fantasma poderá evoluir para suportar os novos caminhos, preservando compatibilidade com o aplicativo instalado e a condição de custo financeiro zero. Não houve implantação nem alteração de faturamento nesta etapa. A proposta de contratos, incerteza, revisões de imagem e navegação está em `ux/ARCHITECTURE.md`; a origem das imagens está em `ux/REFERENCE_AUDIT.md`. Esses documentos descrevem a próxima implementação, não funcionalidades já publicadas.

## Fontes oficiais consultadas

- Cloudflare Workers: https://www.cloudflare.com/products/workers/
- Preços: https://developers.cloudflare.com/workers/platform/pricing/
- Limites: https://developers.cloudflare.com/workers/platform/limits/
- Supabase: https://supabase.com/pricing
- Render: https://render.com/docs/free
- AWS Lambda: https://aws.amazon.com/lambda/pricing/
- Google Cloud Run: https://docs.cloud.google.com/run/docs/overview/what-is-cloud-run
- Preços Cloud Run: https://cloud.google.com/run/pricing
- Franquia e conta de faturamento Google: https://docs.cloud.google.com/free/docs/free-cloud-features
- Deploy Python e serviços de build: https://docs.cloud.google.com/run/docs/deploying-source-code
- Alertas de orçamento: https://docs.cloud.google.com/billing/docs/how-to/budgets

Na consulta de 21/10/2026, Workers Free informa 100.000 requisições/dia e 10 ms de CPU por execução. A adequação deve ser medida com os tamanhos reais dos arquivos de teste. Supabase Free informa pausa por inatividade; Render Free informa suspensão após 15 minutos sem tráfego e retomada de aproximadamente um minuto. Esses fatos ajudam a escolha, mas não constituem garantia de disponibilidade nem validação de desempenho do aplicativo.

Na mesma consulta, Lambda informa franquia mensal de 1 milhão de requisições e 400.000 GB-segundos para Event Functions. Cloud Run, no modo de cobrança por requisição, informa 2 milhões de requisições, 180.000 vCPU-segundos e 360.000 GiB-segundos mensais, com aplicação da franquia baseada em preços de us-central1. Essas franquias não equivalem a gratuidade de todos os serviços associados nem dispensam as condições da conta.
# Verificação da evolução UX — 29/10/2026

- Backend v2 publicado no serviço existente: revisão `pipeline-bucal-00003-kx2`, 100% do tráfego; v1 preservada.
- Smoke HTTPS v2 passou em 19 chamadas com pixels sintéticos, incluindo recorte manual, incerteza, três riscos, feedback e retry estável. Os testes não usaram fotografias clínicas.
- Limites conferidos: 0–1 instância no serviço/revisão, 1 vCPU, 512 MiB, concorrência 2, timeout 60 s, CPU por requisição e sem boost.
- A conta foi verificada em avaliação gratuita, sem upgrade para uma conta paga. A restrição de custo financeiro zero permanece.
- Contrato definitivo em `cloud/CONTRACT_V2.md`; registro de publicação em `cloud/README.md`.
