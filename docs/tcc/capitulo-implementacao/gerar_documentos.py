"""Build editable LaTeX, HTML and a reading PDF from the chapter manuscript.

No access to Overleaf and no modification to original academic documents.
PDF is an independent reading layout, not a LaTeX compilation/template proof.
Run with Python + reportlab + Pillow. All inputs are local and versioned.
"""
from pathlib import Path
import html
import json
import re

ROOT = Path(__file__).resolve().parent
FIGURES = ROOT / 'figuras'

# Each number is the exact observed prefix of a real Flutter capture.
GROUPS = {
    'acquisition_preview': [
        ('inicio', 'Tela inicial e aquisição da imagem', ['01', '02']),
        ('preview', 'Pré-visualização da fotografia e confirmação da entrada', ['03', '03b']),
    ],
    'detection_crop': [
        ('deteccao', 'Processamento da detecção e conferência da região sugerida', ['04', '05']),
    ],
    'manual_failure': [
        ('recorte', 'Opções de correção e editor de recorte manual', ['05b', '06']),
        ('falha-deteccao', 'Ausência de região detectada e alternativas de recuperação', ['07', '07b']),
    ],
    'focus': [
        ('foco', 'Espera da avaliação de foco e retorno simulado de qualidade adequada', ['08', '09']),
        ('qualidade', 'Decisão do profissional e indicação simulada de qualidade inadequada', ['09b', '10']),
        ('retorno-qualidade', 'Alternativas disponíveis após indicação de foco inadequado', ['10b']),
    ],
    'cnn_alternative': [
        ('cnn', 'Processamento da classificação e apresentação da classe sugerida', ['11', '12']),
        ('discordancia', 'Referências da classe e seleção entre classes alternativas', ['13', '14']),
        ('incerteza', 'Declaração de incerteza e preservação da sugestão após escolha alternativa', ['15', '41']),
    ],
    'questionnaire_uncertain': [
        ('questionario', 'Seções do questionário demonstrativo', ['16', '17']),
        ('questionario-provisorio', 'Identificação da classe provisória e controles do formulário', ['18', '35']),
    ],
    'review_multimodal': [
        ('revisao', 'Revisão das respostas e confirmação do encaminhamento', ['19', '36']),
        ('multimodal', 'Espera pelo resultado do modelo multimodal fantasma', ['20']),
    ],
    'risks': [
        ('riscos', 'Apresentação das três categorias de risco simulado', ['21', '22', '23']),
        ('orientacoes', 'Orientações demonstrativas e ações após o resultado', ['37']),
    ],
    'uncertain_completed': [
        ('resultado-provisorio', 'Resultado com classe provisória e aviso de não confirmação', ['24', '24b']),
        ('conclusao', 'Encerramento explícito da análise e exportação do histórico', ['25']),
    ],
    'history_errors': [
        ('historico', 'Histórico da execução e recuperação de arquivo inválido', ['31', '32']),
        ('erro', 'Falha controlada de serviço e ação de nova tentativa', ['33']),
    ],
    'support': [
        ('biblioteca', 'Biblioteca local e visualização ampliada com atribuição', ['26', '27']),
        ('sobre', 'Informações sobre o sistema e preferências de aparência', ['28', '29']),
        ('modo', 'Escolha explícita do modo de execução da próxima análise', ['34']),
    ],
    'themes_demo': [
        ('demonstracao', 'Painel de cenários e tela inicial em tema escuro', ['30', '38']),
        ('escuro', 'Conferência de recorte e resultado em tema escuro', ['39', '40']),
    ],
}

SOURCE = ('Fonte: Elaborado pela autora a partir de renderizações controladas do '
          'aplicativo. Fotografias clínicas, quando presentes: Gomes et al. (2023).')


def image_file(prefix):
    found = list(FIGURES.glob(prefix + '-*.png'))
    if len(found) != 1:
        raise ValueError(f'Expected exactly one capture for {prefix}: {found}')
    return found[0]


def blocks(markdown):
    lines = markdown.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line:
            continue
        if line.startswith('#'):
            level = len(line) - len(line.lstrip('#'))
            yield ('heading', level, line[level:].strip())
        elif line.startswith('{{FIG:'):
            marker = re.fullmatch(r'\{\{FIG:([a-z_]+)\}\}', line).group(1)
            for identifier, caption, prefixes in GROUPS[marker]:
                yield ('figure', identifier, caption, [image_file(p) for p in prefixes])
        elif line.startswith('|'):
            table = [line]
            while i < len(lines) and lines[i].strip().startswith('|'):
                table.append(lines[i].strip())
                i += 1
            rows = [[cell.strip() for cell in row.strip('|').split('|')]
                    for row in table if not re.fullmatch(r'[| :\-]+', row)]
            yield ('table', rows)
        else:
            paragraph = [line]
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(('#', '{{FIG:', '|')):
                paragraph.append(lines[i].strip())
                i += 1
            yield ('paragraph', ' '.join(paragraph))


