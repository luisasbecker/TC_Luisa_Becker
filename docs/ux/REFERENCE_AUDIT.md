# Levantamento das referências e recursos

Atualizado em 29/10/2026. Os PDFs originais foram apenas lidos. A fonte local disponibilizada pela usuária é `../../../TC2_Luisa/Referências/`, relativa a esta pasta. O relatório `TCC_II__Luisa_Becker_v1.pdf` e o `Fluxograma_Pipeline_v7.png` estão na pasta acadêmica imediatamente acima de `Referências`. A paleta posteriormente localizada em Downloads também foi incorporada ao levantamento; ela não está mais pendente.

## Fonte principal da biblioteca

**Gomes et al. (2023). Use of Artificial Intelligence in the Classification of Elementary Oral Lesions from Clinical Images. International Journal of Environmental Research and Public Health, 20, 3894. DOI: 10.3390/ijerph20053894.**

A Figura 2, página 4 do PDF, contém rótulos explícitos, esquemas e nove fotografias. A associação abaixo vem desses rótulos e do texto da fonte; não foi inferida pela aparência das fotografias.

| Classe no aplicativo | Rótulo na Figura 2 | Fotografias |
| --- | --- | --- |
| Pápula/nódulo | Category 1 — Papule/Nodule | 2 |
| Mácula/mancha | Category 2 — Macule/Spot | 2 |
| Vesícula/bolha | Category 3 — Vesicle/Bullae | 2 |
| Erosão | Category 4 — Erosion | 1 |
| Úlcera | Category 5 — Ulcer | 1 |
| Placa | Category 6 — Plaque | 1 |

A figura nativa inteira mede 865 × 720 pixels; as fotografias individuais são pequenas, aproximadamente 100 × 80 pixels. Extração preserva os pixels disponíveis e não acrescenta detalhe. A visualização ampliada deve informar essa limitação. Objetos duplicados da mesma figura no PDF não são novos exemplos.

A primeira página do PDF declara CC BY 4.0. Registrar autores, título, ano, DOI, figura, página e painel; informar quando a foto tiver sido extraída/recortada da composição. Isso registra a declaração da fonte e a origem do recurso, sem substituir a autorização de uso informada pela usuária.

Não associar níveis de risco às fotografias: a fonte de classificação não fornece essa anotação para os exemplos. Risco continua sendo uma saída independente do módulo fantasma.

## Demais fontes disponíveis

| Arquivo/título | Evidência útil | Uso previsto e limite |
| --- | --- | --- |
| Use of Artificial Intelligence in the Classification of Elementary Oral Lesions from Clinical Images | Figura 3, p.4: qualidade, resolução, foco e iluminação; Figura 4, p.5: exemplos de recorte | Ajuda contextual e testes; não inferir classes não indicadas pelas legendas |
| SBCAS___A_method_for_focus_analysis_in_images_of_oral_lesions (1) | Figura 1, p.3: imagem nítida (a) e desfocada (b) | Comparação de qualidade; classe elementar não informada |
| Image Processing Methods for Oral Macules and Spots Segmentation | Figura 7(a), p.7: “macule 18”; Figura 8(a), p.8: “macule 3” | Exemplos adicionais de máculas/manchas; imagens processadas em tons de cinza e com contorno, não fotos originais sem edição |
| Critical analysis of the performance of the YOLO architecture in the detection of oral lesions from clinical images | Figura 1, p.5 e Figura 2, p.7 | Exemplos técnicos de delimitação/detecção, com caixas já desenhadas; não constituem rótulos de classe para galeria |
| Convolutional neural network misclassification analysis in oral lesions- an error evaluation criterion by image characteristics | Figuras 1–4, pp.4–7; Figura 4 descreve ambiguidade entre classes | Apoiar explicação de incerteza e limitações; não converter um caso ambíguo em classe confirmada |
| Use of Deep Neural Networks in the Detection and Automated Classification of Lesions Using Clinical Images in Ophthalmology, Dermatology, and Oral Medicine | Revisão, 11 páginas; Figura 1, p.4 | Fundamentação, sem fotografias clínicas aproveitáveis para a biblioteca |

As páginas indicadas são posições no PDF, começando em 1. Não confundir com numeração de páginas da revista.

## Avaliação de foco

O artigo de Mateus de Souza, Jean Schmith e colaboradores apresenta comparação explícita entre foto nítida e desfocada. As imagens nativas da Figura 1 medem 305 × 305 e 307 × 307 pixels, respectivamente. O ano editorial não foi identificado na abertura; a data de geração do PDF não será usada como data de publicação.

O método real não será implementado. A conclusão, p.11, deixa a definição de um ponto de corte para trabalho futuro. Portanto, não inventar limiar de aprovação nem apresentar um escore fictício como medida validada. Mostrar o recorte confirmado, permitir ampliação e solicitar a decisão visual do profissional, conforme o fluxo aprovado.

## Uso confirmado pela usuária

As fotografias disponibilizadas servem para a biblioteca local e podem ser escolhidas como entradas de testes do aplicativo, inclusive com envio ao Google Cloud. Consultar uma referência não implica envio. Não foi enviada nenhuma fotografia clínica durante este levantamento.

O manifesto da biblioteca em `design/reference_library/` separa exemplos de classe, exemplos de qualidade e a figura composta de contexto. Cada registro contém identidade, origem, legenda explícita, dimensões, transformações e hash. Nenhum diagnóstico ou anotação de risco foi acrescentado. A cópia incorporada em `mobile/assets/references/manifest.json` corresponde ao manifesto de origem; os hashes das onze fotografias incorporadas foram conferidos.

## Referências de interface

