# Recorte fixo e comunicação cloud — 01/11/2026

## Alterações

- O recorte manual usa a altura disponível, fora da rolagem da página. A imagem preserva a proporção; confirmação e cancelamento permanecem visíveis.
- Gestos acumulam deslocamentos entre frames, evitando perda de movimento. Ampliação e edição usam o mesmo viewport para que os cantos visíveis recebam toques, inclusive fora do retângulo original da imagem.
- Ferramentas têm alvos de 48 pixels lógicos; ajuda e ajustes acessíveis abrem separadamente. Fontes grandes usam ações visuais curtas, com rótulos completos e ativação semântica preservados. O processamento bloqueia gestos e ações duplicadas.
- Nova análise normal inicia em cloud e limpa cenários fixos anteriores. Selecionar uma referência durante aquisição ou substituição preserva a identidade da análise e um modo offline explicitamente escolhido.
- As chamadas HTTPS existentes de detecção, foco, CNN, questionário e multimodal foram preservadas e verificadas. Os recibos agora exigem também o módulo esperado.
- A interface identifica processamento e retorno de cada etapa; o foco fictício recebido aparece como adequado/inadequado, sem substituir a avaliação visual do profissional.
- O histórico registra origem, operação, módulo validado e duração da comunicação. Imagens e dados identificáveis não são acrescentados ao histórico.

Não foram implementados modelos de IA, algoritmos clínicos ou retreinamento.
O backend e a configuração de faturamento não foram alterados.

## Verificação

| Verificação | Resultado |
| --- | --- |
| Suíte Flutter, incluindo contrato Python local | 116 testes passaram, sem testes ignorados |
| Análise estática Flutter | Sem problemas |
| Suíte Python da cloud | 21 testes passaram |
| Renderização adicional | 1 teste passou; cinco capturas |
| Smoke HTTPS do serviço publicado | Passou nas cinco etapas, três riscos, três decisões, recorte manual, feedback e retry |
| Compilação Android debug | `assembleDebug` concluído; assinatura v2, alinhamento 16 KB e manifesto verificados |
| Integridade do diff | Sem erros de whitespace |

Os testes abrangem arraste vertical sem rolagem, movimentos sem frame intermediário,
coordenadas após zoom, cantos fora da área original, ativação por leitor de tela,
fontes até 250%, temas claro/escuro, redução de movimento, telas pequenas e tablet.
Também cobrem modo cloud após uma demonstração, ausência de fallback silencioso,
falhas e novas tentativas em cada etapa, recibos divergentes e pixels corrigidos.

As imagens de [evidência visual](../screenshots/flutter/README.md) são renderizações
de widgets com respostas controladas. Não equivalem a teste manual em Android ou
iPhone. O smoke remoto usa somente pixels sintéticos; veja
[comunicação por etapa](CLOUD_STAGE_COMMUNICATION.md).

## Reproduzir

Em `mobile/`, com Flutter instalado:

```sh
flutter analyze --no-pub
PIPELINE_PYTHON=python3 PYTHONPATH=../cloud flutter test --no-pub
flutter test --no-pub --update-goldens tool/capture_crop_cloud_test.dart
```

O Python selecionado precisa ter Pillow instalado. A suíte Python pode ser
executada na raiz com `PYTHONPATH=cloud python3 -m unittest discover -s cloud/tests -v`.
O smoke remoto é opt-in: `PYTHONPATH=cloud python3 cloud/smoke_v2.py URL_HTTPS`.

Esta alteração não atualiza automaticamente o APK já compartilhado no OneDrive
nem os aplicativos instalados nos aparelhos; não houve publicação em loja.

O APK de verificação local está em `mobile/build/app/outputs/flutter-apk/app-debug.apk`,
mantendo a versão de desenvolvimento 0.3.0+4. Possui 178.601.072 bytes e SHA-256
`37e5727923e6ad79c530d97cce2c6745b0e19569d66b62e4835583780229ec5e`.
O build utilizou os caches offline, sem criar chave de assinatura. Os metadados
locais foram restaurados após a compilação. O [relatório Android](logs/android-crop-cloud-build-20261101.json)
registra mínimo Android 24, alvo 36 e ABIs ARM64, ARM32 e x86_64.
Não foi feito novo build nativo iOS nesta revisão; o código compartilhado e os
testes de widgets em variante iOS passaram, sem comprovar instalação no iPhone.
