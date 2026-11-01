# Comunicação por etapa — revisão de 01/11/2026

## Integração preservada

O aplicativo usa `HttpsAnalysisTransport` no modo cloud. Cada etapa é uma
requisição HTTPS ao serviço Google Cloud Run existente, sem substituição local
silenciosa em caso de erro:

| Etapa | Endpoint | Módulo fantasma esperado |
| --- | --- | --- |
| Delimitar a região | `POST /v2/detect` | `YoloDetectionStub` |
| Avaliar o foco | `POST /v2/focus` | `FocusEvaluationStub` |
| Sugerir classe | `POST /v2/classify` | `CnnClassificationStub` |
| Obter formulário da classe | `POST /v2/questionnaire` | `QuestionnaireStub` |
| Produzir risco demonstrativo | `POST /v2/multimodal` | Um dos seis multimodais da classe |

A original preparada segue para detecção. O recorte confirmado, inclusive quando
corrigido manualmente, segue para as outras quatro etapas. Imagem, análise,
requisição, revisões e SHA-256 acompanham os pedidos. O retorno deve corresponder
a esses dados e ao módulo esperado. No multimodal, o controlador também verifica
o módulo específico da classe efetivamente utilizada.

O protocolo continua simulado: não executa YOLO, análise Fourier, CNN nem modelos
multimodais reais. Classe e risco são derivados separadamente da identidade
aleatória de cada nova análise; repetir a mesma requisição mantém a mesma saída.
Foco simulado não substitui a confirmação visual pelo profissional.

## Evidência no aplicativo

`AnalysisController.pendingOperation` identifica somente a chamada que está
aguardando resposta válida. É removida na conclusão, erro, cancelamento ou troca
da análise. Respostas atrasadas de uma execução invalidada não geram sucesso.

Os eventos `operation_started`, `operation_completed` e `operation_error` incluem
`operation`, `request_id` e `execution_mode`. Só a conclusão validada registra
`module` e `duration_ms`. A duração inclui o transporte e a validação no cliente;
não é uma medida isolada do tempo de execução no servidor. A exportação continua
sem fotografias, base64, nomes de arquivos ou conteúdo arbitrário da resposta.

## Verificação local

Os testes de `mobile/test/analysis_controller_test.dart` verificam explicitamente:

- Ordem das cinco chamadas e ausência de processamento offline no modo cloud.
- Circulação dos pixels do recorte manual e da mesma identidade de imagem.
- Estado pendente durante cada chamada, sem registrar conclusão antecipada.
- Recuperação após falha em cada etapa, mantendo payload e identidade no retry.
- Recusa de identidade de imagem ou módulo divergente em todas as etapas.
- Descarte de resposta atrasada após iniciar outra análise.

O teste `analysis_backend_contract_test.dart` continua verificando o contrato
contra a implementação Python real, localmente, incluindo as seis rotas de
questionários e multimodais, correção e incerteza. Esses testes não consomem
requisições Cloud Run e não equivalem a uma verificação HTTPS do serviço remoto.

Em 01/11/2026, os dois arquivos de teste acima passaram: **47 testes**, incluindo
20 novos casos de espera, falha, retry e rejeição de recibos por etapa. A execução
incluiu o contrato Python com Pillow, sem testes ignorados nesses arquivos.

## Verificação HTTPS em 01/11/2026

O serviço publicado respondeu à saúde v2. Em seguida, `cloud/smoke_v2.py`
passou contra `https://pipeline-bucal-qpkmvmtgra-uc.a.run.app`, usando somente
pixels sintéticos. Foram verificados saúde v1/v2, as cinco etapas HTTPS,
falha de detecção, pixels do recorte manual, decisões confirmada/corrigida/incerta,
os três riscos, feedback e estabilidade ao repetir a requisição.

Essa evidência verifica o serviço remoto. Os testes Flutter locais verificam o
controlador e a interface; as capturas controladas não são capturas de um aparelho
nem comprovam, isoladamente, comunicação remota.

## Operação gratuita e implantação

Esta revisão não cria serviços, altera recursos, muda faturamento, executa
treinamento ou faz deploy. Reutiliza os endpoints existentes. Mantêm-se as
condições documentadas de mínimo zero e máximo uma instância; isso reduz consumo,
mas não constitui teto financeiro. O teste remoto foi limitado ao smoke existente,
sem novos recursos ou mudança no faturamento. Não fazer upgrade de faturamento;
uma eventual nova implantação exige conferir as condições gratuitas da conta.

O registro histórico da publicação HTTPS encontra-se em
[`cloud/README.md`](../../../cloud/README.md). Esta revisão não mediu o custo
acumulado da conta nem alterou a revisão publicada.
