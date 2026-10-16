"""Preparação local e determinística de imagens para a interface móvel."""

from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO

from PIL import Image, ImageOps


MAX_IMAGE_DIMENSION = 2560
EXIF_ORIENTATION_TAG = 274


@dataclass(frozen=True)
class PreparedImage:
    """Cópia sem metadados, orientada e dimensionada para a sessão."""

    data: bytes
    width: int
    height: int
    original_width: int
    original_height: int
    resized: bool
    orientation_corrected: bool
    output_format: str


def prepare_image_for_session(
    raw: bytes, *, max_dimension: int = MAX_IMAGE_DIMENSION
) -> PreparedImage:
    """Normaliza uma imagem sem persistir os bytes ou executar análise clínica.

    A orientação EXIF é aplicada antes do redimensionamento. A regravação remove
    metadados do arquivo e limita o custo das visualizações no navegador móvel.
    """

    if max_dimension < 1:
        raise ValueError("A dimensão máxima deve ser positiva.")

    with Image.open(BytesIO(raw)) as source:
        source.load()
        original_width, original_height = source.size
        orientation = source.getexif().get(EXIF_ORIENTATION_TAG)
        image = ImageOps.exif_transpose(source)

    orientation_corrected = orientation not in (None, 1)
    before_resize = image.size
    image.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
    resized = image.size != before_resize

    has_alpha = image.mode in {"RGBA", "LA"} or (
        image.mode == "P" and "transparency" in image.info
    )
    buffered = BytesIO()
    if has_alpha:
        image = image.convert("RGBA")
        output_format = "PNG"
        image.save(buffered, format=output_format, optimize=True)
    else:
        image = image.convert("RGB")
        output_format = "JPEG"
        image.save(buffered, format=output_format, quality=92, optimize=True)

    return PreparedImage(
        data=buffered.getvalue(),
        width=image.width,
        height=image.height,
        original_width=original_width,
        original_height=original_height,
        resized=resized,
        orientation_corrected=orientation_corrected,
        output_format=output_format,
    )
