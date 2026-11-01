# Contrato cloud v2 — Pipeline Bucal

Publicado em 29/10/2026 na revisão `pipeline-bucal-00003-kx2`, conforme o
registro e a verificação HTTPS em [README.md](README.md). A revisão do cliente
em 01/11/2026 reforça a validação e a visibilidade das chamadas; não altera
o contrato nem realiza uma nova implantação do backend.
Serviço WSGI existente, sem banco ou armazenamento de imagens. `/v1` permanece
compatível com o app 0.2.1, incluindo sorteio `ghost-v1`, detecção positiva e seus
rótulos antigos. O novo cliente usa `/v2` explicitamente; não há fallback silencioso.

## Envelope

`POST /v2/{detect|focus|classify|questionnaire|multimodal|feedback}` com JSON.
`GET /v2/health` responde `status:ok`, `api_version:"2"`, `simulation_only:true`.

Campos comuns obrigatórios:

| Campo | Tipo/regra |
| --- | --- |
| `analysis_id` | String de 16–80 caracteres `[A-Za-z0-9_-]`; nova identidade aleatória por análise |
| `image_id` | Mesmo formato; nova identidade para cada fotografia dentro da análise |
| `request_id` | Mesmo formato; preservar ao tentar novamente a mesma requisição |
| `crop_revision` | Inteiro 0–2147483647; mínimo 1 de `focus` em diante |
| `decision_revision` | Mesmo intervalo; mínimo 1 em `questionnaire` e `multimodal` |
| `answers_revision` | Mesmo intervalo; mínimo 1 em `multimodal` |
| `image_hash` | SHA-256 hexadecimal minúsculo dos bytes enviados/referenciados |
| `image_base64` | Somente nas cinco etapas de processamento; PNG/JPEG preparado |

Toda resposta de operação ecoa os sete campos de identidade/revisão/hash, além de
`api_version:"2"`, `operation`, `execution_mode:"cloud"`, `simulation_only:true`,
`data_stored:false`, `module` e `feedback:[]`. Campos fora do contrato são rejeitados;
não existe parâmetro de cenário, seed, risco ou classe forçada.

A original preparada segue para `detect`; somente os pixels do recorte confirmado
seguem para `focus`, `classify`, `questionnaire` e `multimodal`. O servidor valida o
hash real. Limites preservados: 18 MiB por requisição, 12 MiB por imagem e 8 milhões
de pixels. Respostas usam `Cache-Control:no-store`.

**O servidor não guarda estado.** Ecos de revisão identificam a entrada processada;
não demonstram que o servidor conhece requisições anteriores. O controlador deve
descartar respostas de imagem/revisão/operação que não sejam mais atuais, manter os
estados e invalidar dependências. Trocar a fotografia mantém `analysis_id`, muda
`image_id` e reinicia a detecção; trocar a classe invalida formulários incompatíveis.

## Operações

### `detect`

Sem campos adicionais. Retorna `detected:bool`, `detection_status:"found"|"not_found"`,
`box:{left,top,right,bottom}|null`, `crop_base64:string|null`, `crop_hash:string|null`.
A caixa é normalizada (0–1); o recorte retornado contém pixels reais. A localização
central é ilustrativa. A detecção é fantasma, não depende da aparência da imagem.

O caminho de ausência de detecção é derivado do identificador aleatório da análise
(um dos oito valores da função de simulação), sem significado de desempenho clínico.
Nesse caso não há ROI e há feedback de falha. O app oferece recorte manual ou nova
fotografia. Uma revisão de recorte zero é recusada nas etapas seguintes.

### `focus`

Recebe `manual:bool` e `box:{left,top,right,bottom}` com números finitos e
`0 <= left < right <= 1`, `0 <= top < bottom <= 1`.
Retorna `adequate:bool`, `user_decides:true`. A avaliação visual continua sendo decisão
do profissional; não é inferida do indicador fantasma. Recorte manual gera feedback
simulado candidato à curadoria YOLO.

### `classify`

Retorna `class_index:0..5` e `class_label` na ordem: pápula/nódulo, mácula/mancha,
vesícula/bolha, erosão, úlcera, placa. Essa sugestão original deve ser preservada.

### Decisão profissional

`questionnaire` e `multimodal` recebem obrigatoriamente:

```json
{
  "decision": {
    "status": "uncertain",
    "suggested_class": 4,
    "selected_class": null
  }
}
```

`suggested_class` deve corresponder à sugestão simulada da análise. Regras:

| `status` | `selected_class` | Resultado |
| --- | --- | --- |
| `confirmed` | Igual à sugestão | Classe confirmada pelo profissional |
| `corrected` | Outra classe válida | Classe escolhida pelo profissional |
| `uncertain` | `null` | Sugestão original usada provisoriamente, sem confirmação |

