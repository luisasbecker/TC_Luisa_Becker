from .enums import ElementaryLesionClass
from .models import CNNResult, CroppedImage, StubConfig


EXAMPLES_BY_CLASS: dict[ElementaryLesionClass, tuple[str, ...]] = {
    lesion_class: (
        f"EXEMPLO SIMULADO A — cartão sintético de {lesion_class.value}",
        f"EXEMPLO SIMULADO B — cartão sintético de {lesion_class.value}",
    )
    for lesion_class in ElementaryLesionClass
}


class CNNClassificationStub:
    """Bloco fantasma que sugere uma classe de lesão elementar fixa."""

    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def classify(self, image: CroppedImage) -> CNNResult:
        return CNNResult(
            image.image_id,
            self.config.cnn_class,
            self.config.cnn_confidence,
            EXAMPLES_BY_CLASS[self.config.cnn_class],
        )
