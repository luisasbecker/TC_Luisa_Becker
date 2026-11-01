# Cloud fantasma — Pipeline Bucal

Serviço Python para testes de integração, sem modelos de IA. A comunicação e o recorte dos pixels são reais. CNN, foco, risco, curadoria e retreinamento são simulados. Há seis classes e somente risco baixo, médio ou alto; nenhuma saída binária de diagnóstico.

## Atualização v2 publicada em 29/10/2026

A revisão **`pipeline-bucal-00003-kx2`** foi publicada no mesmo serviço e recebe 100% do tráfego. `/v1` permanece compatível; `/v2` atende à interface 0.3.0+4. O contrato completo está em [CONTRACT_V2.md](CONTRACT_V2.md).

A verificação HTTPS `smoke_v2.py` passou com **19 chamadas e imagens sintéticas**: saúde v1/v2, cinco etapas, falha de detecção, recorte manual materializado, concordância, classe alternativa, incerteza provisória, risco baixo/médio/alto, feedback e retry idêntico. Nenhuma fotografia dos artigos ou de paciente foi enviada nessa verificação. Os 21 testes locais do backend também passaram.

```sh
PYTHONPATH=cloud python3 cloud/smoke_v2.py https://pipeline-bucal-qpkmvmtgra-uc.a.run.app
```

O endereço anterior continua válido e foi o usado nos testes. A URL adicional fornecida pelo Cloud Run é `https://pipeline-bucal-430167517700.us-central1.run.app`.

Configuração conferida após a publicação: máximo **1** no serviço e na revisão, mínimo **0**, CPU por requisição, **1 vCPU / 512 MiB**, concorrência **2**, timeout **60 s**, CPU boost desabilitado. Foram reutilizadas as identidades existentes de build e execução; não houve expansão de papéis IAM ou alteração de acesso público.

O projeto deve permanecer com **custo financeiro zero**. Não foi realizado upgrade de faturamento. A configuração de escala não é um teto financeiro nem uma promessa de gratuidade permanente. Verificar as condições gratuitas vigentes antes de novas publicações e reavaliar a hospedagem quando necessário, sem ampliar a modalidade de cobrança sem autorização.

O primeiro build da atualização detectou um erro de sintaxe de destino no `COPY` de múltiplos arquivos do Dockerfile. O destino foi corrigido para `./`; o build subsequente `eed6ee4e-aa57-4a6f-a4d0-e26011b3c61b` e a publicação foram concluídos. Nenhum tráfego foi transferido para o build que falhou.

## Contrato atual e compatibilidade

O Flutter **0.3.0+4**, com versões instaladas e abertas em Android e iOS, usa v2 com análise, imagem, revisões e identidade de requisição. A classe da CNN e a decisão profissional permanecem distintas. **Incerteza não interrompe o pipeline:** usa a classe sugerida provisoriamente sem registrá-la como confirmada. Há seis formulários e seis módulos multimodais separados. O resultado é exclusivamente **risco baixo, risco médio ou risco alto**, sem porcentagens ou significado diagnóstico. A v1 abaixo documenta o contrato legado ainda disponível.

## Aleatoriedade normal e demonstrações reproduzíveis

O uso normal cria um identificador aleatório para cada análise. A cloud deriva
resultados independentes de classe e risco a partir desse identificador e do nome
do módulo. Novas análises podem gerar resultados diferentes ou repetir anteriores;
repetir a mesma requisição mantém a resposta estável, inclusive entre processos.
Imagem e respostas não determinam um risco clínico nesta simulação. Não há estado
de sessão persistido no servidor.

Os cenários do painel de demonstração e os mockups usam saídas fixas para reproduzir
percursos. O smoke HTTPS seleciona identidades para cobrir os três riscos; isso é
uma estratégia de teste, não uma opção para escolher o resultado no uso normal.

A v2 publicada inclui detecção encontrada/não encontrada, revisões de entradas,
recorte confirmado, incerteza provisória, seis formulários por seções, seis
componentes multimodais e confirmação de feedback. Os testes locais das duas
versões estão no fim deste documento. A documentação da interface e dos resultados
está em [`mobile/README.md`](../mobile/README.md) e
[`docs/ux/DELIVERY.md`](../docs/ux/DELIVERY.md).

O APK Android debug 0.3.0/build 4 foi distribuído manualmente pelo OneDrive e teve
sua cópia baixada comparada por SHA-256. A geração release build 5 permanece
pendente de dependências ausentes no cache de compilação. Nenhuma loja recebeu
uma publicação; consulte o [relatório de distribuição Android](../docs/ux/validation/ANDROID_DISTRIBUTION.md).

## Legado — contrato v1

Todas as operações usam `POST /v1/<operação>` com JSON: `session_id` (16–80 caracteres), `image_base64` (PNG/JPEG) e `image_hash` (SHA-256 dos bytes enviados). O app envia a original preparada em `detect` e o recorte confirmado nas demais etapas. Limites: 12 MiB por imagem, 18 MiB por requisição e 8 milhões de pixels. O app prepara imagens de até 1600 pixels no maior lado.

| Operação | Campos adicionais | Retorno principal |
| --- | --- | --- |
| `detect` | — | Caixa normalizada e recorte PNG real de uma região central ilustrativa |
| `focus` | `manual`: booleano | Indicador simulado; decisão visual continua com o profissional; curadoria/retreinamento YOLO em correção manual |
| `classify` | — | `class_index`: 0–5 |
| `questionnaire` | `class_index`, `suggested_class` | Três perguntas demonstrativas da classe final; curadoria/retreinamento CNN em discordância |
| `multimodal` | `class_index`, `answers`: lista de três respostas | Módulo da classe, `risk_index`: 0–2, orientação e curadoria/retreinamento MNN |

