from .models import ClinicalImage, CroppedImage, DetectionResult, StubConfig


class YoloDetectionStub:
    """Bloco fantasma que simula localização e recorte de uma lesão."""

    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def detect(self, image: ClinicalImage) -> DetectionResult:
        if not self.config.detection_success:
            return DetectionResult(
                False,
                "lesão",
                None,
                None,
                None,
                "Detecção fantasma não concluída.",
            )
        crop = CroppedImage.create(
            original=image,
            name=f"{image.name}_recorte_automatico",
            source="yolo_stub",
            bounding_box=self.config.detection_box,
            manual=False,
        )
        return DetectionResult(
            True,
            "lesão",
            self.config.detection_box,
            self.config.detection_confidence,
            crop,
            "YOLO fantasma localizou uma região de interesse simulada.",
        )
