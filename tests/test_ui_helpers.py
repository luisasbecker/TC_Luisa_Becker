import unittest

from src.pipeline import (
    CancerRiskClass,
    ElementaryLesionClass,
    ImageQualityStatus,
)
from src.pipeline.ui_helpers import (
    build_stub_config,
    clamp_box_to_image,
    selection_to_box,
)


class UIHelperTests(unittest.TestCase):
    def test_visual_selection_uses_original_image_resolution(self):
        box = selection_to_box(
            {"left": 0.1, "top": 0.2, "right": 0.75, "bottom": 0.8},
            width=4000,
            height=3000,
        )
        self.assertEqual(box.as_dict(), {
            "x_min": 400,
            "y_min": 600,
            "x_max": 3000,
            "y_max": 2400,
        })

    def test_visual_selection_covers_fractional_pixels(self):
        box = selection_to_box(
            {"left": 0.123, "top": 0.234, "right": 0.678, "bottom": 0.789},
            width=100,
            height=100,
        )
        self.assertEqual(box.as_dict(), {
            "x_min": 12,
            "y_min": 23,
            "x_max": 68,
            "y_max": 79,
        })

    def test_visual_selection_is_limited_to_image_bounds(self):
        box = selection_to_box(
            {"left": -0.1, "top": -0.2, "right": 1.2, "bottom": 1.1},
            width=640,
            height=480,
        )
        self.assertEqual(box.as_dict(), {
            "x_min": 0,
            "y_min": 0,
            "x_max": 640,
            "y_max": 480,
        })

    def test_visual_selection_rejects_empty_inverted_or_invalid_rectangles(self):
        for selection in (
            {"left": 0.4, "top": 0.2, "right": 0.4, "bottom": 0.8},
            {"left": 0.8, "top": 0.2, "right": 0.4, "bottom": 0.8},
            {"left": 0.1, "top": 0.8, "right": 0.4, "bottom": 0.2},
            {"left": float("nan"), "top": 0.2, "right": 0.4, "bottom": 0.8},
            {"left": 0.1, "top": 0.2, "right": float("inf"), "bottom": 0.8},
            {"left": "invalid", "top": 0.2, "right": 0.4, "bottom": 0.8},
            {},
        ):
            with self.subTest(selection=selection), self.assertRaises(ValueError):
                selection_to_box(selection, width=640, height=480)

    def test_visual_selection_requires_positive_image_dimensions(self):
        for width, height in ((0, 100), (100, 0), (-1, 100)):
            with self.subTest(width=width, height=height), self.assertRaises(ValueError):
                selection_to_box(
                    {"left": 0, "top": 0, "right": 1, "bottom": 1},
                    width=width,
                    height=height,
                )

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
