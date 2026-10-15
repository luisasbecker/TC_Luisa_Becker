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

__all__ = [
    "BoundingBox",
    "CancerRiskClass",
    "ClassificationDecision",
    "ClinicalImage",
    "CNNResult",
    "CroppedImage",
    "DetectionResult",
    "ElementaryLesionClass",
    "FeedbackEvent",
    "FeedbackEventType",
    "FocusResult",
    "HistoryEvent",
    "ImageQualityStatus",
    "MultimodalResult",
    "PipelineStep",
    "PipelineTransitionError",
    "QuestionnaireAnswers",
    "QuestionnaireQuestion",
    "SessionState",
    "StubConfig",
    "UserDecision",
]
