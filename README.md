# Pipeline para Detecção, Processamento e Classificação de Lesões Bucais

Protótipo funcional e teórico, em Python, do pipeline proposto no TCC I **“Integração de Diferentes Algoritmos de Inteligência Artificial Através de um Pipeline para Detecção, Processamento e Classificação de Lesões Bucais em Imagens Clínicas”**.

O objetivo atual é validar o fluxo de informações, as decisões do profissional da saúde e a passagem da imagem entre módulos. Todos os módulos computacionais são **stubs/blocos fantasmas determinísticos**. Não há IA real, inferência clínica, treinamento ou retreinamento.

## Aviso importante

O sistema é somente uma ferramenta de apoio. A saída final expressa **risco baixo, médio ou alto de câncer**, sem produzir diagnóstico definitivo. Em qualquer classe de risco, o protótipo orienta a busca por avaliação médica adequada e informa que não substitui avaliação profissional nem exames complementares quando indicados.

Não utilize imagens reais ou identificáveis de pacientes neste protótipo.

## Fluxo implementado

1. Upload de imagem clínica simulada.
2. Detecção e recorte por YOLO fantasma, tratando “lesão” como classe única.
3. Validação do recorte automático pelo profissional da saúde.
4. Correção por coordenadas simuladas ou envio de imagem corrigida.
5. Registro do recorte manual pelo sistema inteligente para curadoria futura.
6. Processamento e avaliação interna de foco por stub.
7. Validação subjetiva da qualidade visual.
8. Encerramento com solicitação de nova imagem quando a qualidade for rejeitada.
9. Classificação fantasma em uma das seis classes de lesão elementar.
10. Exibição de cartões sintéticos e decisão de concordância.
11. Em discordância, seleção de classe corrigida e registro de feedback.
12. Questionário simulado específico da classe final.
13. Execução do modelo multimodal específico por classe.
14. Saída final em risco baixo, médio ou alto de câncer, acompanhada de orientação médica.
15. Visualização e download do histórico completo em JSON.

As seis classes de lesão elementar são:

- pápula/nódulo;
- mácula/mancha;
- vesícula/bolha;
- erosão;
- úlcera;
- placa.

## Arquitetura

| Arquivo | Responsabilidade |
|---|---|
| `app.py` | Assistente Streamlit e visualização temporária das imagens. |
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
| `tests/` | Testes automatizados do domínio, stubs, fluxo e segurança da saída. |

O núcleo não depende do Streamlit. Isso permite testar o pipeline diretamente e substituir a interface no futuro.

## Pré-requisitos

- Python 3.11 ou superior;
- `pip` disponível.

O protótipo foi verificado com Python 3.14, Streamlit 1.66 e Pillow 11.3.

## Instalação

Clone o repositório e acesse a pasta do projeto:

```text
git clone https://github.com/luisasbecker/TC_Luisa_Becker.git
cd TC_Luisa_Becker
```

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

## Execução

```powershell
python -m streamlit run app.py
```

O terminal exibirá o endereço local da aplicação, normalmente `http://localhost:8501`. Abra esse endereço no navegador caso a interface não seja aberta automaticamente.

Nenhuma imagem é gravada automaticamente: os bytes permanecem apenas na sessão em memória do Streamlit. O resumo JSON contém somente identificadores e metadados do fluxo.

Para encerrar a aplicação, pressione `Ctrl+C` no terminal em que o Streamlit está sendo executado.

## Configuração da simulação

Na barra lateral, é possível fixar:

- sucesso ou falha do YOLO fantasma;
- bounding box e confiança fictícias;
- escore e status internos de foco;
- classe sugerida pela CNN fantasma;
- confiança fictícia da CNN;
- risco retornado pelo modelo multimodal.

Esses valores não resultam de análise da imagem. Eles existem apenas para reproduzir cenários de navegação e teste.

## Cenários manuais principais

### 1. Fluxo concordante

1. Mantenha a configuração padrão.
2. Envie uma imagem.
3. Execute o YOLO fantasma e aceite o recorte.
4. Execute o foco e aceite a qualidade.
5. Execute a CNN e concorde com a classe.
6. Responda o questionário simulado.
7. Execute o modelo multimodal.

Resultado esperado: risco configurado, mensagem médica e JSON completo.

### 2. Correção manual do recorte

1. Rejeite o recorte automático.
2. Ajuste as coordenadas ou envie uma imagem corrigida.
3. Continue o fluxo.

Resultado esperado: eventos de recorte manual, curadoria e candidatura ao retreinamento futuro da YOLO.

### 3. Qualidade inadequada

1. Execute o módulo de foco.
2. Informe que a qualidade visual não é suficiente.

Resultado esperado: encerramento antes da CNN e solicitação de novo envio.

### 4. Discordância da CNN

1. Rejeite a classe de lesão elementar sugerida.
2. Compare os cartões sintéticos das demais classes.
3. Escolha uma classe corrigida.

Resultado esperado: eventos de discordância, correção e candidatura ao retreinamento futuro da CNN; a classe corrigida orienta questionário e multimodal.

## Testes automatizados

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
- vínculo entre imagem original e recortes.

## Dados, feedback e privacidade

O sistema inteligente apenas cria registros em memória. Recortes manuais e discordâncias são marcados como candidatos à avaliação/curadoria e ao retreinamento futuro; nada é incorporado automaticamente e nenhum retreinamento é executado.

O protótipo não inclui base de pacientes, autenticação, banco de dados ou persistência de imagens. O download do JSON ocorre somente quando solicitado pelo usuário.

## Limitações e trabalho futuro

- YOLO, foco, CNN e multimodais são stubs sem inferência real.
- As perguntas são placeholders claramente marcadas como simuladas.
- Os questionários clínicos reais serão definidos futuramente por profissional especialista em estomatologia.
- As regras clínicas e os limiares reais das classes de risco ainda não foram definidos ou validados.
- Imagens candidatas exigirão curadoria antes de qualquer uso futuro.
- Uma etapa posterior deverá tratar consentimento, anonimização, segurança, descarte e LGPD antes de receber dados reais.
