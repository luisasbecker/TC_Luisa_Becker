"""Stateless v2 contracts. v1 callers keep the original implementation unchanged.

Revision echoes let the client reject stale responses. They are not a server-side
session database and must not be described as verification of previous requests.
"""
import base64
import copy
import hashlib
import io
import json
import math
import re

from service import CLASSES, InvalidRequest, decode_image
from multimodal_v2 import MULTIMODAL_MODELS, ghost_choice


VERSION = '2'
OPERATIONS = ('detect', 'focus', 'classify', 'questionnaire', 'multimodal', 'feedback')
IDENTITY_FIELDS = ('analysis_id', 'image_id', 'request_id')
REVISION_FIELDS = ('crop_revision', 'decision_revision', 'answers_revision')
COMMON_FIELDS = {*IDENTITY_FIELDS, *REVISION_FIELDS, 'image_hash'}
EXTRA_FIELDS = {
    'detect': set(), 'focus': {'manual', 'box'}, 'classify': set(),
    'questionnaire': {'decision'},
    'multimodal': {'decision', 'questionnaire_id', 'questionnaire_version', 'answers'},
    'feedback': {'event'},
}
TIME_OPTIONS = ['Menos de 2 semanas', 'Entre 2 e 4 semanas', 'Mais de 4 semanas', 'Não informado']
OBSERVATION_OPTIONS = ['Não', 'Sim', 'Não informado']


def _questionnaire(index, title, context_prompt):
    return {
        'questionnaire_id': f'lesion-{index}-demo', 'questionnaire_version': 1,
        'title': title, 'demonstrative': True, 'clinical_review_pending': True,
        'sections': [
            {'id': 'context', 'title': 'Contexto informado', 'questions': [
                {'id': f'c{index}_context', 'prompt': context_prompt, 'options': TIME_OPTIONS},
            ]},
            {'id': 'observations', 'title': 'Observações sobre a alteração', 'questions': [
                {'id': f'c{index}_observation',
                 'prompt': f'Foi relatado algum sintoma associado à alteração descrita como {CLASSES[index]}?',
                 'options': OBSERVATION_OPTIONS},
                {'id': f'c{index}_change',
                 'prompt': f'Foi percebida mudança recente na alteração descrita como {CLASSES[index]}?',
                 'options': OBSERVATION_OPTIONS},
            ]},
        ],
    }


# Separate versioned forms. Their content is illustrative and never determines risk.
QUESTIONNAIRES = (
    _questionnaire(0, 'Informações sobre pápula/nódulo', 'Há quanto tempo a alteração descrita como pápula/nódulo foi percebida?'),
    _questionnaire(1, 'Informações sobre mácula/mancha', 'Há quanto tempo a alteração descrita como mácula/mancha foi percebida?'),
    _questionnaire(2, 'Informações sobre vesícula/bolha', 'Há quanto tempo a alteração descrita como vesícula/bolha foi percebida?'),
    _questionnaire(3, 'Informações sobre erosão', 'Há quanto tempo a alteração descrita como erosão foi percebida?'),
    _questionnaire(4, 'Informações sobre úlcera', 'Há quanto tempo a alteração descrita como úlcera foi percebida?'),
    _questionnaire(5, 'Informações sobre placa', 'Há quanto tempo a alteração descrita como placa foi percebida?'),
)


class UseSuggestedClassProvisionally:
    """Replaceable navigation policy, not clinical confirmation."""
    name = 'use_suggested_provisionally_v1'

    def effective_class(self, suggested):
        return suggested


UNCERTAINTY_POLICY = UseSuggestedClassProvisionally()


def _identifier(value):
    return isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9_-]{16,80}', value) is not None


def _class(value):
    if type(value) is not int or value not in range(len(CLASSES)):
        raise InvalidRequest('Classe inválida.')
    return value


