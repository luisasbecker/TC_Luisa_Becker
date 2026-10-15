from .enums import ElementaryLesionClass, FeedbackEventType
from .models import ClinicalImage, CroppedImage, FeedbackEvent


class IntelligentSystemStub:
    """Registra feedback para curadoria, sem executar retreinamento."""

    def register_manual_crop(
        self, original: ClinicalImage, crop: CroppedImage
    ) -> tuple[FeedbackEvent, FeedbackEvent]:
        common: dict[str, object] = {
            "imagem_original_id": original.image_id,
            "recorte_id": crop.image_id,
            "observacao": (
                "Dado sujeito a curadoria; não incorporado automaticamente."
            ),
        }
        return (
            FeedbackEvent(
                FeedbackEventType.MANUAL_CROP,
                crop.image_id,
                common,
                True,
                False,
            ),
            FeedbackEvent(
                FeedbackEventType.RETRAINING_CANDIDATE,
                crop.image_id,
                {**common, "modelo_futuro": "YOLO"},
                True,
                True,
            ),
        )

    def register_cnn_disagreement(
        self,
        image: CroppedImage,
        suggested: ElementaryLesionClass,
        corrected: ElementaryLesionClass,
    ) -> tuple[FeedbackEvent, FeedbackEvent, FeedbackEvent]:
        common: dict[str, object] = {
            "classe_sugerida": suggested.value,
            "classe_corrigida": corrected.value,
            "observacao": (
                "Dado sujeito a curadoria; não incorporado automaticamente."
            ),
        }
        return (
            FeedbackEvent(
                FeedbackEventType.CNN_DISAGREEMENT,
                image.image_id,
                common,
                True,
                False,
            ),
            FeedbackEvent(
                FeedbackEventType.CORRECTED_CLASS,
                image.image_id,
                common,
                True,
                False,
            ),
            FeedbackEvent(
                FeedbackEventType.RETRAINING_CANDIDATE,
                image.image_id,
                {**common, "modelo_futuro": "CNN"},
                True,
                True,
            ),
        )
