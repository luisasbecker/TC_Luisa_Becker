from .models import CroppedImage, FocusResult, StubConfig


class FocusEvaluationStub:
    """Bloco fantasma de processamento e avaliação interna do foco."""

    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def evaluate(self, image: CroppedImage) -> FocusResult:
        return FocusResult(
            image.image_id,
            self.config.focus_score,
            self.config.focus_status,
            "Avaliação de foco fantasma concluída; o escore é apenas controle interno.",
        )
