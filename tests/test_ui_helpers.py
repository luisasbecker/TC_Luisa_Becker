import unittest

from src.pipeline import (
    CancerRiskClass,
    ElementaryLesionClass,
    ImageQualityStatus,
)
from src.pipeline.ui_helpers import build_stub_config, clamp_box_to_image


class UIHelperTests(unittest.TestCase):
    def test_clamp_box_to_image_keeps_a_valid_visible_rectangle(self):
        self.assertEqual(
            clamp_box_to_image((-20, 30, 900, 700), width=640, height=480),
            (0, 30, 640, 480),
        )
        self.assertEqual(
            clamp_box_to_image((700, 700, 800, 900), width=640, height=480),
            (639, 479, 640, 480),
        )

    def test_build_stub_config_preserves_sidebar_choices(self):
        config = build_stub_config(
            detection_success=False,
            detection_box=(1, 2, 101, 202),
            detection_confidence=0.52,
            focus_score=0.31,
            focus_status=ImageQualityStatus.INADEQUATE,
            cnn_class=ElementaryLesionClass.MACULE_SPOT,
            cnn_confidence=0.64,
            final_risk=CancerRiskClass.HIGH,
        )
        self.assertFalse(config.detection_success)
        self.assertEqual(config.detection_box.as_dict(), {
            "x_min": 1,
            "y_min": 2,
            "x_max": 101,
            "y_max": 202,
        })
        self.assertEqual(config.focus_status, ImageQualityStatus.INADEQUATE)
        self.assertEqual(config.cnn_class, ElementaryLesionClass.MACULE_SPOT)
        self.assertEqual(config.final_risk, CancerRiskClass.HIGH)
