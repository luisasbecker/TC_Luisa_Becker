from .cnn_stub import CNNClassificationStub
from .enums import ElementaryLesionClass, PipelineStep, UserDecision
from .focus_stub import FocusEvaluationStub
from .intelligent_system import IntelligentSystemStub
from .models import (
    ClassificationDecision,
    ClinicalImage,
    CroppedImage,
    DetectionResult,
    FocusResult,
    HistoryEvent,
    MultimodalResult,
    QuestionnaireAnswers,
    QuestionnaireQuestion,
    StubConfig,
)
from .multimodal_stub import build_multimodal_registry
from .questionnaire_stub import QuestionnaireStub
from .state import PipelineTransitionError, SessionState
from .yolo_stub import YoloDetectionStub


class PipelineController:
    """Orquestra o fluxo teórico sem depender da interface Streamlit."""

    def __init__(self, config: StubConfig | None = None) -> None:
        self.config = config or StubConfig()
        self.state = SessionState()
        self.yolo = YoloDetectionStub(self.config)
        self.focus = FocusEvaluationStub(self.config)
        self.cnn = CNNClassificationStub(self.config)
        self.questionnaire = QuestionnaireStub()
        self.multimodal_models = build_multimodal_registry(self.config)
        self.intelligent_system = IntelligentSystemStub()

    def _require(self, *steps: PipelineStep) -> None:
        if self.state.step not in steps:
            expected = ", ".join(step.value for step in steps)
            raise PipelineTransitionError(
                f"Etapa inválida: estado atual '{self.state.step.value}'; "
                f"esperado: {expected}."
            )

    def _record(self, step: PipelineStep, message: str, **details: object) -> None:
        self.state.step = step
        self.state.history.append(HistoryEvent(step, message, details))

    def start_session(
        self,
        name: str,
        source: str,
        byte_size: int,
        content_hash: str,
    ) -> SessionState:
        self.state = SessionState()
        self.state.original_image = ClinicalImage.create(
            name, source, byte_size, content_hash
        )
        self._record(
            PipelineStep.IMAGE_LOADED,
            "Imagem clínica simulada carregada.",
            image_id=self.state.original_image.image_id,
            name=name,
        )
        return self.state

    def run_detection(self) -> DetectionResult:
        self._require(PipelineStep.IMAGE_LOADED)
        if self.state.original_image is None:
            raise PipelineTransitionError("A imagem original não está disponível.")
        result = self.yolo.detect(self.state.original_image)
        self.state.detection_result = result
        if result.success:
            self._record(
                PipelineStep.DETECTED,
                result.message,
                detected_class=result.detected_class,
                confidence=result.confidence,
            )
        else:
            self.state.final_message = (
                "A detecção fantasma não foi concluída. Envie uma nova imagem "
                "ou ajuste a configuração da simulação."
            )
            self._record(PipelineStep.DETECTION_FAILED, result.message)
        return result

    def accept_automatic_crop(self) -> CroppedImage:
        self._require(PipelineStep.DETECTED)
        result = self.state.detection_result
        if result is None or result.cropped_image is None:
            raise PipelineTransitionError("O recorte automático não está disponível.")
        self.state.active_crop = result.cropped_image
        self.state.manual_crop_used = False
        self._record(
            PipelineStep.CROP_VALIDATED,
            "Recorte automático aceito pelo profissional da saúde.",
            crop_id=result.cropped_image.image_id,
            manual=False,
        )
        return result.cropped_image

    def run_focus_evaluation(self) -> FocusResult:
        self._require(PipelineStep.CROP_VALIDATED)
        if self.state.active_crop is None:
            raise PipelineTransitionError("O recorte ativo não está disponível.")
        result = self.focus.evaluate(self.state.active_crop)
        self.state.focus_result = result
        self._record(
            PipelineStep.FOCUS_EVALUATED,
            result.message,
            internal_score=result.score,
            internal_status=result.status.value,
        )
        return result

    def validate_visual_quality(self, decision: UserDecision) -> SessionState:
        self._require(PipelineStep.FOCUS_EVALUATED)
        self.state.visual_quality_decision = decision
        if decision is UserDecision.REJECT:
            self.state.final_message = (
                "A qualidade visual foi considerada inadequada. Envie uma nova "
                "imagem para reiniciar o pipeline."
            )
            self._record(
                PipelineStep.QUALITY_REJECTED,
                self.state.final_message,
                user_decision=decision.value,
            )
        else:
            self._record(
                PipelineStep.QUALITY_ACCEPTED,
                "Qualidade visual aceita pelo profissional da saúde.",
                user_decision=decision.value,
            )
        return self.state

    def run_cnn_classification(self):
        self._require(PipelineStep.QUALITY_ACCEPTED)
        if self.state.active_crop is None:
            raise PipelineTransitionError("A imagem recortada não está disponível.")
        result = self.cnn.classify(self.state.active_crop)
        self.state.cnn_result = result
        self._record(
            PipelineStep.CNN_CLASSIFIED,
            "CNN fantasma sugeriu uma classe de lesão elementar.",
            suggested_class=result.suggested_class.value,
            confidence=result.confidence,
        )
        return result

    def record_classification_decision(
        self,
        decision: UserDecision,
        corrected_class: ElementaryLesionClass | None = None,
    ) -> ClassificationDecision:
        self._require(PipelineStep.CNN_CLASSIFIED)
        if self.state.cnn_result is None:
            raise PipelineTransitionError("O resultado da CNN não está disponível.")
        if decision is UserDecision.REJECT:
            raise ValueError("A correção de classe ainda não foi registrada.")
        if corrected_class is not None:
            raise ValueError("Não informe classe corrigida quando houver concordância.")
        result = ClassificationDecision(
            decision=decision,
            suggested_class=self.state.cnn_result.suggested_class,
        )
        self.state.classification_decision = result
        self.state.final_class = result.suggested_class
        self._record(
            PipelineStep.CLASS_CONFIRMED,
            "Classe de lesão elementar confirmada pelo profissional da saúde.",
            final_class=result.suggested_class.value,
            decision=decision.value,
        )
        return result

    def get_questionnaire(self) -> tuple[QuestionnaireQuestion, ...]:
        self._require(PipelineStep.CLASS_CONFIRMED)
        if self.state.final_class is None:
            raise PipelineTransitionError("A classe final não está disponível.")
        return self.questionnaire.questions_for(self.state.final_class)

    def submit_questionnaire(
        self, responses: dict[str, str]
    ) -> QuestionnaireAnswers:
        self._require(PipelineStep.CLASS_CONFIRMED)
        if self.state.final_class is None:
            raise PipelineTransitionError("A classe final não está disponível.")
        questions = self.questionnaire.questions_for(self.state.final_class)
        expected_ids = {question.question_id for question in questions}
        if set(responses) != expected_ids:
            raise ValueError("Responda todas e somente as perguntas simuladas.")
        if any(not answer.strip() for answer in responses.values()):
            raise ValueError("As respostas simuladas não podem ficar vazias.")
        result = QuestionnaireAnswers(self.state.final_class, dict(responses))
        self.state.questionnaire_answers = result
        self._record(
            PipelineStep.QUESTIONNAIRE_ANSWERED,
            "Questionário fantasma específico da classe respondido.",
            final_class=self.state.final_class.value,
            response_count=len(responses),
        )
        return result

    def run_multimodal(self) -> MultimodalResult:
        self._require(PipelineStep.QUESTIONNAIRE_ANSWERED)
        if (
            self.state.active_crop is None
            or self.state.final_class is None
            or self.state.questionnaire_answers is None
        ):
            raise PipelineTransitionError(
                "Imagem, classe final e questionário são obrigatórios."
            )
        model = self.multimodal_models[self.state.final_class]
        result = model.analyze(
            self.state.active_crop,
            self.state.final_class,
            self.state.questionnaire_answers,
        )
        self.state.multimodal_result = result
        self.state.final_message = result.message
        self._record(
            PipelineStep.COMPLETED,
            "Modelo multimodal específico por classe concluiu a simulação.",
            model_name=result.model_name,
            risk=result.risk.value,
        )
        return result
