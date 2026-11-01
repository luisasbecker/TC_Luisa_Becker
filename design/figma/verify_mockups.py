#!/usr/bin/env python3
"""Verify editable assets, routing and semantic content, not clinical quality."""
import base64
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
NS={'s':'http://www.w3.org/2000/svg'}
inventory=json.loads((HERE/'inventory.json').read_text())
records=inventory['screens']
assert len(records)==72
assert len(inventory['scenarios'])==15
assert len({s['id'] for s in inventory['scenarios']})==15
ids={s['id'] for s in records}
allowed_hashes={a['sha256'] for a in json.loads((ROOT/'design/reference_library/manifest.json').read_text())['assets']}
allowed_hashes.add(hashlib.sha256((ROOT/'design/branding/app_icon.png').read_bytes()).hexdigest())
allowed_hashes.add(hashlib.sha256((ROOT/'mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png').read_bytes()).hexdigest())
counts={'screens':len(records),'support_boards':0,'editable_text_nodes':0,'vector_nodes':0,'linked_actions':0,'source_preserved_images':0,'deterministic_scenarios':15}
for record in records:
    root=ET.fromstring((HERE/record['path']).read_bytes())
    text_nodes=root.findall('.//s:text',NS)
    texts=' '.join(t.text or '' for t in text_nodes)
    assert len(text_nodes)>=10,record['path']
    counts['editable_text_nodes']+=len(text_nodes)
    counts['vector_nodes']+=sum(1 for e in root.iter() if e.tag.rsplit('}',1)[-1] in ['rect','path','circle','line'])
    for text in text_nodes:
        assert 0<=float(text.attrib['x'])<390,(record['path'],text.text)
        assert 0<=float(text.attrib['y'])<=844,(record['path'],text.text)
    for image in root.findall('.//s:image',NS):
        data=image.attrib['href'].split(',',1)[1]
        assert hashlib.sha256(base64.b64decode(data)).hexdigest() in allowed_hashes,record['path']
        counts['source_preserved_images']+=1
    for link in record['links']:
        counts['linked_actions']+=1
        assert link['target'] in ids or link['target'].startswith('@'),link
        x,y,w,h=link['bounds']
        assert w>=48 and h>=48,(record['path'],link)
        assert 0<=x and 0<=y and x+w<=390 and y+h<=844,(record['path'],link)
    if record['id'] in ['22-low','23-medium','24-high','25-unconfirmed']:
        assert '%' not in texts,record['path']
        assert 'avaliação médica' in texts,record['path']
        assert 'diagnóstico' in texts,record['path']
        assert 'SIMULADO' in texts and 'demonstrativo' in texts,record['path']
    if record['id']=='25-unconfirmed':
        assert 'não foi confirmada' in texts,record['path']
for theme in ['light','dark']:
    for name in ['00-foundations','00-components','00-user-flows']:
        ET.fromstring((HERE/'svg'/theme/(name+'.svg')).read_bytes())
        counts['support_boards']+=1
for scenario in inventory['scenarios']:
    assert all(scenario[k] in ids for k in ['start','detect','focus','result'])
light={s['id']:s for s in records if s['theme']=='light'}
dark={s['id']:s for s in records if s['theme']=='dark'}
assert light.keys()==dark.keys()
for key in light:
    assert light[key]['links']==dark[key]['links'],key
html=(HERE/'prototype.html').read_text()
assert '/*__SCREENS__*/' not in html
assert 'Math.random' not in html
assert 'fetch(' not in html and 'XMLHttpRequest' not in html
assert 'prefers-reduced-motion' in html
assert 'class_uncertain' in html and 'class_corrected' in html
report={'status':'passed','kind':'automated_mockup_asset_checks','human_ux_study':False,**counts,'broken_navigation_targets':0,'native_figma_components_created':False,'external_network_calls':0}
(HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