def _envelope(operation, data):
    if not isinstance(data, dict) or operation not in OPERATIONS:
        raise InvalidRequest('Requisição inválida.')
    allowed = COMMON_FIELDS | EXTRA_FIELDS[operation]
    if operation != 'feedback':
        allowed = allowed | {'image_base64'}
    if set(data) - allowed:
        raise InvalidRequest('Campo não previsto no contrato v2.')
    if any(not _identifier(data.get(key)) for key in IDENTITY_FIELDS):
        raise InvalidRequest('Identidade da análise, imagem ou requisição inválida.')
    for key in REVISION_FIELDS:
        value = data.get(key)
        if type(value) is not int or not 0 <= value <= 2_147_483_647:
            raise InvalidRequest('Revisão de entrada inválida.')
    if operation in ('focus', 'classify', 'questionnaire', 'multimodal') and data['crop_revision'] < 1:
        raise InvalidRequest('Confirme uma região de interesse antes de continuar.')
    if operation in ('questionnaire', 'multimodal') and data['decision_revision'] < 1:
        raise InvalidRequest('Registre a decisão sobre a classe antes de continuar.')
    if operation == 'multimodal' and data['answers_revision'] < 1:
        raise InvalidRequest('Confirme as respostas antes de continuar.')
    image_hash = data.get('image_hash')
    if not isinstance(image_hash, str) or re.fullmatch(r'[0-9a-f]{64}', image_hash) is None:
        raise InvalidRequest('Referência da imagem inválida.')
    return {
        'api_version': VERSION, 'operation': operation,
        'simulation_only': True, 'execution_mode': 'cloud', 'data_stored': False,
        **{key: data[key] for key in (*IDENTITY_FIELDS, *REVISION_FIELDS, 'image_hash')},
        'feedback': [],
    }


def _decision(data):
    decision = data.get('decision')
    if not isinstance(decision, dict) or set(decision) != {'status', 'suggested_class', 'selected_class'}:
        raise InvalidRequest('Decisão sobre a classe inválida.')
    suggested = _class(decision['suggested_class'])
    if suggested != ghost_choice(data['analysis_id'], 'cnn', len(CLASSES)):
        raise InvalidRequest('Classe sugerida não corresponde à análise.')
    status, selected = decision['status'], decision['selected_class']
    if status == 'uncertain':
        if selected is not None:
            raise InvalidRequest('Incerteza não confirma uma classe alternativa.')
        effective = UNCERTAINTY_POLICY.effective_class(suggested)
    elif status in ('confirmed', 'corrected'):
        effective = _class(selected)
        if (status == 'confirmed') != (effective == suggested):
            raise InvalidRequest('Decisão inconsistente com a classe selecionada.')
    else:
        raise InvalidRequest('Estado da decisão inválido.')
    return {
        'decision': dict(decision), 'class_index': effective, 'effective_class': effective,
        'provisional': status == 'uncertain', 'class_confirmed': status != 'uncertain',
        'decision_policy': UNCERTAINTY_POLICY.name if status == 'uncertain' else None,
    }


def _box(value):
    if not isinstance(value, dict) or set(value) != {'left', 'top', 'right', 'bottom'}:
        raise InvalidRequest('Região de interesse inválida.')
    if any(type(v) not in (int, float) or not math.isfinite(v) for v in value.values()):
        raise InvalidRequest('Região de interesse inválida.')
    if not (0 <= value['left'] < value['right'] <= 1 and 0 <= value['top'] < value['bottom'] <= 1):
        raise InvalidRequest('Região de interesse inválida.')
    return value


def _curation(data, target, reason, event_id=None):
    source = event_id or f"{data['request_id']}:{reason}"
    receipt_id = hashlib.sha256(f"{data['analysis_id']}:{source}".encode()).hexdigest()[:32]
    approved = ghost_choice(data['analysis_id'], f'curation:{target}:{source}', 2) == 1
    return {
        'event_id': receipt_id, 'source_event_id': event_id,
        'module': 'IntelligentSystemStub', 'target': target, 'reason': reason,
        'image_id': data['image_id'], 'image_hash': data['image_hash'],
        'candidate_for_curation': True, 'approved_simulated': approved,
        'clinical_validation': False, 'data_stored': False,
        'retraining': {'module': f'{target}RetrainingStub',
                      'status': 'simulated_acknowledged' if approved else 'not_forwarded',
                      'model_updated': False, 'data_stored': False},
    }


def _feedback_event(data):
    event = data.get('event')
    if not isinstance(event, dict) or set(event) != {'event_id', 'type', 'details'}:
        raise InvalidRequest('Evento inválido.')
    if not _identifier(event['event_id']) or not isinstance(event['type'], str) or not re.fullmatch(r'[a-z][a-z0-9_]{1,63}', event['type']):
        raise InvalidRequest('Identificação do evento inválida.')
    details = event['details']
    if not isinstance(details, dict):
        raise InvalidRequest('Metadados de evento inválidos.')
    # Bound metadata; image bytes/files and personal fields are not part of this API.
    allowed = {'reason', 'stage', 'source', 'previous_image_id', 'previous_image_hash',
               'suggested_class', 'selected_class', 'effective_class', 'status',
               'provisional', 'class_confirmed', 'from_stage', 'to_stage',
               'box', 'candidate_for_review'}
    if set(details) - allowed or len(json.dumps(details, ensure_ascii=False)) > 2048:
        raise InvalidRequest('Envie somente metadados demonstrativos do evento.')
    for key, value in details.items():
        if key == 'box':
            _box(value)
            continue
        if key == 'candidate_for_review' and type(value) is not bool:
            raise InvalidRequest('Indicador de curadoria inválido.')
        if type(value) not in (str, int, bool, type(None)) or (isinstance(value, str) and len(value) > 160):
            raise InvalidRequest('Metadados de evento inválidos.')
    return event


