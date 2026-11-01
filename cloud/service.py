"""Stateless academic simulation. Images live only for the duration of a request."""
import base64
import hashlib
import io
import json
import re
import warnings
from PIL import Image, ImageOps, UnidentifiedImageError

VERSION = '1'
MAX_BODY = 18 * 1024 * 1024
MAX_IMAGE = 12 * 1024 * 1024
Image.MAX_IMAGE_PIXELS = 8_000_000
CLASSES = ['pápula/nódulo', 'mácula/mancha', 'vesícula/bolha', 'erosão', 'úlcera', 'placa']
RISKS = ['risco baixo de câncer', 'risco médio de câncer', 'risco alto de câncer']
MODELS = ['PapuleNoduleMultimodalStub', 'MaculeSpotMultimodalStub', 'VesicleBullaMultimodalStub', 'ErosionMultimodalStub', 'UlcerMultimodalStub', 'PlaqueMultimodalStub']
OPTIONS = [['Menos de 2 semanas', 'Entre 2 e 4 semanas', 'Mais de 4 semanas', 'Não informado'], ['Não', 'Sim', 'Não informado'], ['Não', 'Sim', 'Não informado']]
QUESTION_IDS = ['tempo_evolucao', 'sintomas', 'mudanca_recente']
GUIDANCE = 'Resultado simulado, sem diagnóstico. Busque avaliação médica adequada. Este sistema não substitui avaliação profissional nem exames complementares quando indicados.'

class InvalidRequest(Exception):
    pass


def choice(session, module, count):
    # Session IDs contain random entropy from the client. Independent streams for
    # CNN and risk; no image/answer/clinical association. No process-local state.
    digest = hashlib.sha256(f'ghost-v{VERSION}:{session}:{module}'.encode()).digest()
    return int.from_bytes(digest, 'big') % count


def class_index(data, field='class_index'):
    value = data.get(field)
    if type(value) is not int or not 0 <= value < len(CLASSES):
        raise InvalidRequest('Classe inválida.')
    return value


