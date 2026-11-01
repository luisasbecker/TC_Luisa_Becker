#!/usr/bin/env python3
"""Extract supplied SVG palette, resolve semantic tokens and generate Dart.

Python standard library only. Run from any directory. Original SVG is read-only.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent


def palette(source):
    texts = [''.join(node.itertext()).strip() for node in ET.parse(source).iter()
             if node.tag.endswith('}text')]
    names = {'vinho-terroso': 'wine', 'rosé': 'rose', 'neutros': 'neutral'}
    result = {v: {} for v in names.values()}
    for i, text in enumerate(texts):
        match = re.fullmatch(r'(vinho-terroso|rosé|neutros)-(50|[1-9]00)', text)
        if match:
            value = texts[i + 1]
            if not re.fullmatch(r'#[0-9A-Fa-f]{6}', value):
                raise ValueError(f'Missing color following {text}')
            result[names[match[1]]][match[2]] = value.upper()
    for values in result.values():
        if len(values) != 10:
            raise ValueError('Expected ten steps in each supplied palette')
    return result


def build(source):
    colors = palette(source)
    colors.update({
        'white': '#FFFFFF', 'darkBase': '#181313',
        'sage': {'light': '#E8F2EC', 'ink': '#2C5F4F', 'dark': '#20342C', 'onDark': '#B0D6BE'},
        'amber': {'light': '#FFF2D8', 'ink': '#725114', 'dark': '#392F1E', 'onDark': '#E9CA8A'},
        'danger': {'light': '#FCE6E4', 'ink': '#8C3634', 'dark': '#462825', 'onDark': '#F5B7B1'},
        'info': {'light': '#F0EAF3', 'ink': '#5E4D69', 'dark': '#302936', 'onDark': '#D4C5DE'},
    })
    primitive = {
        'schemaVersion': 1,
        'source': {'file': 'design/sources/grade_cores_pipeline_bucal.svg',
                   'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                   'note': 'Wine, rose and neutral scales extracted verbatim. Semantic hues and darkBase are derived additions.'},
        'colors': colors,
        'font': {'family': 'Inter', 'fallback': ['Arial', 'sans-serif']},
        'typography': {
            'display': {'size': 32, 'lineHeight': 40, 'weight': 600, 'letterSpacing': -0.8},
            'page': {'size': 28, 'lineHeight': 36, 'weight': 600, 'letterSpacing': -0.5},
            'section': {'size': 22, 'lineHeight': 30, 'weight': 600, 'letterSpacing': -0.3},
            'subtitle': {'size': 18, 'lineHeight': 26, 'weight': 600, 'letterSpacing': -0.1},
            'body': {'size': 16, 'lineHeight': 25, 'weight': 400, 'letterSpacing': 0},
            'bodySmall': {'size': 14, 'lineHeight': 22, 'weight': 400, 'letterSpacing': 0},
            'caption': {'size': 12, 'lineHeight': 18, 'weight': 500, 'letterSpacing': 0.15},
            'button': {'size': 15, 'lineHeight': 22, 'weight': 600, 'letterSpacing': 0},
            'eyebrow': {'size': 11, 'lineHeight': 16, 'weight': 600, 'letterSpacing': 1.2},
        },
        'spacing': {'none': 0, 'xxs': 4, 'xs': 8, 'sm': 12, 'md': 16, 'lg': 24, 'xl': 32, 'xxl': 40, 'huge': 48, 'section': 64},
        'radius': {'small': 8, 'input': 12, 'button': 16, 'card': 24, 'sheet': 32, 'pill': 999},
        'dimensions': {'minimumTouch': 48, 'buttonMinHeight': 52, 'fieldMinHeight': 56, 'navigationMinHeight': 64, 'contentMaxWidth': 640, 'pageGutter': 24, 'icon': 24, 'smallIcon': 20},
        'motion': {'instant': 0, 'fast': 120, 'standard': 220, 'slow': 320, 'curve': 'easeOutCubic', 'reducedMotion': 0},
        'elevation': {'flat': {'y': 0, 'blur': 0, 'opacity': 0}, 'card': {'y': 4, 'blur': 20, 'opacity': 0.04}, 'floating': {'y': 8, 'blur': 28, 'opacity': 0.12}, 'dialog': {'y': 16, 'blur': 48, 'opacity': 0.18}},
    }
    light = {
        'background': '{colors.rose.50}', 'surface': '{colors.white}', 'surfaceRaised': '{colors.white}',
        'surfaceSubtle': '{colors.neutral.50}', 'surfaceSelected': '{colors.wine.100}',
        'textPrimary': '{colors.neutral.900}', 'textSecondary': '{colors.neutral.600}', 'textMuted': '{colors.neutral.600}',
        'border': '{colors.neutral.200}', 'outline': '{colors.neutral.500}', 'divider': '{colors.neutral.200}',
        'primary': '{colors.wine.500}', 'onPrimary': '{colors.white}', 'primaryHover': '{colors.wine.600}', 'primaryPressed': '{colors.wine.700}',
        'secondary': '{colors.rose.200}', 'onSecondary': '{colors.wine.700}',
        'focus': '{colors.wine.600}', 'disabledSurface': '{colors.neutral.100}', 'disabledText': '{colors.neutral.500}',
        'navigation': '{colors.neutral.900}', 'onNavigation': '{colors.rose.50}', 'navigationSelected': '{colors.rose.200}', 'onNavigationSelected': '{colors.wine.900}',
        'successSurface': '{colors.sage.light}', 'success': '{colors.sage.ink}',
        'warningSurface': '{colors.amber.light}', 'warning': '{colors.amber.ink}',
        'errorSurface': '{colors.danger.light}', 'error': '{colors.danger.ink}',
        'infoSurface': '{colors.info.light}', 'info': '{colors.info.ink}',
    }
    dark = {
        'background': '{colors.darkBase}', 'surface': '{colors.neutral.900}', 'surfaceRaised': '{colors.neutral.800}',
        'surfaceSubtle': '{colors.neutral.800}', 'surfaceSelected': '{colors.wine.800}',
        'textPrimary': '{colors.neutral.50}', 'textSecondary': '{colors.neutral.300}', 'textMuted': '{colors.neutral.400}',
        'border': '{colors.neutral.700}', 'outline': '{colors.neutral.400}', 'divider': '{colors.neutral.700}',
        'primary': '{colors.rose.200}', 'onPrimary': '{colors.wine.900}', 'primaryHover': '{colors.rose.100}', 'primaryPressed': '{colors.rose.300}',
        'secondary': '{colors.wine.800}', 'onSecondary': '{colors.rose.200}',
        'focus': '{colors.rose.300}', 'disabledSurface': '{colors.neutral.800}', 'disabledText': '{colors.neutral.400}',
        'navigation': '{colors.neutral.900}', 'onNavigation': '{colors.neutral.100}', 'navigationSelected': '{colors.rose.200}', 'onNavigationSelected': '{colors.wine.900}',
        'successSurface': '{colors.sage.dark}', 'success': '{colors.sage.onDark}',
        'warningSurface': '{colors.amber.dark}', 'warning': '{colors.amber.onDark}',
        'errorSurface': '{colors.danger.dark}', 'error': '{colors.danger.onDark}',
        'infoSurface': '{colors.info.dark}', 'info': '{colors.info.onDark}',
    }
    semantic = {'schemaVersion': 1, 'light': light, 'dark': dark,
                'states': {'focusRingWidth': 3, 'selectedBorderWidth': 2, 'defaultBorderWidth': 1, 'hoverOpacity': 0.08, 'pressedOpacity': 0.12, 'disabledOpacity': 1},
                'risk': {'low': 'success', 'medium': 'warning', 'high': 'error'},
                'reducedMotion': 'Respect platform disableAnimations; replace transitions with zero duration.'}
    def resolve(value):
        if isinstance(value, str) and value.startswith('{'):
            node = primitive
            for part in value[1:-1].split('.'):
                node = node[part]
            return node
        return value
    resolved = {mode: {key: resolve(value) for key, value in semantic[mode].items()} for mode in ('light', 'dark')}
    return primitive, semantic, resolved


def luminance(color):
    rgb = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
    return sum(a * b for a, b in zip(linear, (.2126, .7152, .0722)))


def contrast(a, b):
    x, y = sorted((luminance(a), luminance(b)))
    return (y + .05) / (x + .05)


def verify(primitive, resolved):
    report = []
    for mode, colors in resolved.items():
        pairs = [('textPrimary', 'background'), ('textPrimary', 'surface'), ('textSecondary', 'surface'), ('textMuted', 'surface'),
                 ('onPrimary', 'primary'), ('onSecondary', 'secondary'), ('onNavigation', 'navigation'), ('onNavigationSelected', 'navigationSelected'),
                 ('success', 'successSurface'), ('warning', 'warningSurface'), ('error', 'errorSurface'), ('info', 'infoSurface')]
        for foreground, background in pairs:
            ratio = contrast(colors[foreground], colors[background])
            if ratio < 4.5:
                raise ValueError(f'{mode} {foreground}/{background}: {ratio:.2f} < 4.5')
            report.append({'mode': mode, 'foreground': foreground, 'background': background, 'ratio': round(ratio, 2), 'minimum': 4.5})
        for foreground in ('focus', 'outline'):
            ratio = contrast(colors[foreground], colors['surface'])
            if ratio < 3:
                raise ValueError(f'{mode} interactive outline contrast below 3')
            report.append({'mode': mode, 'foreground': foreground, 'background': 'surface', 'ratio': round(ratio, 2), 'minimum': 3})
    return report


def dart(primitive, resolved):
    lines = ["// GENERATED by design/tokens/generate_tokens.py. Edit the JSON source generator.", "import 'package:flutter/material.dart';", '', 'abstract final class BucalTokens {']
    for mode, values in resolved.items():
        lines += [f'  static const {mode} = <String, Color>{{']
        lines += [f"    '{key}': Color(0xFF{value[1:]})," for key, value in values.items()]
        lines += ['  };']
    lines += ["  static const fontFamily = 'Inter';"]
    for group in ('spacing', 'radius', 'dimensions', 'motion'):
        for key, value in primitive[group].items():
            if isinstance(value, (int, float)):
                name = group + key[0].upper() + key[1:]
                lines.append(f'  static const {name} = {float(value)};')
    lines += ['  static const typography = <String, Map<String, double>>{']
    for key, values in primitive['typography'].items():
        inner = ', '.join(f"'{k}': {float(v)}" for k, v in values.items())
        lines.append(f"    '{key}': {{{inner}}},")
    lines += ['  };', '}', '']
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=ROOT / 'design/sources/grade_cores_pipeline_bucal.svg')
    parser.add_argument('--check', action='store_true', help='Verify generated artifacts without writing')
    args = parser.parse_args()
    primitive, semantic, resolved = build(args.source)
    report = verify(primitive, resolved)
    files = {HERE / 'primitives.json': primitive, HERE / 'semantic.json': semantic, HERE / 'resolved.json': resolved, HERE / 'contrast_report.json': report}
    content = {path: json.dumps(value, ensure_ascii=False, indent=2) + '\n' for path, value in files.items()}
    content[ROOT / 'mobile/lib/design_system/tokens.g.dart'] = dart(primitive, resolved)
    for path, text in content.items():
        if args.check:
            if not path.exists() or path.read_text() != text:
                raise SystemExit(f'Generated artifact is stale: {path}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
    print(f'{len(report)} contrast pairs passed; 30 supplied palette colors verified; generated artifacts {"current" if args.check else "written"}.')


if __name__ == '__main__':
    main()
