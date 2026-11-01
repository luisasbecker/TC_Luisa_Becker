"""Public WSGI contract tests. Fixtures use synthetic pixels only."""
import base64
import hashlib
import io
import json
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch
from urllib.parse import urlparse

from PIL import Image
from service import application, process as process_v1, choice as choice_v1, MAX_BODY
from api_v2 import QUESTIONNAIRES
from multimodal_v2 import MULTIMODAL_MODELS, ghost_choice


def photo(color='blue', size=(80, 40)):
    output = io.BytesIO()
    Image.new('RGB', size, color).save(output, format='PNG')
    return output.getvalue()


def envelope(raw=None, **overrides):
    raw = photo() if raw is None else raw
    return {
        'analysis_id': '00000000000000000000000000000001',
        'image_id': '10000000000000000000000000000001',
        'request_id': '20000000000000000000000000000001',
        'crop_revision': 1, 'decision_revision': 1, 'answers_revision': 1,
        'image_hash': hashlib.sha256(raw).hexdigest(),
        'image_base64': base64.b64encode(raw).decode(), **overrides,
    }


def invoke(operation, payload=None, version='2', method='POST', size=None, content='application/json'):
    raw = json.dumps(envelope() if payload is None else payload).encode()
    statuses, headers = [], []
    output = application({
        'PATH_INFO': f'/v{version}/{operation}', 'REQUEST_METHOD': method,
        'CONTENT_TYPE': content, 'CONTENT_LENGTH': str(len(raw) if size is None else size),
        'wsgi.input': io.BytesIO(raw),
    }, lambda status, response_headers: (statuses.append(status), headers.extend(response_headers)))
    return statuses[0], dict(headers), json.loads(b''.join(output))


