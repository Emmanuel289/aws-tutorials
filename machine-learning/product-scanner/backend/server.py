#!/usr/bin/env python3
"""
FastAPI Product Scanner API

Run:
  uvicorn server:app --reload

Environment:
  export OPENAI_API_KEY=...
"""
import logging
import json
import hashlib
import os
from pathlib import Path
from typing import Any, Dict, Optional, Union

from fastapi import Body, File, FastAPI, APIRouter, UploadFile, HTTPException
from pydantic import BaseModel
from openai import OpenAI
from utils import *

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────

MODEL = "gpt-5"
MAX_TOKENS = 102400
CACHE_DIR=Path(__file__).parent/"cache"

if not CACHE_DIR.exists():
    os.mkdir(CACHE_DIR)
logging.basicConfig(
    format="%(levelname)s - %(message)s - %(asctime)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Product Scanner API")
router = APIRouter()

def call_model(content: list) -> Dict[str, Any]:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not set")

    client = OpenAI(api_key=api_key)

    response = client.responses.create(
        model=MODEL,
        input=[{"role": "user", "content": content}]
    )

    raw = response.output_text.strip()

    # Remove markdown fencing if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()

    try:
        result = json.loads(raw)
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=500,
            detail={
                "error": "Model returned invalid JSON",
                "raw_response": raw,
                "exception": str(e),
            },
        )

    usage = response.usage

    cost = (
        (usage.input_tokens / 1_000_000 * 3.0) +
        (usage.output_tokens / 1_000_000 * 15.0)
    )

    return {
        "result": result,
        "usage": {
            "input_tokens": usage.input_tokens,
            "output_tokens": usage.output_tokens,
        },
        "estimated_cost_usd": round(cost, 6),
        "raw": raw,
    }


# ─────────────────────────────────────────────────────────────
# Request Models: Handles both filenames and image urls
# ─────────────────────────────────────────────────────────────

class BaseRequest(BaseModel):
    save_raw_to: Optional[str] = None

class URLRequest(BaseRequest):
    image_url: str

class FileRequest(BaseRequest):
    file: UploadFile


# ─────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────

def get_cache_key(source: str) -> Path:
    """
    Creates a deterministic cache filename
    """
    hashed = hashlib.sha256(source.encode()).hexdigest()
    return CACHE_DIR / f"{hashed}.json"

def check_cache(source: str) -> Optional[dict]:
    cache_file = get_cache_key(source)
    if cache_file.exists() and cache_file.stat().st_size:
        try:
            with open(cache_file) as f:
                return json.loads(f.read())
        except json.JSONDecodeError:
            return None
        
    return None

def update_cache(source: str, response: dict) -> None:
    cache_file = get_cache_key(source)
    with open(cache_file, "w") as f:
        json.dump(response, f)
    
@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/analyze")
async def analyze_product(
    # File upload (multipart/form-data)
    file: Optional[UploadFile] = File(None),
    
    # JSON body (application/json)
    url: Optional[str] = Body(None),

    # Optional raw save path
    save_raw_to: Optional[str] = Body(None),
):
    # Ensure exactly one source is provided
    if (file and url) or not(file or url):
        raise HTTPException(
            status_code=400,
            detail="Provide either a file upload or an image url, not both"
        )
    

    # Handle file mode
    if file:
        source_key = f"file:{file.filename}"
        # Check if a previous call for the file was made
        model_response = check_cache(source_key)
        if not model_response:
            image_bytes = await file.read()
            content = build_content_from_bytes(image_bytes, file.filename)
            model_response = call_model(content)
            # Save the response in the cache
            update_cache(source_key, model_response)
    
    # Handle url mode
    else:
        source_key = f"url:{url}"
        # Check if a previous call for the image url was made
        model_response = check_cache(source_key)
        if not model_response:
            content = build_content_from_url(url)
            model_response = call_model(content)
            # Save the response in the cache
            update_cache(source_key, model_response)
        

    # Get the result from the model call
    result = model_response["result"]
    errors = validate_schema(result)

    if save_raw_to:
        Path(save_raw_to).write_text(model_response["raw"])

    return {
        "data": result,
        "schema_errors": errors,
        "usage": model_response["usage"],
        "estimated_cost_usd": model_response["estimated_cost_usd"],
    }