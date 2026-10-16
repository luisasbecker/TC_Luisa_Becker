import os
import unittest
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

from PIL import Image
from streamlit.testing.v1 import AppTest

from src.ui.image_preparation import prepare_image_for_session
from src.ui.mobile_access import build_mobile_url, make_qr_png


class ImagePreparationTests(unittest.TestCase):
    def test_applies_iphone_exif_orientation_and_removes_metadata(self):
        source = Image.new("RGB", (40, 20), "red")
        exif = source.getexif()
        exif[274] = 6
        buffered = BytesIO()
        source.save(buffered, format="JPEG", exif=exif)

        prepared = prepare_image_for_session(buffered.getvalue(), max_dimension=2560)

        self.assertEqual((prepared.width, prepared.height), (20, 40))
        self.assertTrue(prepared.orientation_corrected)
        with Image.open(BytesIO(prepared.data)) as decoded:
            self.assertEqual(decoded.getexif().get(274), None)

    def test_limits_large_image_while_preserving_aspect_ratio(self):
        source = Image.new("RGB", (4000, 2000), "blue")
        buffered = BytesIO()
        source.save(buffered, format="JPEG")

        prepared = prepare_image_for_session(buffered.getvalue(), max_dimension=1000)

        self.assertEqual((prepared.width, prepared.height), (1000, 500))
        self.assertTrue(prepared.resized)

    def test_keeps_small_image_dimensions(self):
        source = Image.new("RGBA", (320, 240), (0, 128, 255, 128))
        buffered = BytesIO()
        source.save(buffered, format="PNG")

        prepared = prepare_image_for_session(buffered.getvalue(), max_dimension=1000)

        self.assertEqual((prepared.width, prepared.height), (320, 240))
        self.assertFalse(prepared.resized)
        self.assertEqual(prepared.output_format, "PNG")


class MobileAccessTests(unittest.TestCase):
    def test_builds_lan_address(self):
        self.assertEqual(
            build_mobile_url("192.168.15.6", 8501),
            "http://192.168.15.6:8501",
        )

    def test_rejects_invalid_mobile_address(self):
        for host, port in (("", 8501), ("192.168.1.2/path", 8501), ("host", 0)):
            with self.subTest(host=host, port=port), self.assertRaises(ValueError):
                build_mobile_url(host, port)

    def test_qr_is_a_valid_png_generated_locally(self):
        data = make_qr_png("http://192.168.15.6:8501")

        self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
        with Image.open(BytesIO(data)) as qr:
            self.assertEqual(qr.format, "PNG")
            self.assertGreaterEqual(qr.width, 100)
            self.assertEqual(qr.width, qr.height)


class TouchCropperTests(unittest.TestCase):
    def test_cropper_declares_mobile_touch_target_and_page_scroll(self):
        html = Path("src/ui/cropper/index.html").read_text(encoding="utf-8")

        self.assertIn("--touch-target: 44px", html)
        self.assertIn("touch-action: pan-y", html)


class MobileInterfaceIntegrationTests(unittest.TestCase):
    @patch.dict(
        os.environ,
        {"PIPELINE_MOBILE_URL": "http://192.168.15.6:8501"},
        clear=False,
    )
    def test_app_uses_provisional_name_and_renders_mobile_access(self):
        app_path = Path(__file__).resolve().parents[1] / "app.py"
        app = AppTest.from_file(str(app_path)).run(timeout=15)

        self.assertEqual(list(app.exception), [])
        self.assertEqual(app.title[0].value, "Pipeline Bucal")
        self.assertIn(
            "Acesso no celular",
            [item.value for item in app.sidebar.subheader],
        )


class MobileLauncherAssetsTests(unittest.TestCase):
    def test_windows_launcher_and_presentation_guide_are_complete(self):
        root = Path(__file__).resolve().parents[1]
        batch = root / "INICIAR_PIPELINE_MOBILE.bat"
        script = root / "scripts" / "iniciar_pipeline_mobile.ps1"
        guide = root / "GUIA_APRESENTACAO_MOBILE.md"

        self.assertTrue(batch.is_file())
        self.assertTrue(script.is_file())
        self.assertTrue(guide.is_file())
        batch_text = batch.read_text(encoding="utf-8")
        script_text = script.read_text(encoding="utf-8")
        guide_text = guide.read_text(encoding="utf-8")
        self.assertIn("iniciar_pipeline_mobile.ps1", batch_text)
        self.assertIn("--server.address", script_text)
        self.assertIn("0.0.0.0", script_text)
        self.assertIn("PIPELINE_MOBILE_URL", script_text)
        self.assertIn("Get-NetIPConfiguration", script_text)
        self.assertIn('$ErrorActionPreference = "Continue"', script_text)
        self.assertIn("/_stcore/health", script_text)
        self.assertIn('Read-Host "Pressione ENTER', script_text)
        self.assertNotIn("O Streamlit foi encerrado com erro", script_text)
        self.assertIn("Hotspot móvel", guide_text)
        self.assertIn("Adicionar à Tela de Início", guide_text)
        self.assertIn("pressione `Enter`", guide_text)
        self.assertIn("INICIAR_PIPELINE_MOBILE.bat", guide_text)


if __name__ == "__main__":
    unittest.main()
