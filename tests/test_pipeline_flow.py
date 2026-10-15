import unittest

from src.pipeline import (
    ElementaryLesionClass,
    PipelineController,
    PipelineStep,
    StubConfig,
    UserDecision,
)


class PipelineFlowTests(unittest.TestCase):
    def test_complete_flow_with_automatic_crop_and_cnn_agreement(self):
        controller = PipelineController(
            StubConfig(cnn_class=ElementaryLesionClass.ULCER)
        )
        state = controller.start_session(
            "imagem-simulada.png", "upload", 250, "hash-1"
        )
        controller.run_detection()
        controller.accept_automatic_crop()
        controller.run_focus_evaluation()
        controller.validate_visual_quality(UserDecision.ACCEPT)
        controller.run_cnn_classification()
        controller.record_classification_decision(UserDecision.ACCEPT)
        questions = controller.get_questionnaire()
        controller.submit_questionnaire(
            {question.question_id: "Resposta simulada" for question in questions}
        )
        result = controller.run_multimodal()

        self.assertEqual(state.step, PipelineStep.COMPLETED)
        self.assertEqual(state.final_class, ElementaryLesionClass.ULCER)
        self.assertEqual(result.model_name, "UlcerMultimodalStub")
        self.assertFalse(state.manual_crop_used)
        self.assertIs(state.active_crop, state.detection_result.cropped_image)
        self.assertEqual(result.lesion_class, state.questionnaire_answers.lesion_class)

    def test_rejects_out_of_order_transition_without_mutating_state(self):
        controller = PipelineController()
        controller.start_session("imagem.png", "upload", 10, "hash")
        history_before = list(controller.state.history)
        with self.assertRaisesRegex(Exception, "Etapa inválida"):
            controller.run_cnn_classification()
        self.assertEqual(controller.state.step, PipelineStep.IMAGE_LOADED)
        self.assertEqual(controller.state.history, history_before)


if __name__ == "__main__":
    unittest.main()
