from fastapi import UploadFile
from PIL import Image
from io import BytesIO

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
}
MIN_DIMENSION = 224
MAX_PIXELS = 20_000_000


def _has_valid_signature(contents: bytes, content_type: str | None) -> bool:
    signatures = {
        "image/jpeg": (b"\xff\xd8\xff",),
        "image/png": (b"\x89PNG\r\n\x1a\n",),
        "image/webp": (b"RIFF",),
    }
    expected = signatures.get(content_type or "")
    if not expected or not any(contents.startswith(prefix) for prefix in expected):
        return False
    return content_type != "image/webp" or contents[8:12] == b"WEBP"


def validate_image(file: UploadFile, max_size_mb: int = 5) -> list[str]:
    errors: list[str] = []

    ext = get_extension(file.filename)
    if ext not in ALLOWED_EXTENSIONS:
        errors.append(f"Unsupported file extension '{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}")

    if file.content_type and file.content_type not in ALLOWED_MIME_TYPES:
        errors.append(f"Unsupported MIME type '{file.content_type}'. Allowed: {', '.join(sorted(ALLOWED_MIME_TYPES))}")

    max_bytes = max_size_mb * 1024 * 1024
    file.file.seek(0, 2)
    size = file.file.tell()
    file.file.seek(0)
    if size > max_bytes:
        errors.append(f"File size exceeds {max_size_mb} MB limit")

    if not errors:
        try:
            contents = file.file.read()
            if not _has_valid_signature(contents, file.content_type):
                errors.append("Image content does not match its declared format")
                return errors
            img = Image.open(BytesIO(contents))
            if img.width * img.height > MAX_PIXELS:
                errors.append("Image dimensions are too large")
            if img.width < MIN_DIMENSION or img.height < MIN_DIMENSION:
                errors.append(f"Image dimensions must be at least {MIN_DIMENSION}x{MIN_DIMENSION} pixels")
            file.file.seek(0)
        except Exception:
            errors.append("Unable to decode image file")

    return errors


def get_extension(filename: str | None) -> str:
    if not filename:
        return ""
    idx = filename.rfind(".")
    return filename[idx:].lower() if idx != -1 else ""
