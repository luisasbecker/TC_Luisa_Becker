# Especificação técnica: protótipo do pipeline de lesões bucais

## 1. Objetivo

Implementar um esboço funcional e teórico, em Python, do pipeline descrito no relatório do TCC I **“Integração de Diferentes Algoritmos de Inteligência Artificial Através de um Pipeline para Detecção, Processamento e Classificação de Lesões Bucais em Imagens Clínicas”**.

O protótipo comprovará o fluxo de informações, as decisões intermediárias, a experiência de uso e os registros de feedback. Não haverá detecção, processamento, classificação, análise multimodal ou treinamento reais.

## 2. Fonte principal e limites

O arquivo `TCC_I__Luisa_Becker_v6.pdf` é a fonte principal para o fluxo, os módulos e a terminologia. Os artigos presentes no projeto são apenas fontes contextuais e não ampliam o escopo.

O sistema:

- é destinado ao profissional da saúde;
- atua somente como ferramenta de apoio;
- não produz diagnóstico definitivo;
- classifica a saída final como risco baixo, médio ou alto de câncer;
- não utiliza porcentagem como resultado final;
- orienta avaliação médica adequada em qualquer classe de risco;
- não armazena automaticamente imagens ou dados clínicos;
- não utiliza imagens reais de pacientes como exemplos;
- não executa treinamento ou retreinamento.

## 3. Abordagem escolhida

Será usada uma arquitetura com núcleo Python independente e interface Streamlit. A lógica do pipeline não dependerá do Streamlit, permitindo testes automatizados diretos e futura substituição da interface.

Foram descartadas:

- uma máquina de estados formal, por acrescentar complexidade desnecessária ao protótipo;
- a concentração da lógica em `app.py`, por dificultar testes e manutenção.

## 4. Estrutura prevista

```text
.
├── app.py
├── requirements.txt
├── README.md
├── src/
│   └── pipeline/
│       ├── __init__.py
│       ├── enums.py
│       ├── models.py
│       ├── state.py
│       ├── yolo_stub.py
│       ├── focus_stub.py
│       ├── cnn_stub.py
│       ├── questionnaire_stub.py
│       ├── multimodal_stub.py
│       ├── intelligent_system.py
│       └── pipeline_controller.py
├── tests/
│   └── test_pipeline_flow.py
└── docs/
    └── superpowers/specs/
        └── 2026-08-11-pipeline-lesoes-bucais-design.md
```

## 5. Modelo de domínio

### 5.1 Enumerações

- `ElementaryLesionClass`: pápula/nódulo, mácula/mancha, vesícula/bolha, erosão, úlcera e placa.
- `ImageQualityStatus`: adequada e inadequada.
- `UserDecision`: concorda/aceita e discorda/rejeita, conforme o ponto do fluxo.
- `CancerRiskClass`: risco baixo, médio e alto de câncer.
- `FeedbackEventType`: recorte manual, discordância da CNN, classe corrigida, candidata a retreinamento e metadados do fluxo.
- `PipelineStep`: etapas explícitas da sessão, usada para impedir transições incoerentes.

### 5.2 Dataclasses

Serão representados por dataclasses:

- imagem original;
- imagem recortada;
- resultado da detecção YOLO;
- resultado da avaliação de foco;
- resultado da CNN;
- decisão do usuário sobre concordância;
- classe corrigida pelo usuário;
- respostas do questionário;
- resultado multimodal;
- evento de feedback;
- evento do histórico;
- estado completo da sessão;
- configuração determinística dos stubs.

Cada imagem terá identificador, nome ou caminho, origem e metadados suficientes para comprovar sua passagem entre módulos. Bytes de imagem não serão incluídos no resumo JSON.

## 6. Componentes

### 6.1 YOLO fantasma

Receberá a imagem original e retornará:

- sucesso configurável;
- bounding box fictícia configurável;
- confiança fictícia interna;
- referência para uma imagem recortada simulada.

Não fará inferência nem detecção real. A classe de detecção será somente “lesão”.

### 6.2 Correção manual do recorte

Se o recorte automático for rejeitado, a interface oferecerá:

- ajuste de coordenadas fictícias; ou
- upload de uma imagem corrigida.

