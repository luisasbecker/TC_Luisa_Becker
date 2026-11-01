import base64
import hashlib
import io
import json
import unittest
from PIL import Image
from service import application, process, CLASSES, RISKS, MODELS, OPTIONS, InvalidRequest, MAX_BODY


def photo(color='blue', size=(80, 40)):
    output = io.BytesIO()
    Image.new('RGB', size, color).save(output, 'PNG')
    return output.getvalue()


def request(image=None, session='00000000000000000000000000000001', **extra):
    raw = photo() if image is None else image
    return {'session_id': session, 'image_base64': base64.b64encode(raw).decode(),
            'image_hash': hashlib.sha256(raw).hexdigest(), **extra}


class ServiceTests(unittest.TestCase):
    def test_crop_and_all_stages_receive_actual_corrected_image(self):
        original = photo('red')
        detection = process('detect', request(original))
        auto = base64.b64decode(detection['crop_base64'])
        self.assertEqual(Image.open(io.BytesIO(auto)).size, (64, 32))
        self.assertEqual(hashlib.sha256(auto).hexdigest(), detection['crop_hash'])
        corrected = photo('blue', (20, 30))
        focus = process('focus', request(corrected, manual=True))
        cnn = process('classify', request(corrected))
        selected = (cnn['class_index'] + 1) % 6
        questions = process('questionnaire', request(corrected, class_index=selected, suggested_class=cnn['class_index']))
        result = process('multimodal', request(corrected, class_index=selected, answers=[o[0] for o in OPTIONS]))
        for response in [focus, cnn, questions, result]:
            self.assertEqual(response['image_hash'], hashlib.sha256(corrected).hexdigest())
            self.assertNotEqual(response['image_hash'], hashlib.sha256(original).hexdigest())
            self.assertTrue(response['simulation_only'])
            self.assertFalse(response['data_stored'])
        self.assertEqual(result['module'], MODELS[selected])
        self.assertEqual([q['options'] for q in questions['questions']], OPTIONS)
        self.assertEqual([focus['feedback'][0]['target'], questions['feedback'][0]['target'], result['feedback'][0]['target']], ['YOLO', 'CNN', 'MNN'])

    def test_retry_is_identical_and_risk_has_no_clinical_dependence(self):
        payload = request(class_index=4, answers=[o[0] for o in OPTIONS])
        first = process('multimodal', payload)
        self.assertEqual(first, process('multimodal', payload))
        other = process('multimodal', request(photo('red'), class_index=1, answers=[o[-1] for o in OPTIONS]))
        self.assertEqual(first['risk_index'], other['risk_index'])

    def test_variety_classes_risks_and_curation(self):
        classes, risks, decisions = set(), set(), set()
        for i in range(150):
            session = f'{i:032x}'
            classes.add(process('classify', request(session=session))['class_index'])
            result = process('multimodal', request(session=session, class_index=i % 6, answers=[o[0] for o in OPTIONS]))
            risks.add(result['risk_index'])
            feedback = result['feedback'][0]
            decisions.add(feedback['approved_simulated'])
            self.assertFalse(feedback['retraining']['model_updated'])
        self.assertEqual(classes, set(range(len(CLASSES))))
        self.assertEqual(risks, set(range(len(RISKS))))
        self.assertEqual(decisions, {True, False})

    def test_all_six_multimodal_routes(self):
        for index, model in enumerate(MODELS):
            result = process('multimodal', request(class_index=index, answers=[o[-1] for o in OPTIONS]))
            self.assertEqual(result['module'], model)
            self.assertIn(result['risk_label'], RISKS)

    def test_corrupt_image_hash_session_and_answers_rejected(self):
        bad = [request(b'not an image'), request(image_hash='bad'), request(session='x')]
        for payload in bad:
            with self.assertRaises(InvalidRequest): process('classify', payload)
        for answers in [[], ['Sim'], [None]*3, ['inventado']*3]:
            with self.assertRaises(InvalidRequest):
                process('multimodal', request(class_index=0, answers=answers))
        with self.assertRaises(InvalidRequest):
            process('multimodal', request(class_index=True, answers=[o[0] for o in OPTIONS]))

    def test_http_boundary(self):
        def invoke(path, method='POST', body=None, size=None, content='application/json'):
            raw = json.dumps(request() if body is None else body).encode()
            status, headers = [], []
            output = application({'PATH_INFO': path, 'REQUEST_METHOD': method,
                'CONTENT_TYPE': content, 'CONTENT_LENGTH': str(len(raw) if size is None else size),
                'wsgi.input': io.BytesIO(raw)}, lambda s, h: (status.append(s), headers.extend(h)))
            return status[0], dict(headers), json.loads(b''.join(output))
        status, headers, response = invoke('/v1/classify')
        self.assertEqual(status, '200 OK')
        self.assertEqual(headers['Cache-Control'], 'no-store')
        self.assertEqual(response['execution_mode'], 'cloud')
        health_status, health_headers, health = invoke('/v1/health', 'GET')
        self.assertEqual(health_status, '200 OK')
        self.assertEqual(health['status'], 'ok')
        self.assertTrue(health['simulation_only'])
        self.assertEqual(health_headers['Cache-Control'], 'no-store')
        self.assertTrue(invoke('/unknown')[0].startswith('404'))
        self.assertTrue(invoke('/v1/classify', size=MAX_BODY+1)[0].startswith('413'))
        self.assertTrue(invoke('/v1/classify', content='text/plain')[0].startswith('415'))
        self.assertTrue(invoke('/v1/classify', body=[])[0].startswith('400'))

if __name__ == '__main__':
    unittest.main()
