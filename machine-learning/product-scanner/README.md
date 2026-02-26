# AI Product Scanner — Backend

Serverless API that accepts a product image and returns its description powered by GPT-5.

## Project structure

```
product-scanner/
├── backend/
│   ├── handler.py        # Lambda entry point
│   ├── prompt.txt        # Claude prompt template
│   └── requirements.txt
    └── server.py         # local server testing before deploying
    └── utils.py          # Common utility functions
|    
├── infra/
│   ├── main.tf           # S3 + Lambda + API Gateway
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf/
```

## Prerequisites

- Python 3.11+
- Terraform 1.6+
- AWS CLI configured (`aws configure`)
- OpenAI API key

## Local Testing
- Create a virtual environment and install dependencies.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
```

- Set your `OPENAI_API` key
```bash
export "OPENAI_API_KEY=<key>
```

- Start the local server and test the `analyze` endpoint
```bash 
uvicorn server:app

# Test with an image saved on your machine
curl -X POST http://127.0.0.1:8000/analyze \
  -F "file=@image.jpg"

# Test with a public url
curl -X POST http://127.0.0.1:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{"url":"https://images.unsplash.com/photo-1600185365483-26d7a4cc7519"}'
```

## Deploy to AWS

```bash
cd infra

# Pass your `OPENAI_API_KEY` as an env var (never commit it)
export TF_VAR_openai_api_key="value"

terraform init
terraform plan
terraform apply
```

After apply, Terraform will output your `api_base_url`.

## Test the API

```bash
BASE_URL="https://xxxx.execute-api.<region>.amazonaws.com/dev"

# Get a pre-signed upload URL
curl -X POST $BASE_URL/upload-url \
  -H "Content-Type: application/json" \
  -d '{"filename": "product.jpg"}'

# Upload image directly to S3 (use the URL + key from above)
curl -X PUT "<upload_url>" \
  -H "Content-Type: image/jpeg" \
  --data-binary @product.jpg

# Analyze the uploaded image
curl -X POST $BASE_URL/analyze \
  -H "Content-Type: application/json" \
  -d '{"key": "<key from step 1>"}'
```

## Teardown

```bash
cd infra && terraform destroy
```

## Next steps (after backend is working)

- [ ] Add DynamoDB caching layer (cache by image hash or product name)
- [ ] Add AWS Cognito for user authentication
- [ ] Build the React frontend and deploy to AWS Amplify
- [ ] Move OPENAI_API_KEY to AWS Secrets Manager
- [ ] Add WAF rate limiting to API Gateway
