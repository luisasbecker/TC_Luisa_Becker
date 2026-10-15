import unittest

from src.pipeline.enums import (
    CancerRiskClass,
    ElementaryLesionClass,
    ImageQualityStatus,
    PipelineStep,
)
from src.pipeline.models import BoundingBox, ClinicalImage, CroppedImage, StubConfig
from src.pipeline.state import SessionState


class DomainModelTests(unittest.TestCase):
    def test_defines_exactly_six_elementary_lesion_classes(self):
        self.assertEqual(
            {item.value for item in ElementaryLesionClass},
            {
                "pápula/nódulo",
                "mácula/mancha",
                "vesícula/bolha",
                "erosão",
                "úlcera",
                "placa",
            },
        )

    def test_defines_only_three_non_percentage_risk_classes(self):
        self.assertEqual(
            {item.value for item in CancerRiskClass},
            {
                "risco baixo de câncer",
                "risco médio de câncer",
                "risco alto de câncer",
            },
        )
        self.assertNotIn("%", " ".join(item.value for item in CancerRiskClass))

    def test_bounding_box_rejects_inverted_coordinates(self):
        with self.assertRaisesRegex(ValueError, "coordenadas"):
            BoundingBox(x_min=50, y_min=20, x_max=10, y_max=80)

    def test_image_lineage_is_explicit(self):
        original = ClinicalImage.create("caso-simulado.png", "upload", 1234, "abc")
        crop = CroppedImage.create(
            original=original,
            name="caso-simulado_recorte.png",
            source="yolo_stub",
            bounding_box=BoundingBox(10, 10, 100, 100),
            manual=False,
        )
        self.assertEqual(crop.parent_image_id, original.image_id)
        self.assertFalse(crop.manual)

    def test_session_starts_empty(self):
        state = SessionState()
        self.assertEqual(state.step, PipelineStep.EMPTY)
        self.assertEqual(state.history, [])
        self.assertEqual(state.feedback_events, [])

    def test_stub_configuration_has_fixed_defaults(self):
        config = StubConfig()
        self.assertEqual(config.focus_status, ImageQualityStatus.ADEQUATE)
        self.assertEqual(config.detection_confidence, 0.88)


if __name__ == "__main__":
    unittest.main()
