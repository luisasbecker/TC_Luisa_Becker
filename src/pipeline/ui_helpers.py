from .enums import CancerRiskClass, ElementaryLesionClass, ImageQualityStatus
from .models import BoundingBox, StubConfig


def clamp_box_to_image(
    coordinates: tuple[int, int, int, int], width: int, height: int
) -> tuple[int, int, int, int]:
    """Limita apenas a prévia visual, preservando ao menos um pixel."""

    if width < 1 or height < 1:
        raise ValueError("A imagem deve ter largura e altura positivas.")
    x_min, y_min, x_max, y_max = coordinates
    left = max(0, min(x_min, width - 1))
    top = max(0, min(y_min, height - 1))
    right = max(left + 1, min(x_max, width))
    bottom = max(top + 1, min(y_max, height))
    return left, top, right, bottom


def build_stub_config(
    *,
    detection_success: bool,
    detection_box: tuple[int, int, int, int],
    detection_confidence: float,
    focus_score: float,
    focus_status: ImageQualityStatus,
    cnn_class: ElementaryLesionClass,
    cnn_confidence: float,
    final_risk: CancerRiskClass,
) -> StubConfig:
    """Converte escolhas da interface em configuração determinística."""

    return StubConfig(
        detection_success=detection_success,
        detection_box=BoundingBox(*detection_box),
        detection_confidence=detection_confidence,
        focus_score=focus_score,
        focus_status=focus_status,
        cnn_class=cnn_class,
        cnn_confidence=cnn_confidence,
        final_risk=final_risk,
    )
