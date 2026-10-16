"""Utilitários locais para abrir o protótipo em celulares na mesma rede."""

from __future__ import annotations

from io import BytesIO
from urllib.parse import urlsplit

import qrcode


def build_mobile_url(host: str, port: int = 8501) -> str:
    """Monta um endereço HTTP simples sem aceitar caminho ou esquema no host."""

    normalized_host = host.strip()
    if (
        not normalized_host
        or any(character in normalized_host for character in "/?#@")
        or "://" in normalized_host
        or not 1 <= port <= 65535
    ):
        raise ValueError("Endereço ou porta inválidos para acesso móvel.")
    url = f"http://{normalized_host}:{port}"
    parsed = urlsplit(url)
    if parsed.hostname is None or parsed.port != port:
        raise ValueError("Endereço inválido para acesso móvel.")
    return url


def make_qr_png(url: str) -> bytes:
    """Gera em memória um QR PNG; nenhum endereço é enviado a serviço externo."""

    parsed = urlsplit(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("Informe um endereço HTTP ou HTTPS válido.")
    qr = qrcode.QRCode(version=None, box_size=8, border=3)
    qr.add_data(url)
    qr.make(fit=True)
    image = qr.make_image(fill_color="black", back_color="white")
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    return buffered.getvalue()
