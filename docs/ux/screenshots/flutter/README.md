# Evidências renderizadas pelo Flutter

Estas dez capturas foram geradas a partir dos widgets reais de `mobile/lib`, em um teste de renderização Flutter de 390 × 844 pixels lógicos. Incluem a fonte Inter embarcada, o logo do aplicativo, os temas claro e escuro e as imagens locais publicadas nas fontes do TCC. Não são capturas de Figma nem evidência de instalação no iPhone.

- `light-home.png` e `dark-home.png`: tela inicial e menu flutuante.
- `light-classification.png` e `dark-classification.png`: classe sugerida e recorte em uso.
- `light-risk-low.png` / `dark-risk-low.png`: resultado de baixo risco.
- `light-risk-medium.png` / `dark-risk-medium.png`: resultado de médio risco.
- `light-risk-high.png` / `dark-risk-high.png`: resultado de alto risco; o cenário segue com classe não confirmada, cujo aviso permanece na tela rolável.

As saídas são fixtures determinísticas de teste. A utilização normal do aplicativo continua sorteando classe e risco por análise. As capturas mostram a posição inicial da tela, com conteúdo adicional acessível por rolagem. Não representam validação clínica nem avaliação com profissionais.

A fotografia usada na fixture pertence a Gomes et al. (2023), Figura 2, categoria Úlcera, DOI 10.3390/ijerph20053894, CC BY 4.0. Sua resolução é a disponível na publicação; nenhuma melhoria artificial foi aplicada. A fonte define a classe elementar, não um risco real. Proveniência completa em `design/reference_library/manifest.json`.

Para reproduzir a partir de `mobile/`:

```sh
flutter test --no-pub --update-goldens tool/capture_ui_test.dart
```

O script carrega as fontes e aguarda a decodificação das imagens antes de capturar. As imagens são produzidas por `matchesGoldenFile`, sem edição posterior.