Ambas as opções produzirão uma `CroppedImage`, atualizarão o fluxo e gerarão feedback para curadoria e possível retreinamento futuro da YOLO.

### 6.3 Processamento e foco fantasmas

O módulo receberá a imagem recortada e produzirá um escore interno fictício e um status configurável de qualidade. A avaliação subjetiva do profissional da saúde será uma decisão separada.

Se a qualidade visual for rejeitada, a sessão será encerrada sem CNN ou modelo multimodal, com solicitação de novo envio da imagem.

### 6.4 CNN fantasma

Receberá a imagem processada e retornará:

- classe de lesão elementar configurável;
- confiança fictícia opcional e interna;
- descrições de exemplos sintéticos da classe.

Os exemplos serão cartões gráficos não clínicos, identificados como placeholders.

Em caso de concordância, a classe sugerida orientará as etapas seguintes. Em caso de discordância, o sistema registrará a imagem candidata, a classe sugerida, a discordância e a classe alternativa selecionada. A classe corrigida passará a orientar o questionário e o modelo multimodal específico por classe.

### 6.5 Questionários fantasmas

Haverá um conjunto de perguntas distinto para cada classe. Toda pergunta será explicitamente identificada como simulada e pendente de definição futura por profissional especialista em estomatologia.

O protótipo não atribuirá validade clínica às perguntas. As respostas serão apenas dados estruturados para demonstrar a integração multimodal.

### 6.6 Modelos multimodais fantasmas

Existirão seis classes separadas:

- `PapuleNoduleMultimodalStub`;
- `MaculeSpotMultimodalStub`;
- `VesicleBullaMultimodalStub`;
- `ErosionMultimodalStub`;
- `UlcerMultimodalStub`;
- `PlaqueMultimodalStub`.

Cada modelo receberá a imagem processada, a classe final e as respostas do questionário. A saída configurável será exclusivamente uma enumeração de risco baixo, médio ou alto de câncer, sem porcentagens.

Cada resultado conterá a mensagem obrigatória de que o sistema é uma ferramenta de apoio, não substitui avaliação profissional e não substitui exames complementares quando indicados. A mensagem orientará a busca por avaliação médica adequada independentemente do risco.

### 6.7 Sistema inteligente

O sistema inteligente será um registrador e curador simulado. Ele receberá:

- recortes manuais;
- discordâncias entre profissional da saúde e CNN;
- classes corrigidas;
- imagens candidatas a retreinamento futuro;
- metadados do fluxo.

Os eventos serão marcados como candidatos a avaliação/curadoria. Nenhum retreinamento será executado e nenhum dado será incorporado automaticamente a uma base.

### 6.8 Controlador do pipeline

O `PipelineController` será a única camada responsável por transições e regras do fluxo. Ele receberá dependências configuráveis, atualizará `SessionState` e registrará eventos de histórico.

Operações públicas previstas:

- iniciar sessão com imagem;
- executar detecção;
- aceitar ou corrigir recorte;
- executar avaliação de foco;
- registrar validação subjetiva da qualidade;
- executar CNN;
- registrar concordância ou correção;
- obter e responder questionário;
- executar modelo multimodal correspondente;
- gerar resumo serializável.

Transições fora de ordem gerarão erro claro sem corromper o estado da sessão.

## 7. Fluxo completo

1. O profissional da saúde envia uma imagem.
2. A YOLO fantasma gera bounding box e recorte automático.
3. O usuário aceita o recorte ou realiza correção manual simulada.
4. Correções são registradas no sistema inteligente.
5. O módulo fantasma de processamento/foco avalia a imagem recortada.
6. O usuário confirma ou rejeita a qualidade visual.
7. Se rejeitar, a sessão solicita novo envio e termina sem resultado multimodal.
8. Se aceitar, a CNN fantasma sugere uma classe de lesão elementar.
9. A interface mostra cartões sintéticos da classe e solicita concordância.
10. Em concordância, a classe sugerida é a classe final.
11. Em discordância, o sistema registra feedback, mostra as demais classes e recebe uma classe corrigida.
12. O questionário fantasma específico da classe final é respondido.
13. O modelo multimodal específico por classe recebe imagem, classe final e respostas.
14. O resultado apresenta risco baixo, médio ou alto de câncer e a orientação médica obrigatória.
15. A interface apresenta e permite baixar o resumo JSON da sessão.

