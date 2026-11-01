#!/usr/bin/env python3
"""Reproducible, editable SVG mockups and an offline, deterministic UX prototype.

This is the explicit fallback when native Figma authoring is unavailable. It
does not create Figma components, variables, Auto Layout or prototype links.
Clinical assets are embedded unchanged; their source-defined class is not a
simulated risk label. No network request is made by this builder or prototype.
"""
from __future__ import annotations

import base64
import html
import json
import textwrap
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
TOKENS = json.loads((ROOT / 'design/tokens/resolved.json').read_text())
PRIMITIVES = json.loads((ROOT / 'design/tokens/primitives.json').read_text())
LIBRARY = ROOT / 'design/reference_library'
ASSETS = json.loads((LIBRARY / 'manifest.json').read_text())
CLASSES = ['Pápula/nódulo', 'Mácula/mancha', 'Vesícula/bolha', 'Erosão', 'Úlcera', 'Placa']
IMAGES = {a['id']: a for a in ASSETS['assets']}
W, H = 390, 844
FONT = 'Inter, Arial, sans-serif'
SCREEN_NAMES = {
    '01-home': 'Início', '02-new': 'Nova análise', '03-source': 'Selecionar imagem',
    '04-preview': 'Pré-visualização', '05-detecting': 'Processamento da região',
    '06-detected': 'Região encontrada', '07-crop': 'Validação do recorte',
    '08-editor': 'Editor manual', '09-no-detection': 'Falha de detecção',
    '10-replace': 'Novo envio', '11-focus': 'Verificar qualidade',
    '12-poor-focus': 'Imagem inadequada', '13-classification': 'Comparar lesão',
    '14-gallery': 'Referências ampliadas', '15-agreement': 'Classe confirmada',
    '16-disagreement': 'Discordância', '17-alternative': 'Seleção alternativa',
    '18-uncertainty': 'Incerteza', '19-questionnaire': 'Questionário',
    '20-review': 'Revisão das respostas', '21-processing': 'Processamento final',
    '22-low': 'Risco baixo', '23-medium': 'Risco médio', '24-high': 'Risco alto',
    '25-unconfirmed': 'Resultado com classe não confirmada',
    '26-complete': 'Sessão concluída', '27-about': 'Sobre o sistema',
    '28-error': 'Erro e recuperação', '29-library': 'Biblioteca de referências',
    '30-history': 'Histórico da execução', '31-section-two': 'Questionário — seção 2',
    '32-empty': 'Nenhuma análise iniciada', '33-offline': 'Cloud indisponível',
    '34-revisit': 'Revisão de decisões', '35-zoom': 'Imagem ampliada',
    '36-abandon': 'Sair da análise',
}
SCENARIOS = [
    {'id': 'complete', 'name': '1 · Fluxo sem correções', 'start': '01-home', 'detect': '06-detected', 'focus': '11-focus', 'result': '22-low'},
    {'id': 'manual', 'name': '2 · Recorte incorreto → manual', 'start': '07-crop', 'detect': '06-detected', 'focus': '11-focus', 'result': '23-medium'},
    {'id': 'replacement', 'name': '3 · Recorte incorreto → nova imagem', 'start': '07-crop', 'detect': '06-detected', 'focus': '11-focus', 'result': '24-high'},
    {'id': 'miss-manual', 'name': '4 · Sem detecção → manual', 'start': '09-no-detection', 'detect': '09-no-detection', 'focus': '11-focus', 'result': '22-low'},
    {'id': 'miss-replace', 'name': '5 · Sem detecção → nova imagem', 'start': '09-no-detection', 'detect': '06-detected', 'focus': '11-focus', 'result': '23-medium'},
    {'id': 'focus', 'name': '6 · Qualidade inadequada', 'start': '11-focus', 'detect': '06-detected', 'focus': '12-poor-focus', 'result': '24-high'},
    {'id': 'agree', 'name': '7 · Concordância com a classe', 'start': '13-classification', 'detect': '06-detected', 'focus': '11-focus', 'result': '22-low'},
    {'id': 'correct', 'name': '8 · Classe alternativa', 'start': '16-disagreement', 'detect': '06-detected', 'focus': '11-focus', 'result': '23-medium'},
    {'id': 'uncertain', 'name': '9 · Não consigo determinar', 'start': '16-disagreement', 'detect': '06-detected', 'focus': '11-focus', 'result': '25-unconfirmed'},
    {'id': 'low', 'name': '10 · Resultado baixo', 'start': '20-review', 'detect': '06-detected', 'focus': '11-focus', 'result': '22-low'},
    {'id': 'medium', 'name': '11 · Resultado médio', 'start': '20-review', 'detect': '06-detected', 'focus': '11-focus', 'result': '23-medium'},
    {'id': 'high', 'name': '12 · Resultado alto', 'start': '20-review', 'detect': '06-detected', 'focus': '11-focus', 'result': '24-high'},
    {'id': 'return', 'name': '13 · Alterar decisão anterior', 'start': '34-revisit', 'detect': '06-detected', 'focus': '11-focus', 'result': '22-low'},
    {'id': 'format', 'name': '14 · Arquivo inválido', 'start': '28-error', 'detect': '06-detected', 'focus': '11-focus', 'result': '23-medium'},
    {'id': 'feedback', 'name': '15 · Correções e feedback', 'start': '08-editor', 'detect': '06-detected', 'focus': '11-focus', 'result': '25-unconfirmed'},
]


