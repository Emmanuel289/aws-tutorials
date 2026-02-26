#!/usr/bin/env bash

BASE_URL="https://xxxx.execute-api.<region>.amazonaws.com/dev"
FILE_NAME="random-pic.jpg"
FILE_PATH="assets/${FILE_NAME}"

# Ensure file exists
if [[ ! -f "$FILE_PATH" ]]; then
  echo "❌ File not found: $FILE_PATH"
fi

echo "Generate presigned URL..."
RESPONSE=$(curl -s -f -X POST "$BASE_URL/upload-url" \
  -H "Content-Type: application/json" \
  -d "{\"filename\": \"$FILE_NAME\"}")

if [[ -z "$RESPONSE" ]]; then
  echo "❌ Failed to generate presigned URL"
fi

UPLOAD_URL=$(echo "$RESPONSE" | jq -r '.upload_url')
if [[ -z "$UPLOAD_URL" || "$UPLOAD_URL" == "null" ]]; then
  echo "❌ upload_url missing in response"
  echo "Response was: $RESPONSE"
fi

echo "Uploading image..."
curl -f -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --data-binary @"$FILE_PATH"

echo "✅ Upload successful"


echo "Analyzing the uploaded image..."
IMAGE_KEY=$(echo "$RESPONSE" | jq -r '.key')
ANALYZE_PAYLOAD=$(jq -n --arg key "$IMAGE_KEY" '{key: $key}')

curl -X POST "$BASE_URL/analyze" \
  -H "Content-Type: application/json" \
  -d "$ANALYZE_PAYLOAD"