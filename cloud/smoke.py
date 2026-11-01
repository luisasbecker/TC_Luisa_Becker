"""HTTPS test after deployment. Sends only a generated red/blue test image."""
import base64
import hashlib
import io
import json
import secrets
import sys
import urllib.request
from urllib.parse import urlparse
from PIL import Image

endpoint = sys.argv[1].rstrip('/')
parsed = urlparse(endpoint)
if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.query or parsed.fragment:
    raise SystemExit('Informe uma URL HTTPS válida.')
with urllib.request.urlopen(endpoint + '/v1/health', timeout=90) as response:
    health = json.load(response)
assert health == {'status': 'ok', 'api_version': '1', 'simulation_only': True}
session = secrets.token_hex(16)
original = Image.new('RGB', (80, 40), 'red')
original.paste('blue', (40, 0, 80, 40))
def encode(image):
    data = io.BytesIO()
    image.save(data, 'PNG')
    return data.getvalue()
def call(operation, raw, **extra):
    image_hash = hashlib.sha256(raw).hexdigest()
    body = {'session_id': session, 'image_base64': base64.b64encode(raw).decode(), 'image_hash': image_hash, **extra}
    request = urllib.request.Request(endpoint + '/v1/' + operation, json.dumps(body).encode(), {'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=90) as response:
        result = json.load(response)
    assert result['image_hash'] == image_hash and result['simulation_only'] is True
    assert result['data_stored'] is False and result['session_id'] == session
    return result

detection = call('detect', encode(original))
assert Image.open(io.BytesIO(base64.b64decode(detection['crop_base64']))).size == (64, 32)
corrected = encode(original.crop((40, 0, 80, 40)))
focus = call('focus', corrected, manual=True)
cnn = call('classify', corrected)
selected = (cnn['class_index'] + 1) % 6
questions = call('questionnaire', corrected, class_index=selected, suggested_class=cnn['class_index'])
answers = [q['options'][0] for q in questions['questions']]
result = call('multimodal', corrected, class_index=selected, answers=answers)
retry = call('multimodal', corrected, class_index=selected, answers=answers)
assert result == retry
assert result['risk_index'] in range(3)
assert [r['feedback'][0]['target'] for r in (focus, questions, result)] == ['YOLO', 'CNN', 'MNN']
print('PASS: HTTPS, recorte, foco, CNN, questionário, MNN, curadoria, retreinamento fantasma e nova tentativa estável.')
