# Pipeline Bucal — mockups para importação no Figma

## O que você recebeu

- 72 telas SVG: 36 em tema claro e 36 em tema escuro.
- 6 pranchas SVG: fundamentos, componentes e fluxo, nos dois temas.
- Fonte Inter e licença de uso, paleta e tokens JSON.
- Fotografias incorporadas nos SVGs, com arquivos de origem e atribuições.
- Prévias PNG para consulta e protótipo HTML navegável com 15 cenários.
- `textos_das_telas.csv`: todos os textos, separados por tela, com posição,
  tamanho, peso e cor, para copiar caso seja necessário recriá-los no Figma.

## Importação dos mockups

1. Descompacte o ZIP no computador.
2. Instale `fontes/Inter-Variable.ttf`. No macOS, abra a fonte e selecione
   **Instalar**. Se o editor já estava aberto, reabra-o para reconhecer a fonte.
3. Abra um arquivo **Figma Design** com permissão de edição. Pode ser um arquivo
   novo nos seus rascunhos; não precisa usar o arquivo vazio da entrega anterior.
4. Abra a pasta `mockups/tema-claro/`. Arraste primeiro `light-01-home.svg`
   para dentro do canvas do arquivo aberto. Não importe o ZIP na lista de arquivos.
5. Confira as camadas e a aparência dessa tela. Depois, arraste os demais SVGs,
   em pequenos lotes. Repita com `mockups/tema-escuro/`.
6. Importe as pranchas de `pranchas/` para consultar fundamentos, componentes
   e fluxo. Organize as telas em áreas separadas do canvas ou nas páginas que
   seu arquivo permitir. Não é necessário contratar outro plano para esta entrega.
7. Selecione os elementos pelo painel de camadas para editar cores, dimensões
   e posições. Desagrupe somente quando precisar acessar um grupo interno.

## Limites da edição

**Estes são arquivos SVG vetoriais, não arquivos `.fig` nativos.** Não foram
exportados de uma biblioteca Figma pronta. O arquivo criado anteriormente no
Figma ficou vazio: a integração informou um limite de chamadas antes de inserir
o conteúdo. Isso não significa que os mockups estejam salvos na sua conta.

Os SVGs contêm textos reais no arquivo de origem e formas vetoriais separadas.
**O importador do Figma pode transformar os textos em contornos.** Instalar a
fonte ajuda na aparência, mas não garante que o texto será importado como camada
de texto. Se isso acontecer, crie uma camada com a ferramenta Texto e copie a
frase correspondente de `textos_das_telas.csv`. O SVG original também pode ser
editado em um editor vetorial que preserve textos.

Fotos clínicas e o ícone do app continuam imagens raster, como nos originais.
As pranchas de componentes são uma referência visual: não incluem componentes
Figma com variantes, Auto Layout, variáveis vinculadas ou biblioteca publicada.
Nenhum texto ou interface completa foi achatado em uma captura de tela.

As setas das duas pranchas de fluxo foram convertidas de `marker` SVG em caminhos
vetoriais explícitos para evitar a perda das pontas na importação. Os demais
conteúdos, as cores, os textos e as fotografias foram preservados.

## Consultar as interações

Abra `prototipo.html` no navegador. Ele inclui os 15 percursos de demonstração,
alternância de tema, revisão das respostas, incerteza e resultados de três níveis.
As interações pertencem ao HTML: importar SVG não cria conexões de protótipo no
Figma. Use `navegacao.json` como mapa para conectar as telas no painel Prototype.
Se a fonte local não carregar ao abrir o HTML diretamente, use Inter instalada
ou um servidor local; os SVGs continuam independentes do HTML.

## Conteúdo e origem

As 36 telas por tema incluem: início; nova análise; seleção de imagem; prévia;
processamento; detecção; recorte; editor; falha de detecção; reenvio; qualidade;
imagem inadequada; classificação; galeria; concordância; discordância;
seleção alternativa; incerteza; questionário; revisão; processamento multimodal;
risco baixo; médio; alto; resultado não confirmado; conclusão; informações;
erro; biblioteca; histórico; segunda seção; estado vazio; cloud indisponível;
revisão de decisões; ampliação e abandono.

Os resultados são demonstrativos, sem diagnóstico ou porcentagens. O HTML tem
saídas fixas para apresentação. O app mantém seu comportamento aleatório e as
chamadas de cloud; este pacote não altera o código nem a implantação.

`referencias/manifest.json` registra a atribuição das imagens científicas.
`paleta/` contém os arquivos da identidade fornecida. `tokens/` contém os valores
primitivos, semânticos e resolvidos usados na interface. `LEIA-ME.md` é este guia.

## Verificação desta entrega

Os 78 SVGs foram analisados como XML; as 46 imagens incorporadas foram preservadas
byte a byte; os textos e os tamanhos das telas foram preservados; o ZIP teve sua
integridade verificada. A importação desta cópia não foi executada na sua conta
Figma. `verificacao.json` registra as contagens e `SHA256SUMS.txt` os arquivos.

Documentação oficial de importação:
https://help.figma.com/hc/en-us/articles/360040027794-Guide-to-imports-in-Figma-Design
https://help.figma.com/hc/en-us/articles/360040030374-Copy-assets-between-design-tools
