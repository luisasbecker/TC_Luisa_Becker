from .enums import ElementaryLesionClass
from .models import (
    CroppedImage,
    MultimodalResult,
    QuestionnaireAnswers,
    StubConfig,
)


MEDICAL_GUIDANCE = (
    "Este resultado indica {risk}. Busque avaliação médica adequada. "
    "O sistema é apenas uma ferramenta de apoio e não substitui avaliação profissional "
    "nem exames complementares quando indicados."
)


class _BaseMultimodalStub:
    lesion_class: ElementaryLesionClass

    def __init__(self, config: StubConfig) -> None:
        self.config = config

    def analyze(
        self,
        image: CroppedImage,
        lesion_class: ElementaryLesionClass,
        answers: QuestionnaireAnswers,
    ) -> MultimodalResult:
        if lesion_class is not self.lesion_class or answers.lesion_class is not lesion_class:
            raise ValueError(
                "A classe deve corresponder ao modelo multimodal específico por classe."
            )
        if not image.image_id:
            raise ValueError("A imagem processada é obrigatória.")
        if not answers.responses or any(
            not value.strip() for value in answers.responses.values()
        ):
            raise ValueError("Todas as respostas simuladas devem ser preenchidas.")
        return MultimodalResult(
            lesion_class=lesion_class,
            model_name=type(self).__name__,
            risk=self.config.final_risk,
            message=MEDICAL_GUIDANCE.format(risk=self.config.final_risk.value),
        )


class PapuleNoduleMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.PAPULE_NODULE


class MaculeSpotMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.MACULE_SPOT


class VesicleBullaMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.VESICLE_BULLA


class ErosionMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.EROSION


class UlcerMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.ULCER


class PlaqueMultimodalStub(_BaseMultimodalStub):
    lesion_class = ElementaryLesionClass.PLAQUE


def build_multimodal_registry(
    config: StubConfig,
) -> dict[ElementaryLesionClass, _BaseMultimodalStub]:
    return {
        ElementaryLesionClass.PAPULE_NODULE: PapuleNoduleMultimodalStub(config),
        ElementaryLesionClass.MACULE_SPOT: MaculeSpotMultimodalStub(config),
        ElementaryLesionClass.VESICLE_BULLA: VesicleBullaMultimodalStub(config),
        ElementaryLesionClass.EROSION: ErosionMultimodalStub(config),
        ElementaryLesionClass.ULCER: UlcerMultimodalStub(config),
        ElementaryLesionClass.PLAQUE: PlaqueMultimodalStub(config),
    }