## 8. Interface Streamlit

A aplicação será organizada como um assistente de etapas. A barra lateral conterá uma área “Configuração da simulação” com valores fixos para:

- resultado e coordenadas da YOLO;
- resultado interno de foco;
- classe sugerida pela CNN;
- risco produzido pelo modelo multimodal.

A tela principal mostrará:

- objetivo e aviso de uso;
- etapa atual;
- upload de imagem;
- visualização do recorte automático ou corrigido;
- decisões com botões e seletores;
- cartões sintéticos das classes;
- questionário placeholder;
- resultado final;
- histórico e resumo JSON;
- download do JSON;
- opção de reiniciar a sessão.

O estado interativo será mantido em `st.session_state`. Nenhuma imagem será salva automaticamente no disco.

## 9. Serialização e resumo

O resumo final deverá conter:

- nome ou caminho da imagem original;
- identificador da imagem;
- resultado da YOLO fantasma;
- indicação e detalhes do recorte manual;
- resultado interno do foco e validação subjetiva;
- classe sugerida pela CNN;
- concordância ou discordância;
- classe final;
- respostas do questionário;
- modelo multimodal utilizado;
- risco final, quando houver;
- mensagem final, quando houver;
- eventos enviados ao sistema inteligente;
- indicações de curadoria e retreinamento futuro;
- histórico completo de etapas.

O JSON será produzido em UTF-8, com rótulos legíveis, sem bytes de imagem e sem resultados percentuais.

## 10. Tratamento de erros

- Ausência de imagem bloqueará o início com mensagem clara.
- Falha simulada da YOLO impedirá avanço até novo envio ou nova configuração.
- Recorte manual sem coordenadas válidas ou sem imagem corrigida será rejeitado.
- Classe corrigida igual à classe rejeitada será impedida na interface e validada pelo controlador.
- Questionário incompleto não seguirá para a análise multimodal.
- Configuração de risco fora da enumeração será rejeitada.
- Transições fora de ordem levantarão exceção de domínio clara.

## 11. Estratégia de testes

Os testes usarão `unittest`, disponível na biblioteca padrão, e exercitarão a API pública real do controlador.

Cenários obrigatórios:

1. recorte automático aceito, foco adequado e concordância com a CNN;
2. recorte automático rejeitado, recorte manual registrado e continuidade normal;
3. foco inadequado com encerramento e solicitação de novo envio;
4. discordância da CNN, seleção alternativa e feedback ao sistema inteligente;
5. saída multimodal sempre pertencente às três classes de risco;
6. ausência de saída final percentual;
7. presença da orientação médica em todas as classes de risco.

Verificações adicionais:

- existência e roteamento dos seis stubs multimodais;
- bloqueio de transições inválidas;
- serialização completa do resumo;
- ausência de bytes e percentuais no JSON final;
- preservação do vínculo entre imagem original, recorte e imagem processada;
- ausência de resultado multimodal quando a qualidade é rejeitada.

## 12. Dependências e execução

O núcleo utilizará apenas a biblioteca padrão do Python. A interface dependerá de Streamlit e Pillow, declarados em `requirements.txt`.

Os testes poderão ser executados sem Streamlit:

```bash
python -m unittest discover -s tests -v
```

A interface será executada após instalação das dependências:

```bash
python -m pip install -r requirements.txt
python -m streamlit run app.py
```

## 13. Critérios de conclusão

A implementação estará concluída quando:

- todos os módulos fantasmas estiverem identificados e separados;
- os desvios principais forem navegáveis;
- os seis modelos multimodais específicos por classe existirem;
- feedbacks e candidatos a retreinamento forem registrados sem treinamento real;
- o resumo demonstrar a passagem da imagem por todas as etapas executadas;
- a saída final nunca for diagnóstico ou porcentagem;
- todas as saídas de risco contiverem orientação médica;
- todos os testes automatizados passarem;
- o README documentar instalação, execução, limitações e cenários.
