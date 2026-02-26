import base64
from pathlib import Path
from typing import List

PROMPT_PATH = Path(__file__).parent / "prompt.txt"

REQUIRED_KEYS = {
    "product_name", 
    "brand", 
    "product_type", 
    "confidence",
    "description", 
    "key_ingredients", 
    "features",
    "skin_types", 
    "similar_products",
}

def load_prompt() -> str:
    if not PROMPT_PATH.exists():
        raise RuntimeError(f"prompt.txt not found at {PROMPT_PATH}")
    return PROMPT_PATH.read_text()


def build_content_from_bytes(image_bytes: bytes, filename: str) -> list:
    """
    Generates the content field for the model input 
    from a filename and the corresponding byte stream.
    """
    file_ext = Path(filename).suffix.lower()
    media_map = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }
    media_type = media_map.get(file_ext, "image/jpeg")

    encoded_str = base64.b64encode(image_bytes).decode()

    return [
        {
            "type": "input_image", 
            "image_url": f"data:{media_type};base64,{encoded_str}"
        },
        {
            "type": "input_text", 
            "text": load_prompt()
        },
    ]


def build_content_from_url(url: str) -> list:
    """
    Generates the content field for the model input
    from a given url.
    """
    return [
        {
            "type": "input_image", 
            "image_url": url
        },
        {
            "type": "input_text", 
            "text": load_prompt()
        },
    ]


def validate_schema(result: dict) -> List[str]:
    """
    Validates the response from a model call
    against a defined schema.
    """
    errors = []

    missing_keys = REQUIRED_KEYS - set(result.keys())
    if missing_keys:
        errors.append(f"Missing keys: {', '.join(missing_keys)}")

    if not isinstance(result.get("key_ingredients"), list) or len(result.get("key_ingredients", [])) < 1:
        errors.append("key_ingredients must be a non-empty list")

    if not isinstance(result.get("similar_products"), list) or len(result.get("similar_products", [])) < 1:
        errors.append("similar_products must be a non-empty list")

    confidence = result.get("confidence", "")
    if confidence not in ("high", "medium", "low"):
        errors.append(f"confidence must be high/medium/low, got: '{confidence}'")

    skin_types = result.get("skin_types", {})
    if not isinstance(skin_types, dict) or "recommended" not in skin_types:
        errors.append("skin_types must be a dict with 'recommended' key")

    return errors