class Canvas:
    def __init__(self, theme='light', width=W, height=H, title='Pipeline Bucal'):
        self.c = TOKENS[theme]
        self.theme, self.w, self.h, self.title = theme, width, height, title
        self.parts = []
        self.links = []
        self.boxes = []
        self.serial = 0
        self.rect(0, 0, width, height, 'background', r=0)

    def color(self, token):
        return self.c.get(token, token)

    def rect(self, x, y, w, h, token='surface', r=24, stroke=None, opacity=1, extra=''):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{self.color(token)}" data-token="{token}" opacity="{opacity}" {f"stroke={chr(34)}{self.color(stroke)}{chr(34)}" if stroke else ""} {extra}/>')

    def text(self, value, x, y, size=16, color='textPrimary', weight=400, max_width=342, line=None, tracking=0):
        line = line or round(size * 1.45, 1)
        # Glyph width conservatively estimated for Inter; original text remains editable.
        lines = []
        for paragraph in value.split('\n'):
            lines += textwrap.wrap(paragraph, max(1, int(max_width / (size * .52))), break_long_words=False, break_on_hyphens=False) or ['']
        for n, value_line in enumerate(lines):
            self.parts.append(f'<text x="{x}" y="{y+n*line+size}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" letter-spacing="{tracking}" fill="{self.color(color)}" data-token="{color}">{html.escape(value_line)}</text>')
        return len(lines) * line

    def icon(self, name, x, y, color='textPrimary', size=24):
        paths = {
            'arrow': '<path d="M9 5l7 7-7 7"/>', 'back': '<path d="M15 5l-7 7 7 7"/>',
            'check': '<path d="M5 12l4 4L19 6"/>', 'plus': '<path d="M12 5v14M5 12h14"/>',
            'home': '<path d="M3 10l9-7 9 7v10H3zM9 20v-7h6v7"/>',
            'analysis': '<rect x="4" y="4" width="16" height="16" rx="5"/><path d="M8 12h8M12 8v8"/>',
            'library': '<path d="M3 4h7a2 2 0 012 2v15a3 3 0 00-3-2H3zM21 4h-7a2 2 0 00-2 2v15a3 3 0 013-2h6z"/>',
            'camera': '<path d="M3 7h4l2-3h6l2 3h4v13H3z"/><circle cx="12" cy="13" r="4"/>',
            'image': '<rect x="3" y="3" width="18" height="18" rx="4"/><circle cx="8" cy="8" r="1"/><path d="M3 17l6-6 4 4 3-3 5 5"/>',
            'crop': '<path d="M7 3v14h14M3 7h14v14"/>',
            'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',
            'warning': '<path d="M12 3L2 21h20zM12 9v5M12 17h.01"/>',
            'cloud': '<path d="M6 18a5 5 0 01-1-10 7 7 0 0113 1 4.5 4.5 0 010 9z"/>',
            'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v6l4 2"/>',
            'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 1v2M12 21v2M1 12h2M21 12h2M4 4l1 1M19 19l1 1M4 20l1-1M19 5l1-1"/>',
            'focus': '<path d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5"/><circle cx="12" cy="12" r="4"/>',
            'shield': '<path d="M12 2l8 4v6c0 5-8 10-8 10S4 17 4 12V6zM8 12l3 3 5-6"/>',
            'close': '<path d="M6 6l12 12M6 18L18 6"/>',
            'download': '<path d="M12 3v12M7 10l5 5 5-5M4 16v5h16v-5"/>',
        }
        self.parts.append(f'<g transform="translate({x} {y}) scale({size/24})" fill="none" stroke="{self.color(color)}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" data-icon="{name}">{paths[name]}</g>')

    def action(self, target, label, x, y, w, h, draw):
        self.links.append({'target': target, 'label': label, 'bounds': [x, y, w, h]})
        self.boxes.append([x, y, w, h, label])
        self.parts.append(f'<a href="#{html.escape(target)}" data-go="{html.escape(target)}" aria-label="{html.escape(label)}" tabindex="0"><title>{html.escape(label)}</title>')
        draw()
        self.parts.append('</a>')

    def button(self, label, y, target, style='primary', x=24, w=342, icon=None, disabled=False):
        def draw():
            bg, fg = {'primary': ('primary', 'onPrimary'), 'secondary': ('surfaceSelected', 'onSecondary'), 'tertiary': ('background', 'primary')}[style]
            if disabled:
                bg, fg = 'disabledSurface', 'disabledText'
            self.rect(x, y, w, 52, bg, 16)
            if icon:
                self.icon(icon, x+18, y+14, fg)
            self.text(label, x+(48 if icon else 18), y+14, 15, fg, 600, w-36-(30 if icon else 0), 22)
            if not icon:
                self.icon('arrow', x+w-38, y+16, fg, 20)
        if disabled:
            draw()
        else:
            self.action(target, label, x, y, w, 52, draw)

    def badge(self, label, y, x=24, tone='info', w=None):
        w = w or int(len(label) * 6.7 + 24)
        self.rect(x, y, w, 28, tone+'Surface', 14)
        self.text(label, x+12, y+6, 11, tone, 600, w-24, 16, .4)

    def notice(self, text, y, tone='info', title=None, height=None):
        lines = len(textwrap.wrap(text, 39))
        height = height or max(76, 36 + lines*20 + (28 if title else 0))
        self.rect(24, y, 342, height, tone+'Surface', 20)
        self.icon('warning' if tone in ('warning', 'error') else 'info', 40, y+18, tone, 20)
        ty = y+15
        if title:
            self.text(title, 72, ty, 14, tone, 600, 278, 20)
            ty += 26
        self.text(text, 72, ty, 13, tone, 400, 274, 20)
        return height

    def image(self, y, h=190, asset='gomes2023_fig2_class4_a', bbox=False, editor=False, x=24, w=342, caption=True):
        record = IMAGES[asset]
        data = base64.b64encode((LIBRARY/record['file']).read_bytes()).decode()
        self.serial += 1
        cid = f'photo-{self.serial}'
        self.parts.append(f'<defs><clipPath id="{cid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24"/></clipPath></defs>')
        self.rect(x, y, w, h, 'surfaceSubtle', 24)
        self.parts.append(f'<image x="{x+12}" y="{y+12}" width="{w-24}" height="{h-24}" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,{data}" clip-path="url(#{cid})" data-source="{asset}"/>')
        if bbox:
            bx, by, bw, bh = x+w*.24, y+h*.24, w*.52, h*.52
            self.parts.append('<g id="crop-box" data-interactive="crop">')
            self.rect(bx, by, bw, bh, 'none', 6, '#231919', extra='stroke-width="4"')
            self.rect(bx, by, bw, bh, 'none', 6, '#FFFFFF', extra='stroke-width="2"')
            for dx, dy in ((0,0),(bw,0),(0,bh),(bw,bh)):
                self.rect(bx+dx-5, by+dy-5, 10, 10, '#FFFFFF', 2, '#231919')
            if editor:
                self.parts.append(f'<path d="M{bx+bw/3} {by}v{bh}M{bx+2*bw/3} {by}v{bh}M{bx} {by+bh/3}h{bw}M{bx} {by+2*bh/3}h{bw}" stroke="white" opacity=".55"/>')
            self.parts.append('</g>')
        if caption:
            self.text('Exemplo publicado · Gomes et al., 2023', x+2, y+h+8, 11, 'textMuted', 400, w, 16)
        return h + (32 if caption else 0)

    def logo(self, x, y, size=48):
        path=ROOT/'mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
        if not path.exists():
            path=ROOT/'design/branding/app_icon.png'
        if path.exists():
            data=base64.b64encode(path.read_bytes()).decode()
            self.parts.append(f'<image x="{x}" y="{y}" width="{size}" height="{size}" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,{data}" data-asset="app_icon"/>')
        else:
            self.icon('focus',x,y,'primary',size)

    def start(self, title, step=None, subtitle=None, back='01-home', selected=1):
        self.text('9:41', 26, 18, 12, weight=600, max_width=60)
        self.parts.append(f'<g fill="{self.c["textPrimary"]}"><rect x="329" y="24" width="3" height="5" rx="1"/><rect x="335" y="21" width="3" height="8" rx="1"/><rect x="341" y="18" width="3" height="11" rx="1"/><rect x="351" y="20" width="17" height="9" rx="3"/></g>')
        self.action(back, 'Voltar', 16, 53, 48, 48, lambda: self.icon('back', 28, 65))
        self.text('PIPELINE BUCAL', 72, 68, 11, 'textSecondary', 600, 245, 16, 1.7)
        self.action('27-about', 'Sobre o sistema', 326, 53, 48, 48, lambda: self.icon('info', 338, 65, 'textSecondary'))
        if step:
            self.text(f'ETAPA {step} DE 6', 24, 118, 11, 'primary', 600, 130, 16, 1.3)
            for i in range(6):
                self.rect(24+i*58, 145, 52, 3, 'primary' if i<step else 'border', 1)
            title_y = 164
        else:
            title_y = 122
        height = self.text(title, 24, title_y, 28, weight=600, line=36, tracking=-.5)
        if subtitle:
            self.text(subtitle, 24, title_y+height+12, 14, 'textSecondary', max_width=340, line=22)
        self.nav(selected)

    def nav(self, selected=1):
        self.rect(24, 756, 342, 64, 'navigation', 32)
        specs = [('Início','home','01-home'),('Análise','analysis','32-empty'),('Biblioteca','library','29-library')]
        for i, (label, icon, target) in enumerate(specs):
            x = 31 + i*111
            def draw(i=i, x=x, label=label, icon=icon):
                if i == selected:
                    self.rect(x, 763, 106, 50, 'navigationSelected', 25)
                fg = 'onNavigationSelected' if i==selected else 'onNavigation'
                self.icon(icon, x+12, 778, fg, 20)
                self.text(label, x+39, 781, 11, fg, 600, 66, 16)
            self.action(target, label, x, 763, 106, 50, draw)
        self.rect(148, 834, 94, 3, 'textPrimary', 2, opacity=.5)

    def choice(self, label, y, target, selected=False, detail=None, icon=None):
        height = 74 if detail else 56
        def draw():
            self.rect(24, y, 342, height, 'surfaceSelected' if selected else 'surface', 16, 'primary' if selected else 'border')
            if icon:
                self.icon(icon, 42, y+(height-24)/2, 'primary')
            else:
                self.parts.append(f'<circle cx="51" cy="{y+height/2}" r="9" fill="none" stroke="{self.c["primary"] if selected else self.c["outline"]}" stroke-width="1.6"/>')
                if selected:
                    self.parts.append(f'<circle cx="51" cy="{y+height/2}" r="4" fill="{self.c["primary"]}"/>')
            self.text(label, 77, y+17, 15, weight=600, max_width=267, line=22)
            if detail:
                self.text(detail, 77, y+42, 12, 'textSecondary', max_width=267, line=18)
        self.action(target, label, 24, y, 342, height, draw)

    def finish(self):
        return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" role="img" aria-labelledby="title"><title id="title">{html.escape(self.title)} — {self.theme}</title><metadata>Editable vector mockup. Theme tokens from design/tokens/resolved.json. Not a native Figma component. Clinical photographs retain source attribution.</metadata>'+''.join(self.parts)+'</svg>'