Em 28/10/2026, os quatro links Mobbin foram tentados por consulta e navegador. No navegador, todos levaram à página inicial com opção de login; nenhuma tela interna desses aplicativos foi visualizada.

| Referência indicada | Acesso efetivo | Interpretação permitida |
| --- | --- | --- |
| Withings Health Mate | Somente página inicial/login do Mobbin | Organização e clareza de saúde são intenções descritas pela usuária, não uma análise visual das telas |
| Stoic | Somente página inicial/login do Mobbin | Minimalismo, tipografia e espaços em branco são diretrizes do prompt |
| One Year | Somente página inicial/login do Mobbin | Ritmo e organização são referências desejadas, ainda sem telas inspecionadas |
| Insight Timer | Somente página inicial/login do Mobbin | Cartões e experiência guiada são diretrizes do prompt |

A captura específica do menu continua indisponível para inspeção. A usuária definiu um **menu inferior flutuante**; essa diretriz orienta uma composição própria, mas não permite afirmar que a captura ou um menu desses aplicativos foi reproduzido. Não atribuir medidas, comportamentos, animações ou detalhes observados a referências que não foram abertas.

## Paleta verificada

Os arquivos `grade_cores_pipeline_bucal.png` e `grade_cores_pipeline_bucal.svg` foram localizados em Downloads e copiados, sem alterar os originais, para `design/sources/`. O SVG contém trinta tons explicitamente rotulados: dez em cada escala, de 50 a 900. Os tokens usam esses valores, sem amostragem aproximada de pixels do PNG.

| Escala | Papel indicado na fonte | Exemplos conferidos |
| --- | --- | --- |
| Vinho-terroso | Primária, botões e ações | 50 `#FFF5F4`; 500 `#904A46`; 900 `#351A19` |
| Rosé | Acento, etapas e progresso | 50 `#FFF8F7`; 200 `#FFDAD7`; 900 `#5F2C2A` |
| Neutras | Superfícies e texto | 50 `#F8F9FB`; 600 `#665957`; 900 `#231919` |

O hash SHA-256 do SVG é `f15d324c8bf276b8a261c25309c9b913e0c360d24d0f7c0aae5423d453d9432c`, igual ao registrado em `design/tokens/primitives.json`. Foi conferida a presença dos trinta valores primitivos no SVG. Cores funcionais complementares e o fundo escuro são derivações identificadas nos tokens, não cores alegadamente extraídas da paleta. A cor seed vermelha usada no aplicativo anterior não é a referência cromática desta evolução.

Fontes e mapeamento visual estão documentados em [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Inter está disponível localmente como `mobile/assets/fonts/Inter-Variable.ttf`, acompanhada de `OFL-Inter.txt`, que declara SIL Open Font License 1.1. A presença do arquivo e o registro da família `Inter` em `mobile/pubspec.yaml` foram verificados. A renderização em cada plataforma pertence à verificação visual da interface.

## Figma e formato dos entregáveis

Foi criado o arquivo [Pipeline Bucal — Design System e UX · TCC](https://www.figma.com/design/hzwZXkdUf8RE0bY45KAWbx). Sua criação não equivale à criação dos componentes: o limite de uso da integração no plano Starter impediu as mutações seguintes. O arquivo permanece sem a biblioteca nativa e sem protótipo nativo verificado.

A alternativa de entrega trabalha com SVGs, tokens JSON e um protótipo HTML navegável, documentados em `design/figma/`. Esses recursos não devem ser apresentados como componentes nativos do Figma com variantes, Auto Layout ou conexões já implantadas. O estado efetivo e as instruções de importação devem acompanhar os arquivos em `design/figma/README.md`.

## Estado verificado e limites

- Seis artigos localizados e inspecionados; cobertura documental das seis classes confirmada.
- Biblioteca local preparada: nove fotografias categorizadas, dois exemplos de qualidade e figura de contexto. As onze fotografias passaram por verificação de dimensões, hashes, igualdade dos pixels extraídos e inspeção visual.
- Recursos copiados para o pacote Flutter, com manifesto idêntico e hashes correspondentes. A galeria lê arquivos locais; consultar/ampliar uma imagem não inicia uma chamada de cloud. A utilização em análise é uma ação separada, seguida da prévia e confirmação da imagem.
- Paleta PNG/SVG localizada e trinta tons conferidos; tokens primitivos/semânticos em `design/tokens/`.
- Inter e sua licença estão presentes; não é necessário depender de download de fonte durante o uso.
- As telas Mobbin e a captura específica do menu não foram inspecionadas. A preferência por menu inferior flutuante está confirmada, mas detalhes da captura não estão.
- Arquivo Figma criado; conteúdo nativo não concluído devido ao limite da integração. Recursos alternativos devem ser identificados pelo formato real.
- Nenhuma classificação clínica, risco real, treinamento ou validação com profissionais foi produzida por esta auditoria. Os documentos originais do TCC e os artigos permaneceram intactos.

## Revisão estática do uso das referências no Flutter

Na implementação inspecionada, `ReferenceLibrary` carrega o manifesto e as imagens por `rootBundle`; `ReferenceGallery` e `ReferenceBrowser` não chamam a API. Abrir um cartão apenas apresenta imagem, atribuição e resolução. A ação separada **Usar em uma análise** é encaminhada pelo shell para `selectImage`, que prepara a imagem e mantém o controlador na prévia. A prévia informa o envio à cloud e exige **Usar esta imagem**; somente `confirmImage` inicia a operação `detect` com os pixels.

O feedback de substituição de uma imagem já escolhida utiliza referências/metadados, com `includePixels: false`. Isso é distinto de enviar automaticamente uma fotografia consultada. A revisão acima é leitura do código, não uma alegação de teste manual em aparelho ou de execução de upload durante a auditoria.
