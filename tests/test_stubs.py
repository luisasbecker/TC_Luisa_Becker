import unittest

from src.pipeline import (
    CancerRiskClass,
    ClinicalImage,
    ElementaryLesionClass,
    QuestionnaireAnswers,
    StubConfig,
)
from src.pipeline.cnn_stub import CNNClassificationStub
from src.pipeline.focus_stub import FocusEvaluationStub
from src.pipeline.intelligent_system import IntelligentSystemStub
from src.pipeline.multimodal_stub import (
    ErosionMultimodalStub,
    MaculeSpotMultimodalStub,
    PapuleNoduleMultimodalStub,
    PlaqueMultimodalStub,
    UlcerMultimodalStub,
    VesicleBullaMultimodalStub,
    build_multimodal_registry,
)
from src.pipeline.questionnaire_stub import QuestionnaireStub
from src.pipeline.yolo_stub import YoloDetectionStub


class DeterministicStubTests(unittest.TestCase):
    def setUp(self):
        self.config = StubConfig(cnn_class=ElementaryLesionClass.PLAQUE)
        self.image = ClinicalImage.create("simulada.png", "upload", 100, "hash")

    def test_yolo_returns_configured_box_and_linked_crop(self):
        result = YoloDetectionStub(self.config).detect(self.image)
        self.assertTrue(result.success)
        self.assertEqual(result.bounding_box, self.config.detection_box)
        self.assertEqual(result.detected_class, "lesão")
        self.assertEqual(result.cropped_image.parent_image_id, self.image.image_id)

    def test_focus_returns_configured_internal_values(self):
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        result = FocusEvaluationStub(self.config).evaluate(crop)
        self.assertEqual(result.score, 0.82)
        self.assertEqual(result.status.value, "adequada")

    def test_cnn_returns_fixed_class_and_synthetic_examples(self):
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        result = CNNClassificationStub(self.config).classify(crop)
        self.assertEqual(result.suggested_class, ElementaryLesionClass.PLAQUE)
        self.assertGreaterEqual(len(result.example_descriptions), 2)
        self.assertTrue(
            all("SIMULADO" in item for item in result.example_descriptions)
        )

    def test_questionnaires_are_specific_and_explicitly_simulated(self):
        questionnaire = QuestionnaireStub()
        prompts_by_class = {
            lesion_class: tuple(
                question.prompt
                for question in questionnaire.questions_for(lesion_class)
            )
            for lesion_class in ElementaryLesionClass
        }
        self.assertEqual(len(set(prompts_by_class.values())), 6)
        self.assertTrue(
            all(
                "PERGUNTA SIMULADA" in prompt
                for prompts in prompts_by_class.values()
                for prompt in prompts
            )
        )

    def test_registry_contains_one_concrete_stub_per_class(self):
        registry = build_multimodal_registry(StubConfig())
        self.assertEqual(
            {type(stub) for stub in registry.values()},
            {
                PapuleNoduleMultimodalStub,
                MaculeSpotMultimodalStub,
                VesicleBullaMultimodalStub,
                ErosionMultimodalStub,
                UlcerMultimodalStub,
                PlaqueMultimodalStub,
            },
        )

    def test_each_multimodal_stub_returns_configured_enum_risk(self):
        registry = build_multimodal_registry(
            StubConfig(final_risk=CancerRiskClass.HIGH)
        )
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        for lesion_class, stub in registry.items():
            with self.subTest(lesion_class=lesion_class):
                answers = QuestionnaireAnswers(
                    lesion_class, {"tempo_evolucao": "Resposta simulada"}
                )
                result = stub.analyze(crop, lesion_class, answers)
                self.assertIs(result.risk, CancerRiskClass.HIGH)
                self.assertEqual(result.lesion_class, lesion_class)

    def test_intelligent_system_marks_feedback_for_human_curatorship(self):
        system = IntelligentSystemStub()
        crop = YoloDetectionStub(self.config).detect(self.image).cropped_image
        events = system.register_manual_crop(self.image, crop)
        self.assertEqual(len(events), 2)
        self.assertTrue(all(event.requires_curator_review for event in events))
        self.assertTrue(any(event.retraining_candidate for event in events))
        self.assertTrue(
            all(
                "não incorporado automaticamente" in event.details["observacao"]
                for event in events
            )
        )


if __name__ == "__main__":
    unittest.main()
