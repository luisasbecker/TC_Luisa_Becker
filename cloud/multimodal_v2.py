"""Six independent routing components sharing a non-clinical simulation policy."""
import hashlib


def ghost_choice(analysis_id, module, count):
    """Stable per randomly created analysis; no pixels or clinical rules involved."""
    digest = hashlib.sha256(f'ghost-v2:{analysis_id}:{module}'.encode()).digest()
    return int.from_bytes(digest, 'big') % count


RISK_CODES = ('low', 'medium', 'high')
RISK_LABELS = ('Risco baixo', 'Risco médio', 'Risco alto')
RISK_MESSAGES = (
    'Classificação de risco apresentada para fins demonstrativos. Risco baixo '
    'não garante ausência de câncer. Busque avaliação médica adequada.',
    'Classificação de risco apresentada para fins demonstrativos. Recomenda-se '
    'avaliação médica para investigar a alteração observada.',
    'Classificação de risco apresentada para fins demonstrativos. É importante '
    'buscar avaliação médica especializada para investigar a alteração.',
)
DISCLAIMER = 'Resultado simulado, não é diagnóstico. Texto demonstrativo, sujeito à revisão por especialista.'


class MultimodalStub:
    class_index = None

    def evaluate(self, analysis_id, image_hash, answers, decision):
        # Inputs remain explicit to preserve the future model interface, but none
        # of them influences this ghost risk. No inference, training or storage.
        risk = ghost_choice(analysis_id, 'risk', len(RISK_CODES))
        return {
            'module': type(self).__name__, 'class_index': self.class_index,
            'risk': RISK_CODES[risk], 'risk_index': risk,
            'risk_label': RISK_LABELS[risk], 'message': RISK_MESSAGES[risk],
            'disclaimer': DISCLAIMER, 'text_review_pending': True,
        }


class PapuleNoduleMultimodalStub(MultimodalStub):
    class_index = 0


class MaculeSpotMultimodalStub(MultimodalStub):
    class_index = 1


class VesicleBullaMultimodalStub(MultimodalStub):
    class_index = 2


class ErosionMultimodalStub(MultimodalStub):
    class_index = 3


class UlcerMultimodalStub(MultimodalStub):
    class_index = 4


class PlaqueMultimodalStub(MultimodalStub):
    class_index = 5


MULTIMODAL_MODELS = (
    PapuleNoduleMultimodalStub(), MaculeSpotMultimodalStub(),
    VesicleBullaMultimodalStub(), ErosionMultimodalStub(),
    UlcerMultimodalStub(), PlaqueMultimodalStub(),
)