def latex_escape(text):
    specials = {'\\': r'\textbackslash{}', '&': r'\&', '%': r'\%', '$': r'\$',
                '#': r'\#', '_': r'\_', '{': r'\{', '}': r'\}', '~': r'\textasciitilde{}',
                '^': r'\textasciicircum{}'}
    return ''.join(specials.get(c, c) for c in text)


def latex_inline(text):
    parts = re.split(r'(`[^`]+`)', text)
    return ''.join(r'\texttt{' + latex_escape(p[1:-1]) + '}' if p.startswith('`')
                   else latex_escape(p) for p in parts)


def html_inline(text):
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', html.escape(text))


def build_tex(content):
    out = [
        '% Generated from capitulo-implementacao.md; original thesis untouched.',
        '% Requires graphicx and longtable in the existing main preamble.',
        r'\providecommand{\pipelinefigdir}{capitulo-implementacao/figuras}',
    ]
    for block in content:
        kind = block[0]
        if kind == 'heading':
            _, level, title = block
            title = re.sub(r'^4(?:\.\d+)*\s+', '', title)
            command = 'chapter' if level == 1 else 'section'
            out.append('\\' + command + '{' + latex_inline(title) + '}')
            if level == 1:
                out.append(r'\label{cap:implementacao-pipeline}')
        elif kind == 'paragraph':
            out.append(latex_inline(block[1]) + '\n')
        elif kind == 'table':
            rows = block[1]
            out += [r'\begingroup\small', r'\begin{longtable}{p{0.34\textwidth}p{0.60\textwidth}}',
                    r'\hline', ' & '.join(r'\textbf{' + latex_inline(c) + '}' for c in rows[0]) + r' \\',
                    r'\hline\endhead']
            out += [' & '.join(latex_inline(c) for c in row) + r' \\' for row in rows[1:]]
            out += [r'\hline\end{longtable}', r'\endgroup']
        elif kind == 'figure':
            _, identifier, caption, files = block
            width = .275 if len(files) == 3 else .37
            panels = [f'\\includegraphics[width={width:.3f}\\textwidth]{{\\pipelinefigdir/{p.name}}}' for p in files]
            out += [r'\begin{figure}[htbp]', r'\centering', r'\hfill'.join(panels),
                    r'\caption{' + latex_inline(caption) + '}',
                    r'\label{fig:impl-' + identifier + '}', r'{\footnotesize ' + latex_inline(SOURCE) + r'\par}',
                    r'\end{figure}']
    out.append(r'\clearpage')
    (ROOT / 'capitulo-implementacao.tex').write_text('\n'.join(out) + '\n')


def build_html(content):
    out = ['<!doctype html><html lang="pt-BR"><meta charset="utf-8">',
           '<meta name="viewport" content="width=device-width,initial-scale=1">',
           '<title>Capítulo 4 — Implementação do pipeline</title>',
           '''<style>
           body{margin:0;background:#eee8e5;color:#282324;font:18px/1.6 Georgia,serif}
           article{max-width:860px;margin:30px auto;padding:50px 60px;background:white}
           h1{font-size:27px;line-height:1.3}h2{font-size:22px;margin-top:40px}
           p{text-align:justify}code{font-size:.83em;overflow-wrap:anywhere}
           table{width:100%;border-collapse:collapse;font-size:15px;margin:25px 0}
           th,td{border:1px solid #ddd;padding:10px;vertical-align:top;text-align:left}
           th{background:#f8f2f0}figure{margin:32px 0;break-inside:avoid}
           .panels{display:flex;gap:12px;justify-content:center;align-items:flex-start}
           .panels img{max-width:32%;height:auto;box-shadow:0 0 0 1px #eee}
           .panels.two img{max-width:39%}.panels.one img{max-width:39%}
           figcaption{font-size:15px;text-align:center;margin-top:12px}
           .source{font-size:12px;color:#555;margin:5px;text-align:center}
           .notice{padding:14px;background:#f4efeb;font:14px/1.5 system-ui}
           @media(max-width:650px){article{padding:22px;margin:0}body{font-size:16px}}
           @media print{body{background:white}article{margin:0;padding:0}h2{break-after:avoid}
           .notice{display:none}.panels img{box-shadow:none}@page{size:A4;margin:25mm}}
           </style><article>''',
           '<div class="notice">Prévia de leitura independente. O arquivo LaTeX é editável para integração ao modelo do TCC. '
           'As imagens são renderizações Flutter em testes locais; não são capturas de um aparelho nem evidência de comunicação cloud.</div>']
    number = 1
    for block in content:
        kind = block[0]
        if kind == 'heading':
            out.append(f'<h{block[1]}>{html_inline(block[2])}</h{block[1]}>')
        elif kind == 'paragraph':
            out.append('<p>' + html_inline(block[1]) + '</p>')
        elif kind == 'table':
            rows = block[1]
            out.append('<table><thead><tr>' + ''.join('<th>' + html_inline(c) + '</th>' for c in rows[0]) + '</tr></thead><tbody>')
            out.extend('<tr>' + ''.join('<td>' + html_inline(c) + '</td>' for c in row) + '</tr>' for row in rows[1:])
            out.append('</tbody></table>')
        else:
            _, identifier, caption, files = block
            number += 1
            count = ['one', 'two', 'three'][len(files)-1]
            out.append(f'<figure id="{identifier}"><div class="panels {count}">')
            for p in files:
                out.append(f'<a href="figuras/{p.name}" style="display:contents"><img src="figuras/{p.name}" alt="{html.escape(caption)} — {p.stem}"></a>')
            out.append(f'</div><figcaption>Figura {number}: {html.escape(caption)}</figcaption><p class="source">{html.escape(SOURCE)}</p></figure>')
    out.append('</article></html>')
    (ROOT / 'capitulo-implementacao.html').write_text('\n'.join(out))


