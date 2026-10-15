from dataclasses import dataclass, field
from uuid import uuid4

from .enums import ElementaryLesionClass, PipelineStep, UserDecision
from .models import (
    CNNResult,
    ClassificationDecision,
    ClinicalImage,
    CroppedImage,
    DetectionResult,
    FeedbackEvent,
    FocusResult,
    HistoryEvent,
    MultimodalResult,
    QuestionnaireAnswers,
)


class PipelineTransitionError(RuntimeError):
    """Indica tentativa de executar uma etapa fora da ordem do pipeline."""


@dataclass
class SessionState:
    session_id: str = field(default_factory=lambda: str(uuid4()))
    step: PipelineStep = PipelineStep.EMPTY
    original_image: ClinicalImage | None = None
    detection_result: DetectionResult | None = None
    active_crop: CroppedImage | None = None
    manual_crop_used: bool = False
    focus_result: FocusResult | None = None
    visual_quality_decision: UserDecision | None = None
    cnn_result: CNNResult | None = None
    classification_decision: ClassificationDecision | None = None
    final_class: ElementaryLesionClass | None = None
    questionnaire_answers: QuestionnaireAnswers | None = None
    multimodal_result: MultimodalResult | None = None
    feedback_events: list[FeedbackEvent] = field(default_factory=list)
    history: list[HistoryEvent] = field(default_factory=list)
    final_message: str | None = None
