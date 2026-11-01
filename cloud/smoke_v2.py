"""Opt-in HTTPS v2 verification after deployment; synthetic pixels only.

The fixture selects analysis identities to cover all risk branches. The public API
does not accept scenario/seed/forced-result parameters and the normal app does not
use this selection policy. No deployment or billing changes are performed here.
"""
import base64
import hashlib
import io
import json
import secrets
import sys
import urllib.request
from urllib.parse import urlparse

from PIL import Image
from multimodal_v2 import ghost_choice


def encode(image):
    output = io.BytesIO()
    image.save(output, format='PNG')
    return output.getvalue()


def fixture_analysis(risk, detected):
    for _ in range(4096):
        identity = secrets.token_hex(16)
        if ghost_choice(identity, 'risk', 3) == risk and (ghost_choice(identity, 'detect', 8) != 0) == detected:
            return identity
    raise AssertionError('Não foi possível preparar as sessões de teste.')


def main(endpoint):
    endpoint = endpoint.rstrip('/')
    parsed = urlparse(endpoint)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.query or parsed.fragment:
        raise SystemExit('Informe uma URL HTTPS válida.')
    for version in ('1', '2'):
        with urllib.request.urlopen(f'{endpoint}/v{version}/health', timeout=90) as response:
            assert json.load(response) == {'status': 'ok', 'api_version': version, 'simulation_only': True}

    def call(operation, data):
        request = urllib.request.Request(
            f'{endpoint}/v2/{operation}', json.dumps(data).encode(),
            {'Content-Type': 'application/json'},
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            result = json.load(response)
        assert result['api_version'] == '2' and result['operation'] == operation
        assert result['simulation_only'] is True and result['data_stored'] is False
        for key in ('analysis_id', 'image_id', 'request_id', 'crop_revision',
                    'decision_revision', 'answers_revision', 'image_hash'):
            assert result[key] == data[key], key
        return result

    pixels = Image.new('RGB', (80, 40), 'red')
    pixels.paste('blue', (40, 0, 80, 40))
    original = encode(pixels)
    corrected = encode(pixels.crop((40, 0, 80, 40)))
    observed = []
    for expected in range(3):
        analysis = fixture_analysis(expected, detected=expected != 0)
        identity = {'analysis_id': analysis, 'image_id': secrets.token_hex(16),
                    'crop_revision': 0, 'decision_revision': 0, 'answers_revision': 0}

        def payload(raw, **extra):
            return {**identity, 'request_id': secrets.token_hex(16),
                    'image_hash': hashlib.sha256(raw).hexdigest(),
                    'image_base64': base64.b64encode(raw).decode(), **extra}

        detection = call('detect', payload(original))
        assert detection['detected'] == (expected != 0)
        if detection['detected']:
            auto = base64.b64decode(detection['crop_base64'])
            assert Image.open(io.BytesIO(auto)).size == (64, 32)
            assert hashlib.sha256(auto).hexdigest() == detection['crop_hash']
        else:
            assert detection['box'] is None and detection['crop_base64'] is None
        identity['crop_revision'] = 1
        focus = call('focus', payload(corrected, manual=True,
                     box={'left': .5, 'top': 0, 'right': 1, 'bottom': 1}))
        assert focus['feedback'][0]['target'] == 'YOLO'
        cnn = call('classify', payload(corrected))
        suggested = cnn['class_index']
        decision = {
            'status': ('uncertain', 'corrected', 'confirmed')[expected],
            'suggested_class': suggested,
            'selected_class': None if expected == 0 else (suggested + 1) % 6 if expected == 1 else suggested,
        }
        identity['decision_revision'] = 1
        questions = call('questionnaire', payload(corrected, decision=decision))
        assert questions['provisional'] == (expected == 0)
        assert questions['class_confirmed'] == (expected != 0)
        identity['answers_revision'] = 1
        answers = {q['id']: 'Não informado' for s in questions['sections'] for q in s['questions']}
        final_request = payload(corrected, decision=decision,
                                questionnaire_id=questions['questionnaire_id'],
                                questionnaire_version=questions['questionnaire_version'], answers=answers)
        result = call('multimodal', final_request)
        assert result['risk_index'] == expected
        assert result['risk'] == ('low', 'medium', 'high')[expected]
        assert result['image_hash'] == hashlib.sha256(corrected).hexdigest()
        assert result['class_index'] == questions['effective_class']
        if expected == 0:
            assert result['provisional_notice'] and not result['class_confirmed']
            event_request = payload(corrected)
            event_request.pop('image_base64')
            event_request['event'] = {
                'event_id': secrets.token_hex(16), 'type': 'class_uncertain',
                'details': {'provisional': True, 'class_confirmed': False},
            }
            receipt = call('feedback', event_request)
            assert receipt['received'] is True
            assert receipt['event_id'] == event_request['event']['event_id']
        if expected == 2:
            assert call('multimodal', final_request) == result
        observed.append(result['risk'])
        print(f"PASS v2: {result['risk_label']}; decision={decision['status']}; corrected_crop=verified")
    assert observed == ['low', 'medium', 'high']
    print('PASS: v1/v2 health, cinco etapas HTTPS, sem detecção, recorte manual, três decisões, três riscos, feedback e retry.')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Uso: python3 cloud/smoke_v2.py https://URL_DO_SERVICO')
    main(sys.argv[1])
