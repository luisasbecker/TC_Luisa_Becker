# Capítulo 4 — Implementação do pipeline

Rascunho preparado em 02/11/2026, a partir do PDF `TCC_II__Luisa_Becker_v1.pdf` disponibilizado no computador e do aplicativo no commit `765c732`. O PDF de referência termina no capítulo 3. Nenhum documento original ou arquivo do projeto Overleaf foi modificado. A versão atual aberta no Overleaf não pôde ser consultada nesta sessão.

## Conteúdo

- `capitulo-implementacao.tex`: capítulo editável em LaTeX, sem classe nem preâmbulo próprios, para integração ao TCC.
- `capitulo-implementacao.md`: manuscrito fonte, com marcadores de grupos de figuras.
- `capitulo-implementacao.pdf`: prévia de leitura, gerada com ReportLab. Não é compilação LaTeX e não comprova a diagramação do modelo institucional.
- `capitulo-implementacao.html`: leitura no navegador, com imagens ampliáveis. Mantenha a pasta `figuras` ao lado.
- `figuras/`: 47 capturas PNG em resolução integral e manifesto de procedência.
- `previsualizacao.tex`: documento independente para experimentar o capítulo, caso ainda não seja inserido no modelo institucional.
- `verificacao.json`: verificações executadas e limitações da entrega.
- `gerar_documentos.py`: geração reproduzível de LaTeX, HTML e PDF a partir do manuscrito e das capturas.

## Inserir no Overleaf existente

1. Extraia o ZIP. Envie a pasta `capitulo-implementacao` e seu conteúdo para a raiz do projeto existente. Não substitua o arquivo principal, a classe institucional, a bibliografia ou os capítulos já escritos.
2. Confirme que o preâmbulo principal carrega `graphicx` e `longtable`. Se os pacotes já estiverem carregados, não os duplique. `placeins` com opção `section` é opcional para manter as figuras próximas às respectivas seções.
3. Depois do capítulo Metodologia e antes das referências, acrescente:

```tex
\input{capitulo-implementacao/capitulo-implementacao}
```

4. Compile o documento principal e revise a posição das figuras, legendas, fontes e o quadro de correspondência conforme o modelo institucional. A numeração de capítulos e figuras vem do documento principal; não copie os ajustes de contadores de `previsualizacao.tex` para o TCC.
5. O caminho padrão das figuras é `capitulo-implementacao/figuras`. Se usar outro diretório, defina `\newcommand{\pipelinefigdir}{CAMINHO/figuras}` antes de incluir o capítulo.

O texto mantém menções autor-data a Gomes et al. (2023), já presentes no PDF-base, sem inventar chaves BibTeX. Na revisão dentro do projeto original, essas menções podem ser ligadas às chaves reais da bibliografia. O texto não cria uma nova lista de referências.

## Escopo e procedência das imagens

As capturas foram renderizadas com widgets e controlador reais do Flutter, mas com respostas locais determinísticas. Não são capturas de iPhone/Android físicos, não são imagens exportadas do Figma e não comprovam chamadas HTTPS. As telas exibem o modo offline. Os textos dos questionários desse modo não são necessariamente idênticos aos do serviço remoto.

Todas as páginas e principais estados visuais estão representados. Seis imagens adicionais mostram trechos inferiores de páginas com rolagem, e três mostram o tema escuro. As imagens não incluem diálogos nativos do sistema operacional para câmera, seletor de arquivos ou compartilhamento. O manifesto informa o estado de cada captura e o relógio fixo utilizado no histórico.

As fotografias clínicas exibidas nas capturas pertencem à biblioteca autorizada do projeto. A atribuição, a figura de origem e o mapeamento explícito das classes constam em `mobile/assets/references/manifest.json`. Nas capturas deste capítulo foram usados exemplos de Gomes et al. (2023); não foram criados casos clínicos sintéticos nem inferidos riscos reais.

O fluxograma original ainda contém quatro tipos, saída binária e a raia “Especialista”. O capítulo explica a correspondência com as decisões atuais de seis classes, três riscos e sistema inteligente computacional, preservando o arquivo original.

## Verificações

Foram aprovados 115 testes Flutter na suíte geral e o teste de contrato Python em uma execução complementar, totalizando os 116 casos da suíte sem pendências. A compilação `flutter build bundle --debug --no-pub` também terminou com sucesso. Não foi executada nova compilação nativa Android/iOS para esta entrega.

O teste de geração das 47 capturas passou, e uma segunda execução de comparação também passou. O arquivo LaTeX foi verificado estruturalmente; não há compilador TeX disponível neste ambiente, portanto a compilação no modelo institucional continua pendente. A prévia PDF utiliza diagramação independente.

## Reproduzir

Na pasta `mobile`, com as dependências existentes do projeto:

```sh
flutter test --no-pub tool/capture_chapter_test.dart --update-goldens
flutter test --no-pub tool/capture_chapter_test.dart
```

Para regenerar os documentos, em um ambiente Python com `reportlab` e `Pillow`:

```sh
python3 docs/tcc/capitulo-implementacao/gerar_documentos.py
```

Edite o manuscrito Markdown antes de regenerar; o script sobrescreve somente seus arquivos derivados LaTeX, HTML e PDF. Alterações feitas diretamente no LaTeX importado para o Overleaf não retornam automaticamente ao Markdown.