class V2Tests(unittest.TestCase):
    def call(self, operation, payload=None):
        status, headers, response = invoke(operation, payload)
        self.assertEqual(status, '200 OK', response)
        self.assertEqual(headers['Cache-Control'], 'no-store')
        self.assertTrue(response['simulation_only'])
        self.assertFalse(response['data_stored'])
        return response

    def test_v2_health_and_identity_echo(self):
        status, _, health = invoke('health', method='GET')
        self.assertEqual(status, '200 OK')
        self.assertEqual(health['api_version'], '2')
        request = envelope()
        response = self.call('classify', request)
        for key in ('analysis_id', 'image_id', 'request_id', 'crop_revision',
                    'decision_revision', 'answers_revision', 'image_hash'):
            self.assertEqual(response[key], request[key])
        self.assertEqual(response['operation'], 'classify')

    def test_v1_public_contract_still_matches_original_process(self):
        # Frozen legacy fixtures guard the ghost-v1 stream across new API versions.
        for value, cnn, risk, focus in ((1, 5, 1, 0), (2, 0, 2, 0), (3, 4, 2, 0), (42, 1, 1, 1)):
            session = f'{value:032x}'
            self.assertEqual((choice_v1(session, 'cnn', 6), choice_v1(session, 'risk', 3),
                              choice_v1(session, 'focus', 2)), (cnn, risk, focus))
        raw = photo()
        request = {'session_id': '00000000000000000000000000000001',
                   'image_base64': base64.b64encode(raw).decode(),
                   'image_hash': hashlib.sha256(raw).hexdigest()}
        for operation in ('detect', 'focus', 'classify'):
            with self.subTest(operation=operation):
                expected = process_v1(operation, request)
                status, _, actual = invoke(operation, request, version='1')
                self.assertEqual(status, '200 OK')
                self.assertEqual(actual, expected)
                self.assertEqual(actual['api_version'], '1')
        self.assertTrue(process_v1('detect', request)['detected'])
        selected = process_v1('classify', request)['class_index']
        request.update(class_index=selected, suggested_class=selected,
                       answers=['Não informado', 'Sim', 'Não'])
        for operation in ('questionnaire', 'multimodal'):
            status, _, actual = invoke(operation, request, version='1')
            self.assertEqual(status, '200 OK')
            self.assertEqual(actual, process_v1(operation, request))
        self.assertIn('de câncer', actual['risk_label'])

    def final_payload(self, raw=None, analysis=None, selected=None, uncertain=False):
        body = envelope(raw)
        if analysis is not None:
            body['analysis_id'] = analysis
        suggested = self.call('classify', body)['class_index']
        selected = suggested if selected is None else selected
        decision = {
            'status': 'uncertain' if uncertain else 'confirmed' if selected == suggested else 'corrected',
            'suggested_class': suggested, 'selected_class': None if uncertain else selected,
        }
        questions = self.call('questionnaire', {**body, 'decision': decision})
        body.update(
            decision=decision, questionnaire_id=questions['questionnaire_id'],
            questionnaire_version=questions['questionnaire_version'],
            answers={question['id']: question['options'][0]
                     for section in questions['sections'] for question in section['questions']},
        )
        return body, questions

    def test_original_and_corrected_pixels_follow_all_operations(self):
        # Choose a normal random-identity branch in the fixture, never via API override.
        analysis = next(f'{i:032x}' for i in range(100) if ghost_choice(f'{i:032x}', 'detect', 8) != 0)
        original = photo('red')
        detection = self.call('detect', envelope(original, analysis_id=analysis, crop_revision=0))
        automatic = base64.b64decode(detection['crop_base64'])
        self.assertEqual(Image.open(io.BytesIO(automatic)).size, (64, 32))
        self.assertEqual(hashlib.sha256(automatic).hexdigest(), detection['crop_hash'])
        corrected = photo('blue', (20, 30))
        focus = self.call('focus', envelope(corrected, analysis_id=analysis, manual=True,
                          box={'left': .5, 'top': 0, 'right': 1, 'bottom': 1}))
        final_body, questions = self.final_payload(corrected, analysis, selected=5)
        result = self.call('multimodal', final_body)
        expected_hash = hashlib.sha256(corrected).hexdigest()
        for response in (focus, questions, result):
            self.assertEqual(response['image_hash'], expected_hash)
            self.assertNotEqual(response['image_hash'], detection['image_hash'])
            self.assertEqual(response['analysis_id'], analysis)
        self.assertEqual(focus['feedback'][0]['target'], 'YOLO')

    def test_detection_failure_allows_manual_crop_but_never_implicit_roi(self):
        analysis = next(f'{i:032x}' for i in range(100) if ghost_choice(f'{i:032x}', 'detect', 8) == 0)
        request = envelope(analysis_id=analysis, crop_revision=0)
        detection = self.call('detect', request)
        self.assertFalse(detection['detected'])
        self.assertEqual(detection['detection_status'], 'not_found')
        self.assertIsNone(detection['box'])
        self.assertIsNone(detection['crop_base64'])
        self.assertEqual(detection['feedback'][0]['reason'], 'detection_failed')
        self.assertTrue(invoke('classify', request)[0].startswith('400'))
        manual = {**request, 'crop_revision': 1, 'manual': True,
                  'box': {'left': 0, 'top': 0, 'right': 1, 'bottom': 1}}
        self.assertEqual(self.call('focus', manual)['module'], 'FocusEvaluationStub')
        self.assertIn(self.call('classify', {**request, 'crop_revision': 1})['class_index'], range(6))

    def test_all_six_forms_route_to_separate_multimodal_components(self):
        self.assertEqual(len({type(model) for model in MULTIMODAL_MODELS}), 6)
        all_ids = set()
        for index in range(6):
            with self.subTest(class_index=index):
                body, form = self.final_payload(selected=index)
                result = self.call('multimodal', body)
                self.assertEqual(form['class_index'], index)
                self.assertEqual(form['questionnaire_id'], f'lesion-{index}-demo')
                self.assertEqual(result['module'], type(MULTIMODAL_MODELS[index]).__name__)
                self.assertEqual(result['class_index'], index)
                self.assertEqual(result['effective_class'], index)
                self.assertTrue(result['class_confirmed'])
                self.assertFalse(result['provisional'])
                ids = {question['id'] for section in form['sections'] for question in section['questions']}
                self.assertEqual(len(ids), 3)
                self.assertTrue(all_ids.isdisjoint(ids))
                all_ids.update(ids)

    def test_uncertainty_continues_without_becoming_confirmation(self):
        body, form = self.final_payload(uncertain=True)
        result = self.call('multimodal', body)
        for response in (form, result):
            self.assertTrue(response['provisional'])
            self.assertFalse(response['class_confirmed'])
            self.assertEqual(response['decision']['status'], 'uncertain')
            self.assertIsNone(response['decision']['selected_class'])
            self.assertEqual(response['class_index'], body['decision']['suggested_class'])
            self.assertEqual(response['decision_policy'], 'use_suggested_provisionally_v1')
        self.assertEqual(form['feedback'][0]['reason'], 'class_uncertain')
        self.assertIn('não foi confirmada', result['provisional_notice'])
        self.assertFalse(form['feedback'][0]['clinical_validation'])

    def test_class_change_rejects_old_form_and_incompatible_answers(self):
        body, _ = self.final_payload()
        changed = (body['decision']['suggested_class'] + 1) % 6
        body['decision'] = {**body['decision'], 'status': 'corrected', 'selected_class': changed}
        body['decision_revision'] += 1
        self.assertTrue(invoke('multimodal', body)[0].startswith('400'))
        body['questionnaire_id'] = f'lesion-{changed}-demo'
        self.assertTrue(invoke('multimodal', body)[0].startswith('400'))
        body['answers'] = {q['id']: q['options'][0] for s in QUESTIONNAIRES[changed]['sections'] for q in s['questions']}
        body['answers_revision'] += 1
        self.assertEqual(self.call('multimodal', body)['effective_class'], changed)

    def test_new_image_and_revision_identity_are_not_silently_reused(self):
        first = envelope()
        second = envelope(photo('red'), image_id='10000000000000000000000000000002',
                          request_id='20000000000000000000000000000002', crop_revision=2)
        previous = self.call('classify', first)
        current = self.call('classify', second)
        self.assertEqual(previous['analysis_id'], current['analysis_id'])
        for key in ('image_id', 'request_id', 'image_hash', 'crop_revision'):
            self.assertNotEqual(previous[key], current[key])
        # Server echoes request identity; client must discard late previous replies.
        self.assertEqual(current['image_id'], second['image_id'])

    def test_retry_and_risk_are_independent_of_clinical_inputs(self):
        body, _ = self.final_payload()
        first = self.call('multimodal', body)
        self.assertEqual(first, self.call('multimodal', body))
        other, _ = self.final_payload(photo('red'), selected=(first['class_index'] + 1) % 6)
        other['answers'] = {key: 'Não informado' for key in other['answers']}
        other['answers_revision'] += 1
        self.assertEqual(first['risk'], self.call('multimodal', other)['risk'])

    def test_all_risks_classes_and_detection_branches_without_overrides(self):
        classes, risks, detections = set(), set(), set()
        for i in range(80):
            analysis = f'{i:032x}'
            body, _ = self.final_payload(analysis=analysis)
            result = self.call('multimodal', body)
            classes.add(result['class_index'])
            risks.add(result['risk'])
            detections.add(self.call('detect', envelope(analysis_id=analysis))['detected'])
            self.assertNotIn('%', result['risk_label'] + result['message'])
            self.assertIn('avaliação médica', result['message'])
            self.assertIn('não é diagnóstico', result['disclaimer'])
            self.assertTrue(result['text_review_pending'])
        self.assertEqual(classes, set(range(6)))
        self.assertEqual(risks, {'low', 'medium', 'high'})
        self.assertEqual(detections, {False, True})

    def test_feedback_is_explicit_stable_acknowledgement_without_pixels(self):
        request = envelope()
        request.pop('image_base64')
        request['event'] = {'event_id': '30000000000000000000000000000001',
                            'type': 'class_uncertain',
                            'details': {'stage': 'classification', 'provisional': True, 'class_confirmed': False}}
        result = self.call('feedback', request)
        self.assertTrue(result['received'])
        self.assertEqual(result['event_id'], request['event']['event_id'])
        self.assertEqual(result['status'], 'simulated_acknowledged')
        self.assertEqual(result, self.call('feedback', request))
        self.assertFalse(result['feedback'][0]['retraining']['model_updated'])
        self.assertFalse(result['feedback'][0]['data_stored'])
        request['event']['details']['patient_name'] = 'not allowed'
        self.assertTrue(invoke('feedback', request)[0].startswith('400'))

    def test_invalid_inputs_revisions_and_forced_results_are_rejected(self):
        for override in ({'analysis_id': 'x'}, {'image_id': None}, {'request_id': False},
                         {'crop_revision': True}, {'crop_revision': -1}, {'crop_revision': 0},
                         {'image_hash': '0' * 64}, {'image_base64': 'not-image'},
                         {'scenario': 'high-risk'}, {'risk_index': 2}, {'seed': 1}):
            with self.subTest(override=override):
                self.assertTrue(invoke('classify', envelope(**override))[0].startswith('400'))
        body, _ = self.final_payload()
        for override in ({'answers_revision': 0}, {'decision_revision': 0},
                         {'questionnaire_version': True}, {'answers': {}},
                         {'answers': {key: 'inventado' for key in body['answers']}}):
            self.assertTrue(invoke('multimodal', {**body, **override})[0].startswith('400'))
        for decision in (
            {**body['decision'], 'status': 'uncertain'},
            {**body['decision'], 'status': 'corrected'},
            {**body['decision'], 'suggested_class': (body['decision']['suggested_class'] + 1) % 6},
        ):
            self.assertTrue(invoke('multimodal', {**body, 'decision': decision})[0].startswith('400'))

    def test_feedback_accepts_bounded_crop_metadata_without_clinical_validation(self):
        request = envelope()
        request.pop('image_base64')
        request['event'] = {'event_id': '30000000000000000000000000000002',
                            'type': 'manual_crop', 'details': {
                                'box': {'left': .2, 'top': .1, 'right': .7, 'bottom': .9},
                                'candidate_for_review': True,
                            }}
        result = self.call('feedback', request)
        self.assertFalse(result['feedback'][0]['clinical_validation'])
        request['event']['details']['box']['right'] = 2
        self.assertTrue(invoke('feedback', request)[0].startswith('400'))
        request['event']['details']['box']['right'] = .7
        request['event']['details']['candidate_for_review'] = 1
        self.assertTrue(invoke('feedback', request)[0].startswith('400'))

    def test_v2_http_limits_and_content_type(self):
        self.assertTrue(invoke('classify', size=MAX_BODY + 1)[0].startswith('413'))
        self.assertTrue(invoke('classify', size='invalid')[0].startswith('413'))
        self.assertTrue(invoke('classify', content='text/plain')[0].startswith('415'))
        self.assertTrue(invoke('unknown')[0].startswith('404'))
        self.assertTrue(invoke('classify', method='PUT')[0].startswith('404'))

    def test_smoke_driver_matches_wsgi_without_external_network(self):
        import smoke_v2
        calls = []

        def local_urlopen(request, timeout):
            url = request if isinstance(request, str) else request.full_url
            path = urlparse(url).path
            method = 'GET' if isinstance(request, str) else request.get_method()
            raw = b'' if isinstance(request, str) else request.data
            statuses = []
            output = application({
                'PATH_INFO': path, 'REQUEST_METHOD': method,
                'CONTENT_TYPE': 'application/json', 'CONTENT_LENGTH': str(len(raw)),
                'wsgi.input': io.BytesIO(raw),
            }, lambda status, headers: statuses.append(status))
            body = b''.join(output)
            self.assertEqual(statuses, ['200 OK'], body)
            calls.append(path)
            return io.BytesIO(body)

        output = io.StringIO()
        with patch('smoke_v2.urllib.request.urlopen', side_effect=local_urlopen), redirect_stdout(output):
            smoke_v2.main('https://synthetic-test.invalid')
        self.assertEqual(len(calls), 19)
        self.assertEqual(calls.count('/v2/detect'), 3)
        self.assertIn('/v2/feedback', calls)
        self.assertIn('PASS: v1/v2 health', output.getvalue())


if __name__ == '__main__':
    unittest.main()