def render_screen(key, theme):
    c = Canvas(theme, title=SCREEN_NAMES[key])
    if key == '01-home':
        c.start('Clareza em\ncada etapa.', subtitle='Um fluxo guiado para apoiar a observação de lesões bucais.', selected=0)
        c.badge('PROTÓTIPO ACADÊMICO', 312, tone='info')
        c.rect(24, 366, 342, 168, 'surface', 24, 'border')
        c.logo(44, 386, 48)
        c.text('Uma imagem. Um percurso.', 44, 450, 19, weight=600, max_width=302, line=27)
        c.text('Revise, compare e acompanhe cada decisão.', 44, 484, 14, 'textSecondary', max_width=302, line=22)
        c.button('Nova análise', 558, '02-new', icon='plus')
        c.text('Para profissionais da saúde. Resultados simulados não substituem avaliação médica.', 28, 636, 13, 'textSecondary', max_width=334, line=21)
    elif key == '02-new':
        c.start('Comece pela imagem', subtitle='Uma lesão por análise. Você poderá revisar cada etapa antes de avançar.', selected=1)
        c.rect(24, 290, 342, 184, 'surface', 24, 'border')
        for y, title, detail, ico in [(314,'Selecione uma imagem','Câmera, galeria ou exemplo publicado.','image'),(388,'Acompanhe as etapas','As decisões ficam vinculadas à sessão.','analysis')]:
            c.icon(ico, 44, y+5, 'primary')
            c.text(title, 82, y, 16, weight=600, max_width=260, line=24)
            c.text(detail, 82, y+29, 13, 'textSecondary', max_width=256, line=20)
        c.notice('Ao continuar, a imagem escolhida será enviada ao serviço de simulação na cloud.', 500, height=112)
        c.button('Selecionar imagem', 638, '03-source', icon='image')
    elif key == '03-source':
        c.start('Selecionar imagem', 1, 'Escolha como deseja iniciar.', back='02-new')
        c.choice('Capturar fotografia', 286, '04-preview', detail='Usar a câmera do dispositivo', icon='camera')
        c.choice('Escolher da galeria', 376, '04-preview', detail='Selecionar uma imagem existente', icon='image')
        c.choice('Usar imagem de exemplo', 466, '29-library', detail='Fontes científicas do projeto', icon='library')
        c.text('A captura e a seleção são representadas neste mockup. No aplicativo, usam os recursos do celular.', 28, 582, 13, 'textSecondary', max_width=334, line=21)
    elif key == '04-preview':
        c.start('Conferir imagem', 1, 'Esta imagem será usada nesta análise.', back='03-source')
        c.image(278, 230)
        c.badge('1 IMAGEM · 1 LESÃO', 554, tone='info')
        c.button('Usar esta imagem', 610, '05-detecting', icon='check')
        c.button('Escolher outra', 674, '03-source', 'tertiary', icon='image')
    elif key in ('05-detecting','21-processing'):
        final = key == '21-processing'
        c.start('Preparando o resultado' if final else 'Localizando a região', 6 if final else 2, 'Processamento demonstrativo na cloud.', back='20-review' if final else '04-preview')
        c.rect(24, 298, 342, 230, 'surface', 24, 'border')
        c.parts.append(f'<circle cx="195" cy="370" r="28" fill="none" stroke="{c.c["border"]}" stroke-width="4"/><path d="M195 342a28 28 0 0128 28" fill="none" stroke="{c.c["primary"]}" stroke-width="4" stroke-linecap="round"/>')
        c.text('Imagem e decisões conectadas' if final else 'Analisando a imagem', 48, 428, 18, weight=600, max_width=294, line=27)
        c.text('Nenhum modelo real de IA é executado nesta versão.', 48, 468, 13, 'textSecondary', max_width=294, line=20)
        c.button('Ver resultado simulado' if final else 'Ver região sugerida', 606, '@result' if final else '@detect', icon='arrow')
        c.text('Toque para avançar no protótipo visual.', 36, 682, 12, 'textMuted', max_width=322)
    elif key in ('06-detected','07-crop'):
        validate = key == '07-crop'
        c.start('O recorte está adequado?' if validate else 'Região sugerida', 2, 'Confira se a região contém a lesão.', back='04-preview')
        c.image(278, 202, bbox=True)
        c.button('Sim, continuar' if validate else 'Conferir recorte', 550, '11-focus' if validate else '07-crop', icon='check')
        c.button('Ajustar recorte', 614, '08-editor', 'secondary', icon='crop')
        c.button('Enviar outra imagem', 678, '10-replace', 'tertiary', icon='image')
    elif key == '08-editor':
        c.start('Ajuste a região', 2, 'Mova a seleção para enquadrar a lesão.', back='07-crop')
        c.image(278, 242, bbox=True, editor=True)
        c.text('O novo recorte substituirá a região usada nas próximas etapas.', 28, 565, 14, 'textSecondary', max_width=334, line=22)
        c.button('Usar este recorte', 640, '11-focus', icon='check')
        c.text('Correção registrada como feedback demonstrativo.', 28, 709, 11, 'textMuted', max_width=334, line=17)
    elif key == '09-no-detection':
        c.start('Defina a região', 2, 'Nenhuma região foi sugerida nesta simulação.', back='04-preview')
        c.image(282, 180)
        c.notice('Selecione um recorte válido para seguir.', 508, tone='warning', height=78)
        c.button('Fazer recorte manual', 610, '08-editor', icon='crop')
        c.button('Enviar outra fotografia', 674, '10-replace', 'secondary', icon='image')
    elif key == '10-replace':
        c.start('Uma nova imagem', 1, 'O processamento recomeçará pela identificação da região.', back='07-crop')
        c.notice('O recorte e as decisões anteriores deixarão de valer para a nova imagem. O histórico será preservado.', 306, height=142)
        c.choice('Capturar fotografia', 492, '04-preview', icon='camera')
        c.choice('Escolher da galeria', 564, '04-preview', icon='image')
        c.button('Cancelar', 664, '07-crop', 'tertiary', icon='back')
    elif key == '11-focus':
        c.start('Verificar qualidade', 3, 'É possível observar a alteração com clareza?', back='07-crop')
        c.image(278, 202)
        c.text('Sua avaliação visual orienta a continuidade. A verificação automática é simulada.', 28, 534, 14, 'textSecondary', max_width=334, line=22)
        c.button('Qualidade adequada', 610, '13-classification', icon='check')
        c.button('Enviar nova imagem', 674, '12-poor-focus', 'secondary', icon='image')
    elif key == '12-poor-focus':
        c.start('Vamos tentar de novo', 3, 'Uma imagem mais nítida ajuda a observar a região.', back='11-focus')
        c.image(278, 190, asset='souza_focus_fig1_b_blurred', caption=False)
        c.text('Exemplo de foco · Souza et al., Figura 1(b)', 28, 480, 11, 'textMuted', max_width=334, line=17)
        c.notice('A qualidade foi considerada insuficiente. Uma nova imagem reiniciará o fluxo.', 528, tone='warning', height=108)
        c.button('Selecionar nova imagem', 668, '10-replace', icon='image')
    elif key == '13-classification':
        c.start('Comparar lesão', 4, back='11-focus')
        c.image(220, 160)
        c.badge('SUGESTÃO SIMULADA', 420, tone='info')
        c.text('Úlcera', 24, 460, 26, weight=600, line=34)
        c.text('A imagem apresenta características semelhantes à classe indicada.', 24, 504, 14, 'textSecondary', max_width=342, line=22)
        c.action('14-gallery','Ampliar referências',24,564,342,48,lambda: (c.text('Ver imagens de referência',24,574,14,'primary',600,max_width=300),c.icon('arrow',338,576,'primary',20)))
        c.button('Concordo com a classe', 620, '15-agreement', icon='check')
        c.button('Não concordo', 684, '16-disagreement', 'secondary', icon='image')
    elif key == '14-gallery':
        c.start('Referências: úlcera', 4, 'Exemplos publicados, sem classificação de risco.', back='13-classification')
        c.image(294, 210)
        c.notice('A foto foi extraída da Figura 2 de Gomes et al. (2023). A ampliação não recupera detalhes da imagem original.', 548, height=122)
        c.button('Voltar à comparação', 688, '13-classification', 'secondary', icon='back')
    elif key in ('15-agreement','18-uncertainty'):
        uncertain = key == '18-uncertainty'
        c.start('Você pode continuar' if uncertain else 'Confirmação registrada', 4, back='16-disagreement' if uncertain else '13-classification')
        c.rect(24, 270, 342, 158, 'surface', 24, 'border')
        c.icon('info' if uncertain else 'check', 44, 290, 'primary', 28)
        c.text('Classe não confirmada' if uncertain else 'Úlcera', 44, 342, 22, weight=600, max_width=300, line=30)
        c.text('Referência provisória: úlcera' if uncertain else 'Sua concordância foi registrada.', 44, 388, 13, 'textSecondary', max_width=300, line=20)
        if uncertain:
            c.notice('A sugestão original será usada apenas para escolher o questionário. Isso não representa validação clínica.', 456, tone='warning', height=142)
        else:
            c.notice('A confirmação da classe elementar não estabelece um diagnóstico.', 456, height=108)
        c.button('Ir ao questionário', 644, '@questionnaire-uncertain' if uncertain else '19-questionnaire', icon='arrow')
    elif key == '16-disagreement':
        c.start('Sua observação importa', 4, 'A sugestão original permanece no histórico.', back='13-classification')
        c.rect(24, 292, 342, 96, 'surface', 24, 'border')
        c.text('SUGESTÃO ORIGINAL', 44, 312, 11, 'textMuted', 600, 300, 16, 1)
        c.text('Úlcera · não confirmada', 44, 340, 18, weight=600, max_width=300)
        c.text('Você identifica outra classe visualmente semelhante?', 24, 426, 22, weight=600, max_width=342, line=30)
        c.button('Comparar outras classes', 540, '17-alternative', icon='library')
        c.button('Não consigo determinar', 604, '18-uncertainty', 'secondary', icon='info')
        c.text('A incerteza é registrada e não interrompe o fluxo.', 28, 688, 13, 'textSecondary', max_width=334, line=21)
    elif key == '17-alternative':
        c.start('Escolher outra classe', 4, 'Compare os exemplos antes de escolher.', back='16-disagreement')
        for n, class_index in enumerate([0,1,2,3,5]):
            y=284+n*74
            def draw(ci=class_index,y=y):
                c.rect(24,y,342,66,'surface',16,'border')
                c.image(y+5,56,f'gomes2023_fig2_class{ci}_a',x=29,w=70,caption=False)
                c.text(CLASSES[ci],115,y+20,15,weight=600,max_width=220,line=22)
                c.icon('arrow',336,y+23,'primary',18)
            c.action(f'@class-{class_index}',CLASSES[class_index],24,y,342,66,draw)
        c.button('Não consigo determinar', 676, '18-uncertainty', 'tertiary', icon='info')
    elif key in ('19-questionnaire','31-section-two'):
        second = key == '31-section-two'
        c.start('Informações clínicas', 5, 'Perguntas demonstrativas · sem critérios clínicos.', back='19-questionnaire' if second else '13-classification')
        c.badge('CLASSE DO FLUXO: ÚLCERA', 270, tone='info')
        c.text('2 de 2 · Observação' if second else '1 de 2 · Contexto', 24, 318, 18, weight=600, line=26)
        c.text('Deseja registrar uma observação?' if second else 'Há uma informação adicional disponível?', 24, 366, 22, weight=600, line=30)
        c.choice('Sim', 464, '@answer-yes', selected=True)
        c.choice('Não', 532, '@answer-no')
        c.choice('Não informado', 600, '@answer-unknown')
        c.button('Revisar respostas' if second else 'Próxima seção', 680, '20-review' if second else '31-section-two', icon='arrow')
    elif key == '20-review':
        c.start('Revisar informações', 5, 'Confirme as respostas antes de continuar.', back='31-section-two')
        c.rect(24, 280, 342, 230, 'surface', 24, 'border')
        for y, label, value in [(302,'Classe utilizada','Úlcera'),(370,'Contexto','Sim'),(438,'Observação','Não informado')]:
            c.text(label, 44, y, 12, 'textMuted', max_width=300, line=18)
            c.text(value, 44, y+24, 17, weight=600, max_width=300, line=25)
        c.text('As respostas e o recorte atual serão enviados juntos ao módulo simulado.', 28, 548, 14, 'textSecondary', max_width=334, line=22)
        c.button('Confirmar e continuar', 622, '21-processing', icon='check')
        c.button('Editar respostas', 686, '19-questionnaire', 'tertiary', icon='back')
    elif key in ('22-low','23-medium','24-high','25-unconfirmed'):
        kind = {'22-low':0,'23-medium':1,'24-high':2,'25-unconfirmed':1}[key]
        tone=['success','warning','error'][kind]
        label=['Risco baixo','Risco médio','Risco alto'][kind]
        guidance=[
            'O resultado demonstrativo não garante ausência de doença. Mantenha a avaliação médica adequada.',
            'Busque avaliação médica para investigar a alteração observada.',
            'É importante buscar avaliação médica especializada para investigar a alteração.',
        ][kind]
        uncertain=key=='25-unconfirmed'
        c.start('Resultado da análise', 6, back='20-review')
        c.rect(24, 236, 342, 226 if not uncertain else 204, tone+'Surface', 24)
        c.icon(['shield','info','warning'][kind], 44, 258, tone, 32)
        c.text('RESULTADO SIMULADO', 44, 314, 11, tone, 600, 300, 16, 1)
        c.text(label, 44, 346, 32, tone, 600, 300, 40, -.8)
        c.text('Classificação de risco para fins demonstrativos.', 44, 400, 13, tone, max_width=300, line=20)
        if uncertain:
            c.notice('A classe usada como referência não foi confirmada pelo profissional.', 462, tone='warning', height=96)
            c.text(guidance, 28, 576, 14, 'textSecondary', max_width=334, line=22)
            c.text('Não é diagnóstico. Texto demonstrativo, sujeito à revisão por especialista.', 28, 646, 11, 'textSecondary', max_width=334, line=15)
        else:
            c.text(guidance, 28, 490, 16, 'textPrimary', max_width=334, line=25)
            c.text('Não é um diagnóstico. Texto demonstrativo, sujeito à revisão por especialista.', 28, 594, 12, 'textSecondary', max_width=334, line=19)
        c.button('Concluir análise', 680, '26-complete', icon='check')
    elif key == '26-complete':
        c.start('Percurso concluído', subtitle='As decisões desta execução estão disponíveis no histórico.', selected=1)
        c.rect(24, 300, 342, 168, 'surface', 24, 'border')
        c.icon('check', 44, 322, 'primary', 32)
        c.text('Cada etapa conectada.', 44, 380, 22, weight=600, max_width=300, line=30)
        c.text('Dados demonstrativos em memória.', 44, 428, 13, 'textSecondary', max_width=300, line=20)
        c.button('Nova análise', 528, '02-new', icon='plus')
        c.button('Ver histórico da execução', 592, '30-history', 'secondary', icon='clock')
        c.button('Voltar ao início', 656, '01-home', 'tertiary', icon='home')
    elif key == '27-about':
        c.start('Sobre o sistema', subtitle='Pipeline para imagens de lesões bucais.', back='01-home', selected=0)
        c.logo(306,264,48)
        c.text('Um protótipo acadêmico',24,272,22,weight=600,line=30)
        c.text('Este trabalho demonstra a circulação de imagens e informações, incluindo revisões e decisões do profissional.',24,320,16,'textSecondary',max_width=342,line=25)
        c.notice('Detecção, classificação e risco são simulados. Não há diagnóstico nem treinamento de modelos nesta versão.',460,height=132)
        c.text('TCC · Ciência da Computação\nLuisa Becker',28,626,14,'textSecondary',max_width=334,line=23)
    elif key in ('28-error','33-offline'):
        offline = key == '33-offline'
        c.start('Vamos recuperar o fluxo', 1, back='03-source')
        c.notice('Não foi possível conectar ao serviço de simulação.' if offline else 'Este arquivo não pôde ser aberto. Selecione uma fotografia em formato compatível.', 286, tone='error', title='Cloud indisponível' if offline else 'Imagem não reconhecida', height=154)
        c.text('Sua sessão permanece disponível. Tente novamente ou escolha outra entrada.',28,484,16,'textSecondary',max_width=334,line=25)
        c.button('Tentar novamente',606,'05-detecting' if offline else '03-source',icon='arrow')
        c.button('Voltar à seleção',670,'03-source','secondary',icon='image')
    elif key == '29-library':
        c.start('Biblioteca de referências', subtitle='Exemplos identificados nas fontes do projeto.', selected=2)
        for i, label in enumerate(CLASSES):
            x,y=24+(i%2)*179,270+(i//2)*150
            def draw(i=i,label=label,x=x,y=y):
                c.rect(x,y,163,134,'surface',20,'border')
                c.image(y+8,83,f'gomes2023_fig2_class{i}_a',x=x+8,w=147,caption=False)
                c.text(label,x+12,y+103,12,weight=600,max_width=143,line=18)
            c.action(f'@reference-{i}',label,x,y,163,134,draw)
        c.text('Gomes et al. (2023) · Figura 2 · CC BY 4.0',28,730,10,'textMuted',max_width=334,line=15)
    elif key == '30-history':
        c.start('Histórico da execução', subtitle='Somente dados demonstrativos, em memória.', back='26-complete')
        for i,(title,detail) in enumerate([('Imagem selecionada','Entrada vinculada à análise'),('Recorte corrigido','Feedback registrado para curadoria'),('Classe não confirmada','Continuidade provisória registrada'),('Resultado simulado','Risco médio · sem inferência clínica')]):
            y=282+i*84
            c.rect(24,y,342,72,'surface',16,'border')
            c.icon('check' if i!=2 else 'info',40,y+22,'primary',20)
            c.text(title,76,y+12,14,weight=600,max_width=270,line=21)
            c.text(detail,76,y+38,11,'textSecondary',max_width=270,line=17)
        c.button('Exportar histórico JSON',654,'@export',icon='download')
        c.text('Sem imagens ou informações identificáveis.',28,721,11,'textMuted',max_width=334,line=17)
    elif key == '32-empty':
        c.start('Sua próxima análise', subtitle='Um percurso simples, uma etapa por vez.', selected=1)
        c.rect(24,306,342,220,'surface',24,'border')
        c.icon('image',160,338,'primary',64)
        c.text('Nenhuma análise iniciada',44,438,21,weight=600,max_width=300,line=30)
        c.text('Selecione uma imagem para começar.',44,482,14,'textSecondary',max_width=300,line=22)
        c.button('Nova análise',604,'02-new',icon='plus')
    elif key == '34-revisit':
        c.start('Revisar uma decisão', subtitle='Ao alterar uma etapa, as respostas dependentes serão recalculadas.', back='20-review')
        for y,title,detail,target,icon in [(302,'Trocar imagem','Reinicia a identificação da região.','10-replace','image'),(392,'Alterar recorte','Reinicia qualidade e classificação.','08-editor','crop'),(482,'Alterar classe','Limpa respostas incompatíveis.','13-classification','library'),(572,'Editar respostas','Invalida o resultado anterior.','19-questionnaire','analysis')]:
            c.choice(title,y,target,detail=detail,icon=icon)
    elif key == '35-zoom':
        c.start('Imagem ampliada', subtitle='Exemplo de referência publicado.', back='14-gallery')
        c.image(280,280)
        c.notice('Resolução original pequena. A ampliação não acrescenta detalhes clínicos.',604,height=90)
    elif key == '36-abandon':
        c.start('Pausar ou encerrar?', subtitle='Você pode voltar às etapas sem perder as decisões desta sessão.', back='20-review')
        c.notice('Ao encerrar, o histórico marcará a execução como abandonada. Nada será apresentado como resultado concluído.',302,tone='warning',height=144)
        c.button('Continuar análise',514,'20-review',icon='arrow')
        c.button('Encerrar esta sessão',578,'01-home','secondary',icon='close')
    return c


def foundations(theme):
    c=Canvas(theme,1120,1180,'Foundations')
    c.text('PIPELINE BUCAL',48,40,14,'primary',600,1000,22,2)
    c.text('Foundations',48,86,42,weight=600,max_width=1024,line=54)
    c.text('Identidade acolhedora. Hierarquia clara. Decisões rastreáveis.',48,162,20,'textSecondary',max_width=1024,line=30)
    for row,(scale,name) in enumerate([('wine','Vinho · identidade'),('rose','Rosé · apoio'),('neutral','Neutros · estrutura')]):
        y=246+row*128
        c.text(name,48,y,18,weight=600,max_width=1024)
        for n,(level,value) in enumerate(PRIMITIVES['colors'][scale].items()):
            x=48+n*103
            c.rect(x,y+40,88,42,value,10)
            c.text(level+' · '+value,x,y+90,9,'textSecondary',max_width=100,line=13)
    c.text('Inter · escala tipográfica',48,650,24,weight=600,max_width=1024)
    for x,y,text,size in [(48,704,'Clareza em cada etapa.',32),(48,766,'Informações clínicas',28),(48,820,'Compare os exemplos',22),(48,866,'Uma etapa por vez.',18),(48,908,'Textos de corpo com leitura confortável.',16)]:
        c.text(text,x,y,size,weight=600 if size>16 else 400,max_width=800)
    c.text('ESPAÇO',704,650,11,'primary',600,300,16,1)
    for n,size in enumerate([4,8,12,16,24,32,40,48]):
        c.rect(704,696+n*38,size*3,12,'primary',3)
        c.text(str(size),880,690+n*38,12,'textSecondary',max_width=70)
    c.text('Contraste verificado · Toque mínimo de 48 px · Movimento reduzido respeitado',48,1060,16,'textSecondary',max_width=1024,line=24)
    c.text('Tokens primitivos e semânticos: design/tokens/ · Este SVG não contém variáveis nativas do Figma.',48,1120,12,'textMuted',max_width=1024,line=18)
    return c


def components(theme):
    c=Canvas(theme,1120,1600,'Components')
    c.text('Biblioteca de componentes',48,40,36,weight=600,max_width=1024,line=48)
    c.text('Variantes editáveis em SVG · estados e dimensões alinhados ao Flutter',48,108,16,'textSecondary',max_width=1024)
    # Each component lives in a labeled group, rather than a flattened screenshot.
    for col,(style,label) in enumerate([('primary','Primário'),('secondary','Secundário'),('tertiary','Terciário')]):
        x=48+col*350
        c.text(label,x,170,18,weight=600,max_width=310)
        for row,(state,text) in enumerate([('normal','Continuar'),('loading','Processando…'),('disabled','Indisponível')]):
            c.parts.append(f'<g id="button-{style}-{state}" data-component="BucalButton" data-variant="{style}" data-state="{state}">')
            c.button(text,222+row*80,'01-home',style,x=x,w=310,disabled=state=='disabled')
            c.parts.append('</g>')
    c.text('Seleção e entrada',48,490,24,weight=600,max_width=1024)
    for i,(label,selected) in enumerate([('Opção disponível',False),('Opção selecionada',True)]):
        c.parts.append(f'<g transform="translate(24 {566+i*80-300})" data-component="BucalChoiceTile">')
        c.choice(label,300,'01-home',selected)
        c.parts.append('</g>')
    c.rect(424,566,310,56,'surface',12,'outline')
    c.text('Campo de texto',442,582,15,'textSecondary',max_width=274)
    c.rect(424,646,310,56,'surface',12,'primary',extra='stroke-width="2"')
    c.text('Campo em foco',442,662,15,'textPrimary',max_width=274)
    c.rect(772,566,300,56,'surface',12,'error')
    c.text('Campo com erro',790,582,15,'textPrimary',max_width=264)
    c.text('Informe uma resposta para continuar.',772,632,12,'error',max_width=300)
    c.text('Orientação e estados',48,754,24,weight=600,max_width=1024)
    for n,(tone,label) in enumerate([('info','Informação'),('success','Confirmação'),('warning','Atenção'),('error','Recuperação')]):
        x=48+(n%2)*526;y=820+(n//2)*146
        c.rect(x,y,500,120,tone+'Surface',24)
        c.icon('info' if tone!='error' else 'warning',x+24,y+24,tone,24)
        c.text(label,x+68,y+22,18,tone,600,400)
        c.text('Mensagem descritiva. A cor sempre acompanha texto e ícone.',x+68,y+58,14,tone,max_width=400,line=22)
    c.text('Navegação flutuante',48,1142,24,weight=600,max_width=1024)
    c.parts.append('<g transform="translate(24 456)" data-component="BucalFloatingNav">')
    c.nav(1)
    c.parts.append('</g>')
    c.text('Áreas de toque ≥ 48 px. Três destinos persistentes.\nTrocar de aba preserva a análise em andamento.',438,1228,16,'textSecondary',max_width=600,line=25)
    c.text('Risco categórico',48,1332,24,weight=600,max_width=1024)
    for n,(tone,label,icon) in enumerate([('success','Risco baixo','shield'),('warning','Risco médio','info'),('error','Risco alto','warning')]):
        x=48+n*350
        c.rect(x,1390,310,112,tone+'Surface',24)
        c.icon(icon,x+20,1410,tone,24)
        c.text(label,x+20,1450,24,tone,600,270)
    c.text('Resultados demonstrativos · sem porcentagens · orientação médica em todas as categorias',48,1546,13,'textMuted',max_width=1024)
    return c


def user_flow(theme):
    c=Canvas(theme,1120,1700,'User Flows')
    c.text('Percurso e decisões',48,40,36,weight=600,max_width=1024,line=48)
    c.text('Imagens e decisões permanecem vinculadas à mesma análise.',48,108,16,'textSecondary',max_width=1024)
    c.parts.append(f'<defs><marker id="arrow" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0 0L7 3.5L0 7Z" fill="{c.c["primary"]}"/></marker></defs>')
    def box(x,y,title,subtitle,width=316,tone='surface'):
        c.rect(x,y,width,78,tone,18,'border')
        c.text(title,x+18,y+15,18,weight=600,max_width=width-36,line=26)
        c.text(subtitle,x+18,y+47,12,'textSecondary',max_width=width-36,line=18)
    def line(path,label=None,x=None,y=None):
        c.parts.append(f'<path d="{path}" fill="none" stroke="{c.c["primary"]}" stroke-width="1.8" marker-end="url(#arrow)"/>')
        if label:c.text(label,x,y,11,'primary',600,max_width=190,line=17)
    box(402,192,'Selecionar imagem','Novo identificador da imagem')
    box(402,320,'Sugerir região','Detecção simulada na cloud')
    box(402,448,'Conferir recorte','Região válida é obrigatória')
    box(780,448,'Recortar manualmente','Correção → feedback candidato',width=292,tone='surfaceSelected')
    box(48,448,'Enviar outra fotografia','Invalida todas as etapas seguintes',width=292)
    box(402,590,'Verificar qualidade','Confirmação visual do profissional')
    box(402,732,'Comparar lesão','Sugestão simulada da CNN preservada')
    box(48,878,'Concordo','Classe confirmada',width=292)
    box(414,878,'Outra classe','Escolha do profissional registrada',width=292)
    box(780,878,'Não consigo determinar','Classe original provisória',width=292,tone='warningSurface')
    box(402,1040,'Informações clínicas','Questionário da classe efetiva')
    box(402,1182,'Resultado simulado','Um de seis multimodais na cloud')
    box(402,1324,'Baixo · médio · alto','Sem porcentagem ou diagnóstico')
    box(402,1466,'Concluir e exportar','Eventos em memória · JSON sem fotos')
    for y1,y2 in [(270,320),(398,448),(526,590),(668,732),(1118,1182),(1260,1324),(1402,1466)]:
        line(f'M560 {y1}V{y2}')
    line('M718 487H780','Ajuste ou falha',728,418)
    line('M926 526V629H718','Recorte corrigido',784,578)
    line('M402 487H340','Reenviar',344,457)
    line('M194 448V231H402','Nova imagem',210,252)
    line('M402 629H194V526','Inadequada',204,598)
    line('M560 810V844H194V878')
    line('M560 810V878')
    line('M560 844H926V878')
    line('M194 956V1000H560V1040')
    line('M560 956V1040')
    line('M926 956V1000H560','Não interrompe',780,974)
    c.text('Revisar uma etapa invalida apenas os dados que dependem dela. O histórico preserva as decisões anteriores.',48,1600,16,'textSecondary',max_width=1024,line=25)
    c.text('Fluxo demonstrativo. Nenhum modelo real de IA, validação clínica ou retreinamento é executado.',48,1650,12,'textMuted',max_width=1024,line=18)
    return c


def main():
    screen_data={}
    inventory=[]
    for theme in TOKENS:
        directory=OUT/'svg'/theme
        directory.mkdir(parents=True,exist_ok=True)
        screen_data[theme]={}
        for key,name in SCREEN_NAMES.items():
            canvas=render_screen(key,theme)
            svg=canvas.finish()
            ElementTree.fromstring(svg)
            (directory/f'{key}.svg').write_text(svg,encoding='utf-8')
            screen_data[theme][key]=svg
            inventory.append({'id':key,'name':name,'theme':theme,'path':f'svg/{theme}/{key}.svg','width':W,'height':H,'links':canvas.links})
        for name,canvas in [('foundations',foundations(theme)),('components',components(theme)),('user-flows',user_flow(theme))]:
            svg=canvas.finish();ElementTree.fromstring(svg)
            (directory/f'00-{name}.svg').write_text(svg,encoding='utf-8')
    (OUT/'inventory.json').write_text(json.dumps({'screens':inventory,'scenarios':SCENARIOS},ensure_ascii=False,indent=2)+'\n')
    template=(OUT/'prototype.template.html').read_text()
    content=template.replace('/*__SCREENS__*/',json.dumps(screen_data,ensure_ascii=False)).replace('/*__NAMES__*/',json.dumps(SCREEN_NAMES,ensure_ascii=False)).replace('/*__SCENARIOS__*/',json.dumps(SCENARIOS,ensure_ascii=False))
    (OUT/'prototype.html').write_text(content,encoding='utf-8')
    all_ids=set(SCREEN_NAMES)
    unknown=sorted({link['target'] for screen in inventory for link in screen['links'] if not link['target'].startswith('@') and link['target'] not in all_ids})
    assert not unknown,unknown
    print(json.dumps({'svg_screens':len(inventory),'support_boards':6,'prototype_scenarios':len(SCENARIOS),'broken_links':unknown,'native_figma_created':False}))


if __name__=='__main__':
    main()