Retornam `decision`, `class_index`, `effective_class`, `class_confirmed`, `provisional`
e `decision_policy`. Os dois índices representam a classe efetiva. Em incerteza,
`class_confirmed:false`, `provisional:true` e política
`use_suggested_provisionally_v1`. Essa política está isolada em
`UseSuggestedClassProvisionally`, não representa regra clínica e pode ser substituída.

### `questionnaire`

Retorna `questionnaire_id:"lesion-{0..5}-demo"`, `questionnaire_version:1`, `title`,
`demonstrative:true`, `clinical_review_pending:true` e `sections`:

```json
[
  {"id":"context","title":"Contexto informado","questions":[
    {"id":"c4_context","prompt":"…","options":["Menos de 2 semanas","Entre 2 e 4 semanas","Mais de 4 semanas","Não informado"]}
  ]},
  {"id":"observations","title":"Observações sobre a alteração","questions":[
    {"id":"c4_observation","prompt":"…","options":["Não","Sim","Não informado"]},
    {"id":"c4_change","prompt":"…","options":["Não","Sim","Não informado"]}
  ]}
]
```

Há um formulário versionado por classe, com IDs próprios `c{classe}_context`,
`c{classe}_observation` e `c{classe}_change`. São perguntas demonstrativas baseadas
nas informações já presentes no protótipo, sem critérios diagnósticos ou influência
no sorteio. O cliente deve renderizar a estrutura recebida e não codificar perguntas.
Correção e incerteza geram feedback CNN distinto de concordância.

### `multimodal`

Além de `decision`, recebe `questionnaire_id`, `questionnaire_version` (inteiro) e
`answers:{questionId:string}`. Exige exatamente os IDs e opções do formulário da
classe efetiva. Formulário anterior, respostas de outra classe e campos incompletos
são recusados.

Retorna `risk:"low"|"medium"|"high"`, `risk_index:0..2`,
`risk_label:"Risco baixo"|"Risco médio"|"Risco alto"`, `message`, `disclaimer`,
`text_review_pending:true`, identificação do formulário e metadados da decisão.
`provisional_notice` contém o aviso de classe não confirmada ou `null`.

`module` identifica uma de seis classes de implementação separadas em
`multimodal_v2.py`, todas com a interface `evaluate(analysis_id,image_hash,answers,decision)`.
Elas não usam pixels, respostas ou classe para inferir risco. O risco e a sugestão CNN
usam fluxos de hash distintos derivados de `analysis_id`. Nova análise pode variar;
repetição da mesma análise permanece estável, mesmo com outra fotografia/resposta.
Nenhuma porcentagem, treinamento ou diagnóstico real é retornado.

### `feedback`

Não recebe `image_base64`; só identidade/hash da imagem já vinculada à análise.
Recebe `event:{event_id,type,details}`. `event_id` usa o formato dos outros IDs;
`type` é snake_case de 2–64 caracteres, por exemplo `manual_crop`,
`detection_failed`, `class_uncertain`, `class_corrected`, `quality_rejected`,
`image_replaced` ou `navigation_return`.

`details` admite apenas: `reason`, `stage`, `source`, `previous_image_id`,
`previous_image_hash`, `suggested_class`, `selected_class`, `effective_class`,
`status`, `provisional`, `class_confirmed`, `from_stage`, `to_stage`, `box` e
`candidate_for_review`. Usar valores demonstrativos, sem texto identificável.
Os valores são escalares, strings de até 160 caracteres; o objeto tem limite de
2048 caracteres serializados. `box` usa a validação da ROI; `candidate_for_review`
é estritamente booleano.

Retorna `received:true`, o `event_id`, `status:"simulated_acknowledged"` e recibo
de curadoria fantasma em `feedback`. Esse recibo inclui `clinical_validation:false`,
`data_stored:false` e `retraining.model_updated:false`. Repetir o mesmo evento gera
confirmação estável; isso não significa deduplicação persistida ou registro remoto.
O cliente conserva eventos pendentes quando a rede falhar e só exibe confirmação
após receber a resposta correspondente.

## Validação e publicação

```sh
PYTHONPATH=cloud python3 -m unittest discover -s cloud/tests -v
# Somente após publicação e verificação das condições gratuitas da conta:
python3 cloud/smoke.py https://URL_DO_SERVICO
python3 cloud/smoke_v2.py https://URL_DO_SERVICO
```

O contrato utiliza o mesmo serviço existente, sem banco ou armazenamento clínico.
A revisão do cliente em 01/11/2026 não publica serviço nem altera faturamento.
O Dockerfile inclui os módulos v2 no mesmo contêiner. Fixtures controladas pertencem
a testes/mockups; não há seleção manual de saídas no endpoint utilizado pelo app.
