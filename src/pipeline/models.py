from dataclasses import dataclass
from uuid import uuid4

from .enums import (
    CancerRiskClass,
    ElementaryLesionClass,
    FeedbackEventType,
    ImageQualityStatus,
    PipelineStep,
    UserDecision,
)


@dataclass(frozen=True)
class BoundingBox:
    x_min: int
    y_min: int
    x_max: int
    y_max: int

    def __post_init__(self) -> None:
        if min(self.x_min, self.y_min) < 0:
            raise ValueError("As coordenadas não podem ser negativas.")
        if self.x_max <= self.x_min or self.y_max <= self.y_min:
            raise ValueError("As coordenadas finais devem superar as iniciais.")

    def as_dict(self) -> dict[str, int]:
        return {
            "x_min": self.x_min,
            "y_min": self.y_min,
            "x_max": self.x_max,
            "y_max": self.y_max,
        }


@dataclass(frozen=True)
class ClinicalImage:
    image_id: str
    name: str
    source: str
    byte_size: int
    content_hash: str

    @classmethod
    def create(
        cls, name: str, source: str, byte_size: int, content_hash: str
    ) -> "ClinicalImage":
        if not name.strip() or not source.strip() or not content_hash.strip():
            raise ValueError("Nome, origem e hash da imagem são obrigatórios.")
        if byte_size < 0:
            raise ValueError("O tamanho da imagem não pode ser negativo.")
        return cls(str(uuid4()), name, source, byte_size, content_hash)


@dataclass(frozen=True)
class CroppedImage:
    image_id: str
    name: str
    source: str
    parent_image_id: str
    bounding_box: BoundingBox | None
    manual: bool

    @classmethod
    def create(
        cls,
        original: ClinicalImage,
        name: str,
        source: str,
        bounding_box: BoundingBox | None,
        manual: bool,
    ) -> "CroppedImage":
        if not name.strip() or not source.strip():
            raise ValueError("Nome e origem do recorte são obrigatórios.")
        return cls(
            image_id=str(uuid4()),
            name=name,
            source=source,
            parent_image_id=original.image_id,
            bounding_box=bounding_box,
            manual=manual,
        )


@dataclass(frozen=True)
class DetectionResult:
    success: bool
    detected_class: str
    bounding_box: BoundingBox | None
    confidence: float | None
    cropped_image: CroppedImage | None
    message: str


@dataclass(frozen=True)
class FocusResult:
    image_id: str
    score: float
    status: ImageQualityStatus
    message: str


@dataclass(frozen=True)
class CNNResult:
    image_id: str
    suggested_class: ElementaryLesionClass
    confidence: float
    example_descriptions: tuple[str, ...]


@dataclass(frozen=True)
class ClassificationDecision:
    decision: UserDecision
    suggested_class: ElementaryLesionClass
    corrected_class: ElementaryLesionClass | None = None


@dataclass(frozen=True)
class QuestionnaireQuestion:
    question_id: str
    prompt: str
    answer_options: tuple[str, ...]


@dataclass(frozen=True)
class QuestionnaireAnswers:
    lesion_class: ElementaryLesionClass
    responses: dict[str, str]


@dataclass(frozen=True)
class MultimodalResult:
    lesion_class: ElementaryLesionClass
    model_name: str
    risk: CancerRiskClass
    message: str


@dataclass(frozen=True)
class FeedbackEvent:
    event_type: FeedbackEventType
    image_id: str
    details: dict[str, object]
    requires_curator_review: bool
    retraining_candidate: bool


@dataclass(frozen=True)
class HistoryEvent:
    step: PipelineStep
    message: str
    details: dict[str, object]


@dataclass(frozen=True)
class StubConfig:
    detection_success: bool = True
    detection_box: BoundingBox = BoundingBox(40, 30, 360, 270)
    detection_confidence: float = 0.88
    focus_score: float = 0.82
    focus_status: ImageQualityStatus = ImageQualityStatus.ADEQUATE
    cnn_class: ElementaryLesionClass = ElementaryLesionClass.ULCER
    cnn_confidence: float = 0.81
    final_risk: CancerRiskClass = CancerRiskClass.MEDIUM

    def __post_init__(self) -> None:
        for name, value in (
            ("confiança da detecção", self.detection_confidence),
            ("escore de foco", self.focus_score),
            ("confiança da CNN", self.cnn_confidence),
        ):
            if not 0 <= value <= 1:
                raise ValueError(f"{name.capitalize()} deve estar entre 0 e 1.")
