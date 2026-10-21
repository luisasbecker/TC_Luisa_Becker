import unittest
from io import BytesIO
from PIL import Image
from src.pipeline import BoundingBox, ClinicalImage, PipelineController, UserDecision
from src.ui.active_image import resolve_active_image


def png(image):
    result = BytesIO()
    image.save(result, format='PNG')
    return result.getvalue()


class ActiveImageTests(unittest.TestCase):
    def test_manual_pixels_survive_every_downstream_stage(self):
        image = Image.new('RGB', (80, 40), 'red')
        image.paste('blue', (40, 0, 80, 40))
        original = png(image)
        controller = PipelineController()
        controller.start_session('sample.png', 'test', len(original), 'test')
        controller.run_detection()
        crop = controller.submit_manual_crop(BoundingBox(40, 0, 80, 40))
        def verify():
            result = resolve_active_image(original, None, controller.state.active_crop)
            self.assertEqual(result.size, (40, 40))
            self.assertEqual(result.getpixel((0, 0)), (0, 0, 255))
        verify()
        self.assertEqual(controller.run_focus_evaluation().image_id, crop.image_id)
        verify()
        controller.validate_visual_quality(UserDecision.ACCEPT)
        self.assertEqual(controller.run_cnn_classification().image_id, crop.image_id)
        controller.record_classification_decision(UserDecision.ACCEPT)
        controller.submit_questionnaire({q.question_id: q.answer_options[0] for q in controller.get_questionnaire()})
        controller.run_multimodal()
        verify()

    def test_corrected_upload_is_not_cropped_again(self):
        c = PipelineController()
        c.start_session('source.png', 'test', 1, 'hash')
        c.run_detection()
        crop = c.submit_manual_crop(corrected_image=ClinicalImage.create('fixed.png', 'test', 1, 'other'))
        result = resolve_active_image(png(Image.new('RGB', (80, 80), 'red')), png(Image.new('RGB', (20, 30), 'blue')), crop)
        self.assertEqual(result.size, (20, 30))
        self.assertEqual(result.getpixel((0, 0)), (0, 0, 255))
        with self.assertRaises(ValueError):
            resolve_active_image(png(Image.new('RGB', (80, 80))), None, crop)