def build_pdf(content):
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
    from reportlab.lib import colors
    from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Image, Table,
                                   TableStyle, KeepTogether)
    from PIL import Image as PillowImage
    width = A4[0] - 142
    styles = {
        'body': ParagraphStyle('body', fontName='Times-Roman', fontSize=12, leading=18,
                               firstLineIndent=23, spaceAfter=9, alignment=TA_JUSTIFY),
        'title': ParagraphStyle('title', fontName='Times-Bold', fontSize=16, leading=21, spaceAfter=24),
        'section': ParagraphStyle('section', fontName='Times-Bold', fontSize=13, leading=18,
                                  spaceBefore=20, spaceAfter=12, keepWithNext=True),
        'caption': ParagraphStyle('caption', fontName='Times-Roman', fontSize=10, leading=13,
                                  alignment=TA_CENTER, spaceBefore=8, spaceAfter=4),
        'source': ParagraphStyle('source', fontName='Times-Roman', fontSize=8, leading=10,
                                 alignment=TA_CENTER, spaceAfter=12),
        'cell': ParagraphStyle('cell', fontName='Times-Roman', fontSize=10, leading=13),
    }
    def inline(s):
        return re.sub(r'`([^`]+)`', r'<font name="Courier" size="10">\1</font>', html.escape(s))
    story = []
    number = 1
    for b in content:
        if b[0] == 'heading':
            story.append(Paragraph(inline(b[2]), styles['title' if b[1] == 1 else 'section']))
        elif b[0] == 'paragraph':
            story.append(Paragraph(inline(b[1]), styles['body']))
        elif b[0] == 'table':
            rows = [[Paragraph(inline(c), styles['cell']) for c in row] for row in b[1]]
            table = Table(rows, colWidths=[width*.36, width*.64], repeatRows=1)
            table.setStyle(TableStyle([
                ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eee8e5')),
                ('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.3,colors.HexColor('#bbb')),
                ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
            story += [Spacer(1,8),table,Spacer(1,12)]
        else:
            _, identifier, caption, files = b
            number += 1
            panel_width = 128 if len(files)==3 else 176
            images = []
            for f in files:
                with PillowImage.open(f) as im:
                    iw, ih = im.size
                images.append(Image(str(f),width=panel_width,height=panel_width*ih/iw))
            table = Table([images],colWidths=[panel_width+8]*len(images),hAlign='CENTER')
            table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),4),('RIGHTPADDING',(0,0),(-1,-1),4)]))
            story.append(KeepTogether([Spacer(1,10),table,
                Paragraph(f'Figura {number}: {inline(caption)}',styles['caption']),
                Paragraph(SOURCE,styles['source'])]))
    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Times-Roman',8)
        canvas.drawString(85,35,'Prévia de leitura — formatação independente do modelo Overleaf')
        canvas.drawRightString(A4[0]-57,35,str(doc.page))
        canvas.restoreState()
    doc = SimpleDocTemplate(str(ROOT/'capitulo-implementacao.pdf'),pagesize=A4,
            leftMargin=85,rightMargin=57,topMargin=70,bottomMargin=57,
            title='Capítulo 4 — Implementação do pipeline',author='Luisa Becker dos Santos')
    doc.build(story,onFirstPage=footer,onLaterPages=footer)


def main():
    content = list(blocks((ROOT/'capitulo-implementacao.md').read_text()))
    actual = {p.name for b in content if b[0]=='figure' for p in b[3]}
    manifest = json.loads((FIGURES/'manifest.json').read_text())
    expected = {c['file'] for c in manifest['captures']}
    if actual != expected:
        raise ValueError(f'Figure coverage mismatch: missing={expected-actual}, extra={actual-expected}')
    build_tex(content)
    build_html(content)
    build_pdf(content)
    print(f'Generated LaTeX, HTML and reading PDF: {len(actual)} captures, '
          f'{sum(b[0]=="figure" for b in content)} figure groups.')


if __name__ == '__main__':
    main()
