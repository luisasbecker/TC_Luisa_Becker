"""Resolve pixels from the same crop identity used by the pipeline."""
from io import BytesIO
from PIL import Image
from src.pipeline.models import CroppedImage
from src.pipeline.ui_helpers import clamp_box_to_image


def resolve_active_image(original: bytes, corrected: bytes | None, crop: CroppedImage | None) -> Image.Image:
    raw = original
    if crop is not None and crop.source == 'corrected_upload':
        if corrected is None:
            raise ValueError('A imagem corrigida não está disponível nesta sessão.')
        raw = corrected
    with Image.open(BytesIO(raw)) as source:
        source.load()
        image = source.copy()
    if crop is not None and crop.bounding_box is not None:
        box = crop.bounding_box
        image = image.crop(clamp_box_to_image(
            (box.x_min, box.y_min, box.x_max, box.y_max), image.width, image.height))
    return image
