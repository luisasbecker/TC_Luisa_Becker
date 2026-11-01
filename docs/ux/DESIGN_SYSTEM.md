# Pipeline Bucal — sistema visual

## Identidade e origem

A identidade usa vinho terroso, rosé e neutros quentes para uma experiência calma, legível e profissional. As 30 cores das três escalas foram extraídas dos rótulos e valores do SVG fornecido pela autora, sem amostragem aproximada da imagem PNG. Cópias dos arquivos estão em `design/sources/`; os originais permanecem intactos.

`design/tokens/primitives.json` registra o SHA-256 do SVG. Branco, fundo escuro e cores funcionais de informação, aviso, erro e resultado são complementos documentados, não cores alegadamente extraídas da paleta. As categorias de risco usam ícone e texto além da cor; não indicam diagnóstico.

## Tokens e geração

| Arquivo | Finalidade |
| --- | --- |
| `design/tokens/primitives.json` | Escalas originais, complementos semânticos, tipografia, dimensões e movimento |
| `design/tokens/semantic.json` | Referências aos primitivos, modos claro/escuro e estados |
| `design/tokens/resolved.json` | Valores de cor resolvidos para consumir no Figma ou outras ferramentas |
| `design/tokens/contrast_report.json` | Pares de contraste medidos e limites de aceitação |
| `mobile/lib/design_system/tokens.g.dart` | Constantes Flutter geradas; não editar manualmente |
| `mobile/lib/design_system/theme.dart` | `ThemeData`, extensão semântica e política de movimento |
| `mobile/lib/design_system/components.dart` | Componentes de apresentação sem regras do pipeline |

Geração reproduzível, sem dependências externas de Python:

```sh
python3 design/tokens/generate_tokens.py
python3 design/tokens/generate_tokens.py --check
```

O comando extrai a paleta XML, resolve referências, calcula contraste e gera todos os artefatos. Se uma cor original precisar ser revista, a fonte deve ser revisada de maneira explícita. Ajustes de mapeamento, escala tipográfica e cores complementares são feitos no gerador. `--check` verifica se os arquivos estão sincronizados; não aplique formatadores diretamente em `tokens.g.dart`.

## Temas

| Papel | Claro | Escuro |
| --- | --- | --- |
| Fundo | `#FFF8F7` | `#181313` |
| Superfície | `#FFFFFF` | `#231919` |
| Superfície elevada | `#FFFFFF` | `#342B29` |
| Texto principal | `#231919` | `#F8F9FB` |
| Texto secundário | `#665957` | `#CFC7C7` |
| Ação principal | `#904A46` | `#FFDAD7` |
| Texto da ação | `#FFFFFF` | `#351A19` |
| Menu flutuante | `#231919` | `#231919` |
| Item de menu selecionado | `#FFDAD7` | `#FFDAD7` |

O tema escuro usa camadas quentes próprias, com superfícies elevadas mais claras e ações em rosé. Contornos de campos interativos têm contraste maior que divisores decorativos. Não usar divisores decorativos para representar sozinhos um limite obrigatório de controle.

```dart
import 'package:pipeline_bucal/design_system/design_system.dart';

MaterialApp(
  theme: BucalTheme.light(),
  darkTheme: BucalTheme.dark(),
  themeMode: ThemeMode.system,
);

final colors = BucalColors.of(context);
```

`BucalColors` é uma `ThemeExtension`; o aplicativo não precisa importar cores brutas para compor novas telas. Os controles Material de texto, botões, cartões, chips, diálogos, bottom sheets e progresso recebem os temas correspondentes.

## Tipografia e ritmo

Inter está incluída localmente em `mobile/assets/fonts/Inter-Variable.ttf`, proveniente do repositório oficial Google Fonts (`https://github.com/google/fonts/tree/main/ofl/inter`). A licença SIL Open Font License está em `OFL-Inter.txt`. Não há download de fontes durante uso do aplicativo. A família deve ser registrada no `pubspec.yaml` como `Inter`; o arquivo variável inclui pesos de 100 a 900. O fallback nativo continua disponível quando necessário.

| Uso | Tamanho / entrelinha | Peso |
| --- | --- | --- |
| Destaque | 32 / 40 | 600 |
| Título de página | 28 / 36 | 600 |
| Título de seção | 22 / 30 | 600 |
| Subtítulo | 18 / 26 | 600 |
| Corpo | 16 / 25 | 400 |
| Corpo auxiliar | 14 / 22 | 400 |
| Legenda | 12 / 18 | 500 |
| Botão | 15 / 22 | 600 |
| Marcador curto | 11 / 16 | 600 |