def decode_image(data):
    value = data.get('image_base64')
    if not isinstance(value, str) or len(value) > ((MAX_IMAGE + 2) // 3) * 4:
        raise InvalidRequest('Imagem ausente ou muito grande.')
    try:
        raw = base64.b64decode(value, validate=True)
        if not raw or len(raw) > MAX_IMAGE:
            raise InvalidRequest('Imagem ausente ou muito grande.')
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            source = Image.open(io.BytesIO(raw))
            if source.format not in ('PNG', 'JPEG'):
                raise InvalidRequest('Use uma imagem PNG ou JPEG.')
            if source.width * source.height > Image.MAX_IMAGE_PIXELS:
                raise InvalidRequest('Resolução da imagem excede o limite.')
            source.load()
            pixels = ImageOps.exif_transpose(source).convert('RGB')
        return raw, pixels
    except (ValueError, OSError, UnidentifiedImageError, Image.DecompressionBombError, Image.DecompressionBombWarning) as error:
        raise InvalidRequest('Não foi possível abrir a imagem.') from error


def curation(session, image_hash, target, reason):
    # Both branches are exercised. This is an acknowledgement, never training.
    approved = choice(session, f'curation:{target}:{image_hash}', 2) == 1
    return {
        'module': 'IntelligentSystemStub', 'target': target, 'reason': reason,
        'image_hash': image_hash, 'approved_simulated': approved,
        'retraining': {
            'module': f'{target}RetrainingStub',
            'status': 'simulated_acknowledged' if approved else 'not_forwarded',
            'model_updated': False, 'data_stored': False,
        },
    }


def process(operation, data):
    if not isinstance(data, dict):
        raise InvalidRequest('Requisição inválida.')
    session = data.get('session_id')
    if not isinstance(session, str) or not re.fullmatch(r'[A-Za-z0-9_-]{16,80}', session):
        raise InvalidRequest('Sessão inválida.')
    if operation not in ('detect', 'focus', 'classify', 'questionnaire', 'multimodal'):
        raise InvalidRequest('Etapa inválida.')
    raw, pixels = decode_image(data)
    image_hash = hashlib.sha256(raw).hexdigest()
    if data.get('image_hash') != image_hash:
        raise InvalidRequest('A imagem recebida não corresponde à imagem confirmada.')
    result = {'api_version': VERSION, 'simulation_only': True, 'execution_mode': 'cloud',
              'session_id': session, 'operation': operation, 'image_hash': image_hash,
              'feedback': [], 'data_stored': False}
    if operation == 'detect':
        # A central ROI is illustrative, not inferred from the photo.
        box = {'left': .1, 'top': .1, 'right': .9, 'bottom': .9}
        import math
        crop = pixels.crop((math.floor(pixels.width * .1), math.floor(pixels.height * .1),
                            math.ceil(pixels.width * .9), math.ceil(pixels.height * .9)))
        output = io.BytesIO()
        crop.save(output, format='PNG')
        cropped = output.getvalue()
        result.update(module='YoloDetectionStub', detected=True, box=box,
                      crop_base64=base64.b64encode(cropped).decode(),
                      crop_hash=hashlib.sha256(cropped).hexdigest())
    elif operation == 'focus':
        manual = data.get('manual', False)
        if type(manual) is not bool:
            raise InvalidRequest('Indicador de recorte inválido.')
        result.update(module='FocusEvaluationStub', adequate=choice(session, 'focus', 2) == 1,
                      user_decides=True)
        if manual:
            result['feedback'].append(curation(session, image_hash, 'YOLO', 'manual_crop'))
    elif operation == 'classify':
        index = choice(session, 'cnn', len(CLASSES))
        result.update(module='CnnClassificationStub', class_index=index, class_label=CLASSES[index])
    elif operation == 'questionnaire':
        index = class_index(data)
        suggested = class_index(data, 'suggested_class')
        if suggested != choice(session, 'cnn', len(CLASSES)):
            raise InvalidRequest('Classe sugerida não corresponde à sessão.')
        label = CLASSES[index]
        prompts = [f'Há quanto tempo a alteração semelhante a {label} foi percebida?',
                   f'Há sintomas associados à alteração semelhante a {label}?',
                   f'Foi percebida mudança recente na alteração semelhante a {label}?']
        result.update(module='QuestionnaireStub', class_index=index,
                      questions=[{'id': name, 'prompt': prompt, 'options': options}
                                 for name, prompt, options in zip(QUESTION_IDS, prompts, OPTIONS)])
        if index != suggested:
            result['feedback'].append(curation(session, image_hash, 'CNN', 'corrected_class'))
    else:
        index = class_index(data)
        answers = data.get('answers')
        if not isinstance(answers, list) or len(answers) != 3 or any(a not in OPTIONS[i] for i, a in enumerate(answers)):
            raise InvalidRequest('Responda todas as perguntas antes de continuar.')
        risk = choice(session, 'risk', len(RISKS))
        result.update(module=MODELS[index], class_index=index, risk_index=risk,
                      risk_label=RISKS[risk], message=GUIDANCE)
        result['feedback'].append(curation(session, image_hash, 'MNN', 'multimodal_result'))
    return result


def application(environ, start_response):
    """Minimal WSGI boundary: bounded JSON; no files, logs of payloads or database."""
    status = '200 OK'
    try:
        path, method = environ.get('PATH_INFO', ''), environ.get('REQUEST_METHOD', '')
        if path == '/v2/health' and method == 'GET':
            payload = {'status': 'ok', 'api_version': '2', 'simulation_only': True}
        elif path in {f'/v2/{op}' for op in ('detect', 'focus', 'classify', 'questionnaire', 'multimodal', 'feedback')} and method == 'POST':
            # Keep v1 processing and its ghost-v1 choice stream unchanged.
            from api_v2 import process as process_v2
            try:
                size = int(environ.get('CONTENT_LENGTH') or '0')
            except ValueError:
                size = 0
            if not 0 < size <= MAX_BODY:
                status, payload = '413 Payload Too Large', {'error': 'Imagem muito grande para envio.'}
            elif environ.get('CONTENT_TYPE', '').split(';')[0].strip().lower() != 'application/json':
                status, payload = '415 Unsupported Media Type', {'error': 'Envie JSON.'}
            else:
                payload = process_v2(path.rsplit('/', 1)[1], json.loads(environ['wsgi.input'].read(size)))
        elif path == '/v1/health' and method == 'GET':
            payload = {'status': 'ok', 'api_version': VERSION, 'simulation_only': True}
        elif path in {f'/v1/{op}' for op in ('detect', 'focus', 'classify', 'questionnaire', 'multimodal')} and method == 'POST':
            try:
                size = int(environ.get('CONTENT_LENGTH') or '0')
            except ValueError:
                size = 0
            if not 0 < size <= MAX_BODY:
                status, payload = '413 Payload Too Large', {'error': 'Imagem muito grande para envio.'}
            elif environ.get('CONTENT_TYPE', '').split(';')[0].strip().lower() != 'application/json':
                status, payload = '415 Unsupported Media Type', {'error': 'Envie JSON.'}
            else:
                payload = process(path.rsplit('/', 1)[1], json.loads(environ['wsgi.input'].read(size)))
        else:
            status, payload = '404 Not Found', {'error': 'Rota não encontrada.'}
    except (InvalidRequest, ValueError, UnicodeError) as error:
        status, payload = '400 Bad Request', {'error': str(error) if isinstance(error, InvalidRequest) else 'JSON inválido.'}
    except Exception:
        # Never echo image bytes, answers or internal error details.
        status, payload = '500 Internal Server Error', {'error': 'Falha temporária. Tente novamente.'}
    body = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode()
    start_response(status, [('Content-Type', 'application/json; charset=utf-8'),
                            ('Content-Length', str(len(body))), ('Cache-Control', 'no-store'),
                            ('X-Content-Type-Options', 'nosniff')])
    return [body]