`GET /v1/health` verifica disponibilidade. A rota fica sob o prefixo da API porque `/healthz` retornou um 404 da infraestrutura Google, antes de chegar ao serviço, na verificação pública. As respostas das operações incluem versão, modo cloud, indicador de simulação, identidade da sessão e hash da imagem recebida. O app valida essa identidade antes de avançar. Corrigir a classe altera questionário e rota multimodal. O risco permanece independente de qualquer dado clínico.

O sorteio usa a identidade aleatória de cada sessão e funções separadas por módulo. Uma nova sessão permite outros resultados, com repetições. Reenviar a mesma operação permanece estável em diferentes processos/instâncias. Não há estado de sessão no servidor. Curadoria pode aceitar ou rejeitar um encaminhamento fictício; retreinamento apenas confirma o encaminhamento aceito, sem atualizar modelo.

## Implantar

O script deve ser executado no Cloud Shell autenticado no projeto escolhido:

```sh
bash cloud/deploy.sh ID_DO_PROJETO us-central1
```

Cria identidades separadas de build e execução, concede `roles/run.builder` somente à identidade de build e publica um serviço HTTPS de protótipo. A identidade de execução não recebe papéis de acesso a dados. O serviço é público, sem login de usuário; não contém segredos no app nem fornece acesso a imagens de outras requisições. Esta configuração destina-se aos testes com imagens sintéticas, não a atendimento clínico.

Configuração publicada: CPU por requisição, 1 vCPU, 512 MiB, concorrência 2, mínimo 0, máximo 1 instância, timeout de 60 segundos, sem CPU boost. O limite de instâncias reduz consumo; não é teto financeiro. Franquia, tráfego, build, artefatos e logs têm regras próprias. O script não altera nem faz upgrade da conta de faturamento. A primeira implantação pode exigir propagação das permissões de build.

A condição de uso aprovada é manter custo financeiro zero. Não fazer upgrade para
conta paga. Verificar a situação atual da conta e as franquias aplicáveis a
computação, tráfego, builds, artefatos e logs antes de implantar. Se a operação não
couber nas condições gratuitas disponíveis, a hospedagem deve ser reavaliada.

Se a primeira implantação falhar ao ler o código do bucket com `PERMISSION_DENIED`, confira se a identidade de build recebeu `roles/run.builder` e aguarde sua propagação antes de repetir. Esse papel já inclui `storage.objects.get`; não conceda papéis amplos adicionais sem identificar uma permissão efetivamente ausente.

Após obter a URL, executar:

```sh
python3 -m pip install -r cloud/requirements.txt
PYTHONPATH=cloud python3 cloud/smoke_v2.py https://URL_DO_SERVICO
```

Para apontar o Flutter a outro serviço verificado, use
`--dart-define=CLOUD_API_URL=https://URL_DO_SERVICO` e recompile. O transporte atual
está em `mobile/lib/core/services/analysis_transport.dart`; o cliente v1 legado
usa `mobile/lib/services/cloud_endpoint.dart`. Não colocar credenciais Google no
aplicativo. Falhas de rede não alternam silenciosamente para uma simulação local.

## Histórico — publicação v1 verificada em 22/10/2026

Os dados abaixo registram a implantação anterior. A revisão v2 de 29/10/2026,
descrita no início deste documento, a substituiu como revisão com tráfego.

- Projeto: `project-9387493a-f6b7-4a38-a3a`; região: `us-central1`.
- Serviço: `pipeline-bucal`; revisão: `pipeline-bucal-00002-kfk`, que recebia 100% do tráfego naquela verificação.
- URL: https://pipeline-bucal-qpkmvmtgra-uc.a.run.app
- `smoke.py` passou contra essa revisão: disponibilidade, cinco etapas do pipeline, recorte manual efetivamente recebido, correção de classe, três caminhos de curadoria/retreinamento fantasma e nova tentativa estável. Teste executado com imagem sintética.
- URL configurada no código Flutter e conferida no binário Release. A versão 0.2.1+3 foi compilada, instalada e iniciada no iPhone em 22/10/2026, após confirmar os três riscos pelas cinco etapas HTTPS no próprio aparelho, com imagens sintéticas e sessões de teste controladas. Esse registro é da versão anterior e não comprova uma execução completa da interface 0.3.0+4. Consulte as evidências atuais em [`docs/ux/validation/FINAL_RESULTS.json`](../docs/ux/validation/FINAL_RESULTS.json).

## Dados e logs

Imagens e respostas existem em memória apenas durante a requisição. O serviço não usa banco, bucket, cache ou arquivos de pacientes, nem registra o corpo das requisições. Respostas usam `Cache-Control: no-store`. Logs técnicos do provedor podem conter metadados das chamadas; isso é distinto de histórico clínico. O app mantém a sessão apenas em memória. O compartilhamento JSON existente continua opcional e não contém pixels.

## Verificação local

```sh
PYTHONPATH=cloud python3 -m unittest discover -s cloud/tests -v
cd mobile
flutter analyze
flutter test
# Contrato v2 contra Python local com Pillow instalado:
PIPELINE_PYTHON=python3 flutter test test/analysis_backend_contract_test.dart
# Contrato v1 legado, também sem socket local:
PYTHONPATH=../cloud TEST_PYTHON=python3 dart tool/verify_cloud_pipeline.dart
dart tool/verify_pipeline.dart
```

O teste de contrato chama os mesmos módulos Python a partir do cliente Dart, mas não substitui a verificação HTTPS após a implantação.
