import json
import os
import boto3
from botocore.exceptions import ClientError
from openai import OpenAI

s3_client = boto3.client("s3")
openai_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

BUCKET_NAME = os.getenv("S3_BUCKET_NAME", "product-scanner-inputs")
PRESIGNED_URL_EXPIRY = 300  # 5 minutes
MODEL = "gpt-5-mini"


# ── Load prompt template ───────────────────────────────────────────────────────
def load_prompt() -> str:
    prompt_path = os.path.join(os.path.dirname(__file__), "prompt.txt")
    with open(prompt_path) as f:
        return f.read()


# ── Generate a pre-signed GET URL for the uploaded image ──────────────────────
def get_presigned_url(key: str) -> str:
    return s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET_NAME, "Key": key},
        ExpiresIn=PRESIGNED_URL_EXPIRY,
    )


# ── Generate a pre-signed PUT URL so the client can upload directly ───────────
def get_upload_url(key: str) -> dict:
    url = s3_client.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET_NAME, "Key": key, "ContentType": "image/jpeg"},
        ExpiresIn=PRESIGNED_URL_EXPIRY,
    )
    return {"upload_url": url, "key": key}


# ── Call GPT-5 with the image and return structured JSON ─────────────────────
def analyze_product(image_url: str) -> dict:
    prompt = load_prompt()

    response = openai_client.responses.create(
        model=MODEL,
        input=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": prompt,
                    },
                    {
                        "type": "input_image",
                        "image_url": image_url
                    }
                ]
            }
        ]
    )

    raw = response.output_text.strip()

    # Strip markdown fences if Chat wraps in ```json ... ```
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()

    return json.loads(raw)


# ── CORS headers ───────────────────────────────────────────────────────────────
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json",
}


def respond(status: int, body: dict) -> dict:
    return {"statusCode": status, "headers": CORS_HEADERS, "body": json.dumps(body)}


# ── Router ─────────────────────────────────────────────────────────────────────
def handler(event, context):
    http_method = event.get("httpMethod", "")
    path = event.get("path", "")

    # Pre-flight
    if http_method == "OPTIONS":
        return respond(200, {})

    # POST /upload-url  →  return a pre-signed PUT URL
    if path == "/upload-url" and http_method == "POST":
        body = json.loads(event.get("body") or "{}")
        filename = body.get("filename", "upload.jpg")
        # Sanitise filename
        safe_name = "".join(c for c in filename if c.isalnum() or c in "._-")
        key = f"uploads/{context.aws_request_id}/{safe_name}"
        return respond(200, get_upload_url(key))

    # POST /analyze  →  analyze an already-uploaded image
    if path == "/analyze" and http_method == "POST":
        body = json.loads(event.get("body") or "{}")
        key = body.get("key")
        if not key:
            return respond(400, {"error": "Missing 'key' in request body"})

        try:
            image_url = get_presigned_url(key)
            result = analyze_product(image_url)
            return respond(200, result)
        except ClientError as e:
            return respond(404, {"error": f"Image not found: {str(e)}"})
        except json.JSONDecodeError as e:
            return respond(502, {"error": f"Claude returned invalid JSON: {str(e)}"})
        except Exception as e:
            return respond(500, {"error": str(e)})

    return respond(404, {"error": "Route not found"})
