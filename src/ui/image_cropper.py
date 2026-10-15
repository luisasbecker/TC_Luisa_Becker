"""Seletor de recorte local, sem dependências adicionais ou serviços externos."""

import base64
from io import BytesIO
from pathlib import Path

import streamlit.components.v1 as components
from PIL import Image

from src.pipeline.models import BoundingBox
from src.pipeline.ui_helpers import clamp_box_to_image, selection_to_box


_cropper = components.declare_component(
    "image_cropper", path=str(Path(__file__).with_name("cropper"))
)


def image_cropper(
    image: Image.Image, initial_box: BoundingBox, *, key: str
) -> BoundingBox | None:
    """Exibe uma prévia reduzida e devolve o recorte na resolução original."""

    left, top, right, bottom = clamp_box_to_image(
        (initial_box.x_min, initial_box.y_min, initial_box.x_max, initial_box.y_max),
        image.width,
        image.height,
    )
    preview = image.copy()
    preview.thumbnail((1000, 700))
    buffered = BytesIO()
    preview.save(buffered, format="PNG")
    selection = _cropper(
        image_data=(
            "data:image/png;base64,"
            + base64.b64encode(buffered.getvalue()).decode("ascii")
        ),
        image_id=key,
        image_width=image.width,
        image_height=image.height,
        initial_selection={
            "left": left / image.width,
            "top": top / image.height,
            "right": right / image.width,
            "bottom": bottom / image.height,
        },
        key=key,
        default=None,
    )
    if selection is None:
        return None
    return selection_to_box(selection, image.width, image.height)
