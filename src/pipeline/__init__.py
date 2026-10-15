"""API pública do pipeline de lesões bucais."""

from .enums import (
    CancerRiskClass,
    ElementaryLesionClass,
    FeedbackEventType,
    ImageQualityStatus,
    PipelineStep,
    UserDecision,
)
from .models import (
    BoundingBox,
    ClassificationDecision,
    ClinicalImage,
    CNNResult,
    CroppedImage,
    DetectionResult,
    FeedbackEvent,
    FocusResult,
    HistoryEvent,
    MultimodalResult,
    QuestionnaireAnswers,
    QuestionnaireQuestion,
    StubConfig,
)
from .state import PipelineTransitionError, SessionState
from .cnn_stub import CNNClassificationStub
from .focus_stub import FocusEvaluationStub
from .intelligent_system import IntelligentSystemStub
from .multimodal_stub import (
    ErosionMultimodalStub,
    MaculeSpotMultimodalStub,
    PapuleNoduleMultimodalStub,
    PlaqueMultimodalStub,
    UlcerMultimodalStub,
    VesicleBullaMultimodalStub,
    build_multimodal_registry,
)
from .questionnaire_stub import QuestionnaireStub
from .yolo_stub import YoloDetectionStub
from .pipeline_controller import PipelineController
from .ui_helpers import build_stub_config, clamp_box_to_image

__all__ = [
    "BoundingBox",
    "CancerRiskClass",
    "CNNClassificationStub",
    "ClassificationDecision",
    "ClinicalImage",
    "CNNResult",
    "CroppedImage",
    "DetectionResult",
    "ElementaryLesionClass",
    "ErosionMultimodalStub",
    "FeedbackEvent",
    "FeedbackEventType",
    "FocusEvaluationStub",
    "FocusResult",
    "HistoryEvent",
    "ImageQualityStatus",
    "IntelligentSystemStub",
    "MaculeSpotMultimodalStub",
    "MultimodalResult",
    "PapuleNoduleMultimodalStub",
    "PipelineStep",
    "PipelineController",
    "PipelineTransitionError",
    "PlaqueMultimodalStub",
    "QuestionnaireAnswers",
    "QuestionnaireQuestion",
    "QuestionnaireStub",
    "SessionState",
    "StubConfig",
    "UlcerMultimodalStub",
    "UserDecision",
    "VesicleBullaMultimodalStub",
    "YoloDetectionStub",
    "build_multimodal_registry",
    "build_stub_config",
    "clamp_box_to_image",
]
