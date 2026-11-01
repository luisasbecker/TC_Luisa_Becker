# Design, mockups e protótipo visual

Esta entrega contém **72 mockups SVG editáveis** (36 estados em dois temas), seis pranchas de fundamentos/componentes/fluxo e um protótipo HTML navegável com 15 cenários fixos. As cores são derivadas dos tokens do projeto, extraídos da paleta SVG real em `design/sources/`. O ícone da aplicação aparece na tela inicial e nas informações sobre o sistema.

## Estado do Figma

Arquivo criado em 29/10/2026: [Pipeline Bucal — Design System e UX · TCC](https://www.figma.com/design/hzwZXkdUf8RE0bY45KAWbx).

O arquivo foi criado, mas **permanece sem a biblioteca, mockups ou conexões nativas**. A integração respondeu, antes da primeira gravação de conteúdo: “You've reached the Figma MCP tool call limit on the Starter plan.” Não foi contratado upgrade, alterado plano ou contornado o limite.

Foi aplicado o fallback expressamente previsto no escopo: SVG, tokens JSON, recursos visuais e instruções de importação. **SVGs editáveis não equivalem a componentes Figma com variantes, Auto Layout, variáveis ou Code Connect.** As interações entregues funcionam no HTML; não são conexões de protótipo dentro do arquivo Figma.

## Abrir e navegar

Abra `prototype.html` em um navegador. Para carregar a fonte local com consistência, execute, na raiz do repositório:

```sh
python3 -m http.server 8768 --bind 127.0.0.1
```

Acesse `http://127.0.0.1:8768/design/figma/prototype.html`. O servidor só escuta o computador local.

Selecione um dos 15 cenários no painel externo ao celular. Use as ações dentro da tela, alterne claro/escuro, volte às etapas, visite a biblioteca ou revise decisões. O menu flutuante mantém a análise disponível ao trocar de aba. “Ver todos os mockups” mostra os 72 estados. O histórico permite exportar JSON dos eventos desta demonstração visual.

O protótipo não captura fotos, envia imagens, executa cloud ou processa pixels. O editor representa o movimento da região de interesse; o recorte efetivo pertence à implementação Flutter. As perguntas são exemplos de composição, e não critérios clínicos. As saídas fixas deste material **não substituem a seleção aleatória por análise do aplicativo**.

## Estrutura da entrega

| Material | Localização | Conteúdo |
|---|---|---|
| Tokens compartilhados | `../tokens/` | Primitivos, semânticos e valores resolvidos dos dois temas |
| Mockups claros | `svg/light/01-home.svg` a `36-abandon.svg` | Textos e geometria editáveis, fotografias incorporadas |
| Mockups escuros | `svg/dark/01-home.svg` a `36-abandon.svg` | Estados equivalentes, com semântica própria de tema |
| Fundamentos | `svg/{light,dark}/00-foundations.svg` | Paleta, tipografia, espaçamento e princípios |
| Componentes | `svg/{light,dark}/00-components.svg` | Botões, entrada, seleção, avisos, navegação e risco |
| Mapa do fluxo | `svg/{light,dark}/00-user-flows.svg` | Correções, retornos e incerteza sem interrupção |
| Protótipo | `prototype.html` | Navegação, cenários, revisão, seleção e exportação de eventos |
| Fontes de construção | `build_mockups.py`, `prototype.template.html` | Geração reproduzível, sem dependências Python adicionais |
| Inventário | `inventory.json` | IDs, temas, caminhos, áreas de toque e destinos de cada ação |
| Evidências | `previews/` | PNGs renderizados dos SVGs, não capturas do Flutter |
| Verificação | `validation.json`, `verify_mockups.py` | Integridade dos arquivos, fontes das imagens e navegação |

`previews/light-01-home.png`, `previews/dark-13-classification.png`, `previews/light-25-unconfirmed.png` e `previews/dark-23-medium.png` são exemplos para uma revisão rápida.

## Importação manual no Figma

O pacote para download está em `../exports/Pipeline_Bucal_Mockups_Figma.zip`,
com guia `../exports/LEIA-ME_IMPORTACAO_FIGMA.md`. Inclui as 72 telas e seis
pranchas, fonte Inter, tokens, fotografias com atribuições, prévias, protótipo
HTML independente e catálogo CSV dos textos. As pontas das setas dos fluxos
foram convertidas de marcadores SVG em caminhos vetoriais explícitos para
compatibilidade de importação. O ZIP não contém um arquivo `.fig` e não implica
que o conteúdo tenha sido gravado na conta Figma. Textos podem virar contornos
no importador; a edição como camada de texto Figma não é garantida.

Para reproduzir e verificar o pacote: `python3 design/figma/package_import.py`.

1. Abra o arquivo dedicado acima.
2. Crie as páginas **Foundations**, **Components**, **Light Theme**, **Dark Theme**, **User Flows**, **Interactive Prototype** e **Documentation**.
3. Arraste os SVGs das respectivas pastas para as páginas. As imagens clínicas e o ícone são bitmaps incorporados; textos, caixas, ícones de interface, linhas e botões permanecem elementos vetoriais no arquivo de origem.
4. Confirme a fonte Inter. A família está incluída no aplicativo em `mobile/assets/fonts/Inter-Variable.ttf`, com sua licença OFL.
5. Confira a estrutura importada: a preservação de texto como texto depende do importador e da disponibilidade da fonte. Se o Figma converter algum texto em contornos, edite-o no SVG-fonte ou recrie o texto no Figma. Não há promessa de propriedades nativas após importação.
6. Para uma biblioteca Figma nativa futura, transforme as famílias em componentes, configure variantes e Auto Layout, recrie as variáveis a partir dos JSON e conecte os fluxos do `inventory.json`. Essa etapa permanece pendente por limitação da integração.
7. Use a página **Interactive Prototype** como referência para o HTML ou para reconstruir manualmente as conexões; importar SVG não importa a lógica JavaScript.

Os mocks podem ser editados no SVG ou regenerados a partir dos tokens. Não edite `prototype.html` diretamente: altere `prototype.template.html` e rode o construtor.

## Telas e cenários

Os estados 01–28 atendem à relação mínima solicitada, incluindo aquisição, processamento, recorte manual, falha de detecção, qualidade insuficiente, concordância, discordância, incerteza, questionário, revisão, três riscos, resultado não confirmado, conclusão, informação e recuperação de erro. Os estados 29–36 acrescentam biblioteca, histórico, segunda seção do questionário, análise vazia, cloud indisponível, revisão de decisões, ampliação e abandono.

Os 15 cenários do seletor correspondem aos caminhos de demonstração descritos no escopo. As ações de rejeição de recorte oferecem novo recorte ou nova imagem; nova imagem retorna à aquisição; o recorte manual segue à qualidade; “Não consigo determinar” segue ao questionário e mantém a advertência no resultado. A seleção alternativa preserva a sugestão original nos eventos.

## Fontes visuais e imagens

A paleta PNG e SVG foi efetivamente lida. As quatro referências Mobbin foram tentadas, mas as telas dos aplicativos não ficaram acessíveis. A captura específica do menu também não foi visualizada; o menu flutuante foi desenvolvido a partir da preferência escrita da usuária, sem afirmar reprodução da imagem anexada.

As fotos de classe são da Figura 2 de Gomes et al. (2023), DOI `10.3390/ijerph20053894`, CC BY 4.0. As classes seguem os rótulos explícitos da fonte. O exemplo de foco inadequado vem da Figura 1(b) do artigo fornecido de Souza et al. Os pixels dos PNGs incorporados são os mesmos da biblioteca local; não houve retoque, criação de paciente ou inferência de risco a partir da foto. Consulte `../reference_library/manifest.json` para origem, dimensões, atribuição e limitações de resolução.

## Verificação e reprodução

```sh
python3 design/figma/build_mockups.py
python3 design/figma/verify_mockups.py
```

A verificação cobre 72 telas, seis pranchas, 15 cenários, preservação dos arquivos de imagem incorporados, 506 ações e correspondência de destinos entre os temas. Todas as telas de risco são categóricas, contêm orientação médica, identificação demonstrativa e aviso de ausência de diagnóstico. O resultado após incerteza mantém a classe não confirmada.

`render_previews.py` utiliza as bibliotecas librsvg/Cairo da instalação local do Inkscape para produzir evidências PNG. Não instala dependências nem modifica as fontes. Foram inspecionados visualmente os fundamentos, componentes e exemplos de início, recorte, classificação, incerteza, questionário, biblioteca e resultado nos temas claro/escuro. O caminho de incerteza, edição de resposta, revisão e resultado foi percorrido no Safari.

Essas verificações são técnicas e visuais. **Não constituem avaliação de usabilidade com profissionais da saúde**, que permanece prevista no protocolo em `docs/ux/validation/PROTOCOL.md`.
