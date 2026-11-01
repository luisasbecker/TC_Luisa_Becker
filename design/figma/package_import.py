"""Package existing vector mockups for manual Figma import, without network access."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design/figma"
OUTPUT = ROOT / "design/exports"
NAME = "Pipeline_Bucal_Mockups_Figma"
SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")

GUIDE = """# Pipeline Bucal — mockups para importação no Figma

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
"""


def path_end(path: str) -> tuple[float, float, float, float]:
    """The existing flow board uses absolute orthogonal M/H/V segments only."""
    commands = re.findall(r"([MHV])([\d. -]+)", path)
    if "".join(cmd + values for cmd, values in commands) != path:
        raise ValueError(f"Unsupported arrow path: {path}")
    x = y = previous_x = previous_y = 0.0
    for cmd, values in commands:
        numbers = [float(value) for value in values.split()]
        previous_x, previous_y = x, y
        if cmd == "M":
            x, y = numbers
        elif cmd == "H":
            x = numbers[0]
        else:
            y = numbers[0]
    return x, y, previous_x, previous_y


def compatible_svg(data: bytes) -> tuple[bytes, int]:
    """Replace unsupported flow arrow markers; never outline text or rasterize."""
    root = ET.fromstring(data)
    arrows = 0
    for parent in list(root.iter()):
        for element in list(parent):
            if element.tag == f"{{{SVG}}}marker":
                parent.remove(element)
            if element.attrib.pop("marker-end", None) is not None:
                x, y, px, py = path_end(element.attrib["d"])
                length = math.hypot(x - px, y - py)
                ux, uy = (x - px) / length, (y - py) / length
                # Original marker units are strokeWidth=1.8: refX6, refY3.5.
                points = [(x + 1.8 * ux, y + 1.8 * uy),
                          (x - 10.8 * ux - 6.3 * uy, y - 10.8 * uy + 6.3 * ux),
                          (x - 10.8 * ux + 6.3 * uy, y - 10.8 * uy - 6.3 * ux)]
                d = "M" + "L".join(f"{a:g} {b:g}" for a, b in points) + "Z"
                arrow = ET.Element(f"{{{SVG}}}path", {
                    "d": d, "fill": element.attrib["stroke"],
                    "id": f"flow-arrow-{arrows + 1}",
                })
                parent.insert(list(parent).index(element) + 1, arrow)
                arrows += 1
    # Keep unrelated SVG bytes exactly as delivered previously.
    return (ET.tostring(root, encoding="utf-8") if arrows else data), arrows


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    files: dict[str, bytes] = {"LEIA-ME.md": GUIDE.encode("utf-8")}
    rows = []
    arrow_count = image_count = 0
    source_files = sorted((SOURCE / "svg").rglob("*.svg"))
    assert len(source_files) == 78
    for path in source_files:
        theme = path.parent.name
        category = "pranchas" if path.name.startswith("00-") else "mockups"
        folder = "tema-claro" if theme == "light" else "tema-escuro"
        relative = f"{category}/{folder}/{theme}-{path.name}"
        original = path.read_bytes()
        data, converted = compatible_svg(original)
        arrow_count += converted
        before, after = ET.fromstring(original), ET.fromstring(data)
        assert (before.attrib["width"], before.attrib["height"]) == (
            after.attrib["width"], after.attrib["height"])
        original_images = [n.attrib for n in before.iter(f"{{{SVG}}}image")]
        final_images = [n.attrib for n in after.iter(f"{{{SVG}}}image")]
        assert original_images == final_images
        image_count += len(final_images)
        texts_before = [(n.text, n.attrib) for n in before.iter(f"{{{SVG}}}text")]
        texts_after = [(n.text, n.attrib) for n in after.iter(f"{{{SVG}}}text")]
        assert texts_before == texts_after
        for number, (text, attributes) in enumerate(texts_after, start=1):
            rows.append([relative, number, text, attributes.get("x"),
                         attributes.get("y"), attributes.get("font-size"),
                         attributes.get("font-weight"), attributes.get("fill")])
        files[relative] = data

    text_file = io.StringIO(newline="")
    writer = csv.writer(text_file)
    writer.writerow(["arquivo", "ordem", "texto", "x", "baseline_y",
                     "tamanho_px", "peso", "cor"])
    writer.writerows(rows)
    files["textos_das_telas.csv"] = text_file.getvalue().encode("utf-8-sig")

    for path in sorted((ROOT / "design/tokens").glob("*.json")):
        files[f"tokens/{path.name}"] = path.read_bytes()
    for path in sorted((ROOT / "mobile/assets/fonts").iterdir()):
        if path.is_file():
            files[f"fontes/{path.name}"] = path.read_bytes()
    for path in sorted((ROOT / "design/sources").iterdir()):
        if path.suffix in {".png", ".svg"}:
            files[f"paleta/{path.name}"] = path.read_bytes()
    for path in sorted((ROOT / "design/reference_library").rglob("*")):
        if path.is_file() and path.suffix in {".json", ".md", ".png", ".jpg"}:
            relative = path.relative_to(ROOT / "design/reference_library")
            files[f"referencias/{relative.as_posix()}"] = path.read_bytes()
    for path in sorted((SOURCE / "previews").glob("*.png")):
        files[f"previas/{path.name}"] = path.read_bytes()
    files["navegacao.json"] = (SOURCE / "inventory.json").read_bytes()
    html = (SOURCE / "prototype.html").read_text()
    font_path = "../../mobile/assets/fonts/Inter-Variable.ttf"
    assert html.count(font_path) == 1
    files["prototipo.html"] = html.replace(font_path, "fontes/Inter-Variable.ttf").encode()
    summary = {
        "screens": 72, "support_boards": 6, "themes": ["light", "dark"],
        "source_text_elements": len(rows), "embedded_images_preserved": image_count,
        "explicit_arrowheads": arrow_count, "native_figma_file": False,
        "figma_import_executed": False, "figma_text_editability_guaranteed": False,
        "text_preserved_in_svg": True, "checks": "passed",
    }
    assert len(rows) == 1316 and image_count == 46 and arrow_count == 36
    files["verificacao.json"] = json.dumps(summary, ensure_ascii=False, indent=2).encode()
    checksums = "\n".join(f"{hashlib.sha256(data).hexdigest()}  {path}"
                          for path, data in sorted(files.items())) + "\n"
    files["SHA256SUMS.txt"] = checksums.encode()
    archive = OUTPUT / f"{NAME}.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=9) as out:
        for path, data in sorted(files.items()):
            out.writestr(f"{NAME}/{path}", data)
    with ZipFile(archive) as check:
        assert check.testzip() is None
        assert len(check.namelist()) == len(files)
        for path, data in files.items():
            assert check.read(f"{NAME}/{path}") == data
    (OUTPUT / "LEIA-ME_IMPORTACAO_FIGMA.md").write_text(GUIDE)
    print(json.dumps({"archive": str(archive), "bytes": archive.stat().st_size,
                      "files": len(files), **summary}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