O marcador curto não substitui instruções importantes. O conteúdo usa largura máxima de 640 px, margens usuais de 24 px e escala de espaçamento 4, 8, 12, 16, 24, 32, 40, 48 e 64 px. Cartões têm raio 24 px, botões 16 px e campos 12 px. Alturas são mínimas, permitindo crescimento com o texto. Botões têm mínimo 52 px de altura; alvos de interação não devem ter menos de 48 px.

## Componentes e variantes

Importação pública: `mobile/lib/design_system/design_system.dart`.

| Componente | API principal / comportamento |
| --- | --- |
| `BucalButton` | `label`, `onPressed`, `icon`, `loading`, `expand`, `kind`; variantes primary, secondary, tertiary e destructive; desabilitado quando sem callback ou carregando |
| `BucalCard` | `child`, `padding`, `onTap`, `selected`; superfície, borda e indicação explícita de seleção |
| `BucalNotice` | `message`, `title`, `tone`, `announce`, `action`; tons info, success, warning e error com ícones |
| `BucalStageHeader` | `title`, `subtitle`, `step`, `total`, `trailing`; título, contagem textual e progresso |
| `BucalRiskCard` | `risk: BucalRisk.low/medium/high`, `provisional`; resultado categórico, simulação, orientação médica e aviso de incerteza |
| `BucalFloatingNav` | `items`, `selectedIndex`, `onSelected`, `hideWhenKeyboard`; cápsula flutuante, 2–4 destinos, rótulos sempre visíveis |
| `BucalNavItem` | `label`, `icon`; modelo exclusivamente visual |
| `BucalChoiceTile` | `title`, `subtitle`, `leading`, `selected`, `onTap`, `enabled`; escolha com ícone de seleção e conteúdo expansível |
| `BucalSectionField` | `label`, `helper`, `error`, `child`; agrupa uma pergunta e controles, com erro textual anunciado |
| `BucalEmptyState` | `title`, `message`, `icon`, `action`; ausência de conteúdo e ação de recuperação |
| `BucalLoading` | `label`; anúncio de processamento, respeitando redução de movimento |
| `BucalPage` | `child`, `padding`, `scrollable`; área segura, largura legível e rolagem |

Coloque `BucalFloatingNav` em `Scaffold.bottomNavigationBar`, permitindo que o layout reserve espaço para o menu. O componente não inicia nem abandona sessões; o controlador decide o que acontece ao trocar de destino. Ocultar o menu quando o teclado estiver aberto evita disputa de espaço com o questionário.

O estado do pipeline permanece fora desses componentes. Uma mudança de classe, por exemplo, deve invalidar respostas no controlador, e não dentro de um botão ou cartão. Editor de recorte, visualizador de imagem e galeria podem compor estas bases com seus contratos específicos na camada de funcionalidades.

## Acessibilidade e movimento

- Os pares de texto principais, ações, avisos e resultados dos dois temas foram verificados em `contrast_report.json` com razão mínima de 4,5:1. Foco e contornos interativos são verificados em 3:1. São 28 verificações; controles desabilitados não são usados para apresentar informações essenciais.
- Títulos têm semântica de cabeçalho; navegação expõe rótulo, ação e estado selecionado. Ícones decorativos são excluídos da leitura duplicada quando necessário.
- Textos e controles podem crescer com a escala do sistema; telas devem rolar em vez de cortar instruções ou ações. Não truncar rótulos essenciais com reticências.
- Os componentes não dependem de animação para comunicar processamento ou resultado. `BucalMotion.duration(context)` retorna zero quando o dispositivo solicita redução de movimento ou navegação acessível; indicadores de carregamento viram ícones estáticos.
- Erros incluem texto e ícone. Resultados exibem “Risco baixo”, “Risco médio” ou “Risco alto” e mensagem específica, sem porcentagem. Classe provisória aparece em aviso próprio.
- A camada de formulários deve fornecer `labelText`/rótulos semânticos para cada campo editável. O cabeçalho de `BucalSectionField` organiza a seção e não substitui o rótulo do controle.

## Verificação

```sh
cd mobile
flutter analyze lib/design_system
flutter test test/design_system_test.dart
```

O teste de widgets cobre temas separados, smartphone estreito com texto ampliado, navegação acessível, redução de movimento, botões sem submissão duplicada e as três categorias de risco com orientação médica. Essas verificações são automatizadas; não equivalem a testes com profissionais da saúde.

Resultado verificado em 29/10/2026, Flutter 3.41.7: análise estática dos arquivos do design system e seu teste sem ocorrências; 9 testes aprovados; 28 pares de contraste aprovados; arquivos de tokens sincronizados. A verificação de layout usa uma tela de 320 × 700 pixels lógicos e texto ampliado a 250% nos dois temas.

Este documento descreve os tokens e componentes Flutter entregues. Arquivos ou componentes Figma só devem ser declarados como produzidos quando existirem de fato e tiverem sido verificados na etapa correspondente.
