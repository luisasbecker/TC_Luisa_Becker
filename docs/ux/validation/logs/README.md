# Evidências de validação

Os relatórios JSON versionados resumem as verificações executadas. Logs brutos
de compilação, depuração e testes são gerados localmente e ignorados pelo Git,
pois podem conter caminhos pessoais ou identificadores do ambiente.

Na verificação de 01/11/2026:

- `flutter analyze --no-pub`: sem problemas.
- Suite Flutter: 71 testes aprovados, incluindo o contrato Python v2, sem testes ignorados.
- Suite Python do backend: 21 testes aprovados.

Os comandos de execução estão no [guia mobile](../../../../mobile/README.md) e
no [guia da API](../../../../cloud/README.md). Esses resultados automatizados
não representam uma avaliação clínica ou um estudo com profissionais de saúde.
