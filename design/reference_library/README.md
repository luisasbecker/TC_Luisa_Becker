# Biblioteca local de referências

Recursos extraídos dos PDFs fornecidos pela autora para uso acadêmico como referências visuais e entradas de teste, inclusive no fluxo cloud autorizado. Esta pasta não contém modelos, treinamento ou resultados clínicos calculados. O script não envia arquivos à internet.

## Conteúdo

- `manifest.json`: inventário, classes documentadas, fontes, páginas/figuras/painéis, atribuição, licença tal como declarada, dimensões, recortes e hashes SHA-256.
- `photos/`: nove fotografias clínicas categorizadas a partir da Figura 2 de Gomes et al. (2023), página PDF 4.
- `quality/`: dois exemplos de qualidade da Figura 1 de Souza et al., página PDF 3, sem atribuição de classe elementar.
- `context/gomes_2023_figure_2_original.jpg`: figura original completa extraída como JPEG sem recompressão, para conferir rótulos e localização. Contém desenhos esquemáticos e fotos; não é uma fotografia clínica única.
- `extract_references.py`: extração reproduzível e verificação de integridade/pixels. Não depende de bibliotecas Python adicionais; requer Poppler `pdfimages`.

| Índice local | Categoria explícita da fonte | Classe no aplicativo | Fotos |
| --- | --- | --- | ---: |
| 0 | Category 1 — Papule/Nodule | Pápula/nódulo | 2 |
| 1 | Category 2 — Macule/Spot | Mácula/mancha | 2 |
| 2 | Category 3 — Vesicle/Bullae | Vesícula/bolha | 2 |
| 3 | Category 4 — Erosion | Erosão | 1 |
| 4 | Category 5 — Ulcer | Úlcera | 1 |
| 5 | Category 6 — Plaque | Placa | 1 |

Os sufixos locais `a` e `b` distinguem as fotos à esquerda e à direita da mesma categoria. Não são letras impressas sobre as fotos originais. A associação entre foto e classe vem do rótulo explícito do grupo na figura, não de inferência pela aparência. Nenhuma fonte utilizada fornece risco baixo/médio/alto para essas fotos; o protótipo deve manter esse resultado simulado separado.

Os exemplos `sharp` e `blurred` de Souza et al. são identificados somente como **nítido** e **desfocado**, conforme a legenda da Figura 1. São elegíveis para orientação/testes de qualidade, mas não para a galeria de uma classe. A classe não foi inferida. O artigo deixa a definição de um ponto de corte do indicador de foco para trabalho futuro; os recursos não estabelecem limiar automático.

## Qualidade e apresentação

As nove fotos categorizadas são pequenas: cerca de 100 × 80 pixels na figura nativa de 865 × 720 pixels. Os arquivos preservam a região original, proporções e pixels decodificados, sem redimensionar, retocar, aumentar nitidez ou gerar detalhes com IA. Uma margem estreita da figura foi mantida quando necessária para não cortar bordas da fotografia. O recorte é documental, não segmentação da lesão.

O zoom deve informar que a resolução da fonte é limitada. Ampliar a visualização não recupera detalhe clínico. Desenhos da figura de contexto são **ilustrações esquemáticas**, não fotos de casos reais; somente as fotografias foram recortadas para `photos/`.

Essas fotos são referências publicadas e entradas demonstrativas. O aplicativo não deve afirmar que comparações, escolhas de cenário ou resultados fantasmas representam diagnóstico, validação clínica ou risco documentado dessas pessoas.

## Fontes e atribuição

**Gomes et al. (2023).** *Use of Artificial Intelligence in the Classification of Elementary Oral Lesions from Clinical Images*. International Journal of Environmental Research and Public Health, 20, 3894. DOI: `10.3390/ijerph20053894`. Figura 2, página PDF 4. O PDF declara CC BY 4.0 na página 1. Exibir crédito ao abrir a referência; indicar que a fotografia foi recortada da figura. Os metadados reproduzem a licença declarada no documento.

**Souza et al.** *A method for focus analysis in images of oral lesions*. Figura 1(a)/(b), página PDF 3 do arquivo fornecido. Ano de publicação e DOI não foram identificados no próprio PDF; a data de criação do arquivo não é usada como ano editorial. Não foi localizada declaração explícita de licença nesse arquivo. A utilização acadêmica baseia-se na permissão informada pela autora. Essa descrição de proveniência não é orientação jurídica.

Os originais permanecem na pasta `TC2_Luisa/Referências`, fora desta biblioteca. Nenhum PDF integral foi copiado. Os hashes dos PDFs e dos recursos estão no manifesto.

## Reproduzir e verificar

Executar a partir da raiz do repositório, com Python 3.10+ e Poppler disponíveis:

```sh
python3 design/reference_library/extract_references.py \
  --source-dir '../TC2_Luisa/Referências'

python3 design/reference_library/extract_references.py \
  --source-dir '../TC2_Luisa/Referências' \
  --verify \
  --contact-sheet /tmp/tcc-reference-contact-sheet.png
```

O script recusa sobrescrever arquivos existentes com conteúdo diferente. A opção `--verify` exige todos os recursos já existentes e não os regrava. Ela compara conteúdo e hashes reproduzidos, valida dimensões/limites de cada recorte e decodifica os PNGs para conferir todos os pixels RGB contra o recorte nativo correspondente. Alterações dos PDFs que mudem pixels, tamanho, mapeamento ou hash exigem revisão humana da extração.

O contact sheet temporário mostra as fotos no tamanho nativo, com rótulos locais `C0-A` a `C5-A`, mais `Q-A` (nítido) e `Q-B` (desfocado). Ele serve para revisão, não é um recurso do aplicativo. A biblioteca foi preparada sem integração automática com Flutter e sem upload, implantação ou commit.
