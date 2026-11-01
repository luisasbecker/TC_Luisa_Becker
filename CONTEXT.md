# Pipeline de lesões bucais

Vocabulário do protótipo acadêmico de apoio ao fluxo de análise de lesões bucais.

## Linguagem

**Simulação fantasma**: Execução demonstrativa dos módulos com saídas fictícias, sem inferência clínica ou modelos de IA treinados.
_Evitar_: Diagnóstico automático, IA validada.

**Recorte confirmado**: Imagem da região aprovada pelo profissional, incluindo a correção manual quando houver. É a imagem de referência para as etapas seguintes.
_Evitar_: Original como imagem ativa após o recorte.

**Classe de lesão elementar**: Uma de seis categorias: pápula/nódulo, mácula/mancha, vesícula/bolha, erosão, úlcera ou placa.
_Evitar_: Diagnóstico de câncer.

**Risco simulado**: Resultado fictício baixo, médio ou alto usado para testar o fluxo. Não expressa probabilidade clínica real.
_Evitar_: É câncer, não é câncer, porcentagem de câncer.

**Sistema inteligente**: Módulo previsto para avaliar correções e candidaturas ao retreinamento; nesta fase, sua avaliação é fictícia.

**Retreinamento fantasma**: Representação do encaminhamento a um futuro retreinamento, sem aprendizado ou alteração de modelos.

**Demonstração offline**: Execução local explicitamente escolhida, distinguida da simulação com comunicação real à cloud.

**Análise**: Percurso iniciado pelo profissional para avaliar uma lesão, incluindo revisões, retornos e eventual substituição de fotografia antes da conclusão.

**Imagem de referência**: Exemplo identificado em uma fonte científica e apresentado para comparação. Pode ser escolhido explicitamente como imagem de teste; sua presença na biblioteca não significa que foi analisado.

**Classe provisória**: Sugestão original utilizada para continuar o fluxo quando o profissional declara incerteza. Não corresponde a concordância ou confirmação clínica.

**Risco aceito da simulação**: Saída fictícia recebida e associada às entradas atuais da análise. É distinta de uma configuração de demonstração ou de um resultado anterior invalidado.