def process(operation, data):
    result = _envelope(operation, data)
    analysis = data['analysis_id']
    if operation == 'feedback':
        event = _feedback_event(data)
        event_type = event['type']
        target = ('YOLO' if any(word in event_type for word in ('crop', 'detection', 'image'))
                  else 'CNN' if any(word in event_type for word in ('class', 'uncertain')) else 'Pipeline')
        result.update(module='IntelligentSystemStub', received=True,
                      event_id=event['event_id'], status='simulated_acknowledged')
        result['feedback'].append(_curation(data, target, event_type, event['event_id']))
        return result

    raw, pixels = decode_image(data)
    if hashlib.sha256(raw).hexdigest() != data['image_hash']:
        raise InvalidRequest('A imagem recebida não corresponde à imagem confirmada.')
    if operation == 'detect':
        # This branch distribution is illustrative, never detection from pixels.
        detected = ghost_choice(analysis, 'detect', 8) != 0
        result.update(module='YoloDetectionStub', detected=detected,
                      detection_status='found' if detected else 'not_found',
                      box=None, crop_base64=None, crop_hash=None)
        if detected:
            box = {'left': .1, 'top': .1, 'right': .9, 'bottom': .9}
            crop = pixels.crop((math.floor(pixels.width * .1), math.floor(pixels.height * .1),
                                math.ceil(pixels.width * .9), math.ceil(pixels.height * .9)))
            output = io.BytesIO()
            crop.save(output, format='PNG')
            cropped = output.getvalue()
            result.update(box=box, crop_base64=base64.b64encode(cropped).decode(),
                          crop_hash=hashlib.sha256(cropped).hexdigest())
        else:
            result['feedback'].append(_curation(data, 'YOLO', 'detection_failed'))
    elif operation == 'focus':
        if type(data.get('manual')) is not bool:
            raise InvalidRequest('Origem do recorte inválida.')
        _box(data.get('box'))
        result.update(module='FocusEvaluationStub', adequate=ghost_choice(analysis, 'focus', 2) == 1,
                      user_decides=True)
        if data['manual']:
            result['feedback'].append(_curation(data, 'YOLO', 'manual_crop'))
    elif operation == 'classify':
        index = ghost_choice(analysis, 'cnn', len(CLASSES))
        result.update(module='CnnClassificationStub', class_index=index, class_label=CLASSES[index])
    else:
        metadata = _decision(data)
        index = metadata['effective_class']
        form = copy.deepcopy(QUESTIONNAIRES[index])
        result.update(metadata)
        if operation == 'questionnaire':
            result.update(module='QuestionnaireStub', **form)
            if metadata['decision']['status'] != 'confirmed':
                reason = 'class_uncertain' if metadata['provisional'] else 'class_corrected'
                result['feedback'].append(_curation(data, 'CNN', reason))
        else:
            if data.get('questionnaire_id') != form['questionnaire_id'] or type(data.get('questionnaire_version')) is not int or data['questionnaire_version'] != form['questionnaire_version']:
                raise InvalidRequest('Questionário não corresponde à classe utilizada.')
            answers = data.get('answers')
            questions = [question for section in form['sections'] for question in section['questions']]
            if not isinstance(answers, dict) or set(answers) != {question['id'] for question in questions} or any(type(answers[question['id']]) is not str or answers[question['id']] not in question['options'] for question in questions):
                raise InvalidRequest('Responda todas as perguntas deste questionário.')
            result.update(MULTIMODAL_MODELS[index].evaluate(analysis, data['image_hash'], answers, metadata['decision']))
            result.update(questionnaire_id=form['questionnaire_id'], questionnaire_version=form['questionnaire_version'])
            if metadata['provisional']:
                result['provisional_notice'] = 'A classe usada como referência não foi confirmada pelo profissional. Sua utilização é provisória e não representa validação clínica.'
            else:
                result['provisional_notice'] = None
            result['feedback'].append(_curation(data, 'MNN', 'multimodal_result'))
    return result
