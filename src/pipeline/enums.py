from enum import Enum


class ElementaryLesionClass(str, Enum):
    PAPULE_NODULE = "pápula/nódulo"
    MACULE_SPOT = "mácula/mancha"
    VESICLE_BULLA = "vesícula/bolha"
    EROSION = "erosão"
    ULCER = "úlcera"
    PLAQUE = "placa"


class ImageQualityStatus(str, Enum):
    ADEQUATE = "adequada"
    INADEQUATE = "inadequada"


class UserDecision(str, Enum):
    ACCEPT = "aceita/concorda"
    REJECT = "rejeita/discorda"


class CancerRiskClass(str, Enum):
    LOW = "risco baixo de câncer"
    MEDIUM = "risco médio de câncer"
    HIGH = "risco alto de câncer"


class FeedbackEventType(str, Enum):
    MANUAL_CROP = "recorte manual"
    CNN_DISAGREEMENT = "discordância da CNN"
    CORRECTED_CLASS = "classe corrigida"
    RETRAINING_CANDIDATE = "candidata a retreinamento futuro"
    FLOW_METADATA = "metadados do fluxo"


class PipelineStep(str, Enum):
    EMPTY = "sem imagem"
    IMAGE_LOADED = "imagem carregada"
    DETECTION_FAILED = "detecção não concluída"
    DETECTED = "recorte automático gerado"
    CROP_VALIDATED = "recorte validado"
    FOCUS_EVALUATED = "foco avaliado"
    QUALITY_REJECTED = "qualidade rejeitada; novo envio necessário"
    QUALITY_ACCEPTED = "qualidade aceita"
    CNN_CLASSIFIED = "classe de lesão elementar sugerida"
    CLASS_CONFIRMED = "classe final definida"
    QUESTIONNAIRE_ANSWERED = "questionário respondido"
    COMPLETED = "análise multimodal concluída"
