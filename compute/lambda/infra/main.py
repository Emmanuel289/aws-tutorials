import json
import urllib.parse
import boto3

print('Loading function')

s3 = boto3.client('s3') # Create an S3 client

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event, indent=2)}")

    # Get the object from the event and show its content type.
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        content_type = response['ContentType']
        content = response['Body'].read().decode('utf-8')
        print(f"CONTENT TYPE: {content_type}")
        print(f"CONTENT: {content}")
        return content_type
    except Exception as e:
        print(e)
        print(f"Error getting object {key} from {bucket}. Make sure they " 
              "exist and your bucket is in the same region as this function.")