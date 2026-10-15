import unittest

from src.pipeline import (
    BoundingBox,
    ClinicalImage,
    ElementaryLesionClass,
    FeedbackEventType,
    ImageQualityStatus,
    PipelineController,
    PipelineStep,
    StubConfig,
    UserDecision,
)


class PipelineFlowTests(unittest.TestCase):
    def test_start_session_registers_flow_metadata_with_intelligent_system(self):
        controller = PipelineController()
        state = controller.start_session("imagem.png", "upload", 10, "hash")

        self.assertEqual(len(state.feedback_events), 1)
        event = state.feedback_events[0]
        self.assertIs(event.event_type, FeedbackEventType.FLOW_METADATA)
        self.assertEqual(event.image_id, state.original_image.image_id)
        self.assertEqual(event.details["sessao_id"], state.session_id)
        self.assertEqual(event.details["etapa"], PipelineStep.IMAGE_LOADED.value)
        self.assertFalse(event.requires_curator_review)
        self.assertFalse(event.retraining_candidate)

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

    def test_rejected_automatic_crop_registers_manual_crop_and_continues(self):
        controller = PipelineController()
        state = controller.start_session("imagem.png", "upload", 20, "hash")
        controller.run_detection()
        manual = controller.submit_manual_crop(
            bounding_box=BoundingBox(5, 8, 200, 180)
        )
        controller.run_focus_evaluation()

        self.assertTrue(controller.state.manual_crop_used)
        self.assertTrue(manual.manual)
        self.assertEqual(manual.parent_image_id, state.original_image.image_id)
        self.assertEqual(controller.state.step, PipelineStep.FOCUS_EVALUATED)
        self.assertTrue(
            any(
                event.event_type is FeedbackEventType.MANUAL_CROP
                for event in controller.state.feedback_events
            )
        )
        self.assertTrue(
            any(event.retraining_candidate for event in controller.state.feedback_events)
        )

    def test_corrected_upload_preserves_original_lineage(self):
        controller = PipelineController()
        controller.start_session("original.png", "upload", 20, "hash-o")
        controller.run_detection()
        corrected = ClinicalImage.create(
            "corrigida.png", "upload_corrigido", 18, "hash-c"
        )
        crop = controller.submit_manual_crop(corrected_image=corrected)
        self.assertEqual(crop.name, "corrigida.png")
        self.assertEqual(crop.source, "corrected_upload")
        self.assertEqual(
            crop.parent_image_id, controller.state.original_image.image_id
        )
        self.assertIsNone(crop.bounding_box)

    def test_inadequate_visual_quality_stops_before_cnn_and_requests_new_upload(self):
        controller = PipelineController(
            StubConfig(focus_status=ImageQualityStatus.INADEQUATE)
        )
        controller.start_session("desfocada.png", "upload", 15, "hash-d")
        controller.run_detection()
        controller.accept_automatic_crop()
        controller.run_focus_evaluation()
        controller.validate_visual_quality(UserDecision.REJECT)

        self.assertEqual(controller.state.step, PipelineStep.QUALITY_REJECTED)
        self.assertIsNone(controller.state.cnn_result)
        self.assertIsNone(controller.state.multimodal_result)
        self.assertIn("nova imagem", controller.state.final_message.lower())
        with self.assertRaisesRegex(Exception, "Etapa inválida"):
            controller.run_cnn_classification()

    def test_cnn_disagreement_uses_corrected_class_and_registers_feedback(self):
        controller = PipelineController(
            StubConfig(cnn_class=ElementaryLesionClass.ULCER)
        )
        controller.start_session("imagem.png", "upload", 12, "hash")
        controller.run_detection()
        controller.accept_automatic_crop()
        controller.run_focus_evaluation()
        controller.validate_visual_quality(UserDecision.ACCEPT)
        controller.run_cnn_classification()
        controller.record_classification_decision(
            UserDecision.REJECT,
            corrected_class=ElementaryLesionClass.PLAQUE,
        )

        self.assertEqual(controller.state.final_class, ElementaryLesionClass.PLAQUE)
        self.assertEqual(len(controller.state.feedback_events), 4)
        self.assertEqual(
            {event.event_type for event in controller.state.feedback_events},
            {
                FeedbackEventType.CNN_DISAGREEMENT,
                FeedbackEventType.CORRECTED_CLASS,
                FeedbackEventType.RETRAINING_CANDIDATE,
                FeedbackEventType.FLOW_METADATA,
            },
        )
        questions = controller.get_questionnaire()
        controller.submit_questionnaire(
            {question.question_id: "Resposta" for question in questions}
        )
        result = controller.run_multimodal()
        self.assertEqual(result.model_name, "PlaqueMultimodalStub")


if __name__ == "__main__":
    unittest.main()
