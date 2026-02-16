# Create a Simple Web App Using AWS Lambda

## 1 - Objective
Create a simple "Hello World" app with AWS Lambda using a blueprint.

## 2 - Knowledge Gained
- Ability to create a simple web app using a blueprint. Blueprints are pre-packaged code templates that provide skeleton code for a variety of Lambda use cases.

## 3 - Preliminaries
- Install the AWS CLI and configure settings including Access Key ID, Secret Access Key, Region, Output format, and profiles using the AWS configure command.

```bash
aws configure list
```

- Configure AWS environment variables for your user session:

```bash
export AWS_ACCESS_KEY_ID=<value>
export AWS_SECRET_ACCESS_KEY=<value>
export AWS_DEFAULT_REGION=<value>
```

## 4 - Tasks

- Navigate to the AWS Lambda service in the management console.
- Launch the wizard by clicking the "Create function" button.
- There are three ways of creating a function: by authoring from scratch, using a blueprint, or browsing the serverless app repository.
- In this lab, we will use a blueprint. We will use the "s3-get-object-python" function provided by AWS, which is an Amazon S3 trigger that retrieves metadata for the object that has been updated.
- Choose a role that defines the permissions of the function. In this case, create a role that allows the function to read the objects in an S3 bucket. For example:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "s3:GetObject",
			"Resource": "arn:aws:s3:<bucket-name>:*"
		}
	]
}
```

- Create the S3 bucket that serves as the event source. The bucket must be in the same region as the function. For example, create a bucket in ca-central-1 using the AWS CLI:

```bash
aws s3api create-bucket \
  --bucket <bucket-name> \
  --region <region> \
  --create-bucket-configuration LocationConstraint=<region>
```

- The function code should look like the following:

```python
import json
import urllib.parse
import boto3

print('Loading function')

s3 = boto3.client('s3')  # Create an S3 client

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event, indent=2)}")

    # Get the object from the event and show its content type.
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print(f"CONTENT TYPE: {response['ContentType']}")
        return response['ContentType']
    except Exception as e:
        print(e)
        print(f"Error getting object {key} from bucket {bucket}. Make sure they exist and your bucket is in the same region as this function.")
        raise e
```

- Select the event types that you want to trigger the Lambda function, such as all object create events or all object delete events.
- Optional: You can also set up a prefix or suffix for an event.
- Test the function in the console by creating a test event encoded in a JSON file and clicking the 'Test' button. The lambda function accepts the event described in the JSON file and processes the received information. 
The structure of an event JSON is shown below. 

```json
{
  "Records": [
    {
      "eventVersion": "2.0",
      "eventSource": "aws:s3",
      "awsRegion": "<region>", // The name of the region where the lambda and bucket are deployed.
      "eventTime": "1970-01-01T00:00:00.000Z",
      "eventName": "ObjectCreated:Put",
      "userIdentity": {
        "principalId": "EXAMPLE"
      },
      "requestParameters": {
        "sourceIPAddress": "127.0.0.1"
      },
      "responseElements": {
        "x-amz-request-id": "EXAMPLE123456789",
        "x-amz-id-2": "EXAMPLE123/5678abcdefghijklambdaisawesome/mnopqrstuvwxyzABCDEFGH"
      },
      "s3": {
        "s3SchemaVersion": "1.0",
        "configurationId": "testConfigRule",
        "bucket": {
          "name": "<bucket-name>", // The name of the bucket that triggers the lambda function
          "ownerIdentity": {
            "principalId": "EXAMPLE"
          },
          "arn": "arn:aws:s3:::<bucket-name>"
        },
        "object": {
          "key": "<object-name>", // The name of the object that serves as a key in the event's record
          "size": 1024,
          "eTag": "0123456789abcdef0123456789abcdef",
          "sequencer": "0A1B2C3D4E5F678901"
        }
      }
    }
  ]
}
```

**Note:** In the JSON above:
- `"name": "<bucket-name>"` is the name of the bucket that triggers the Lambda function
- `"key": "<object-key>"` is the name of the object that serves as a key in the event's record

## 5 - Cleanup

Delete the Lambda function, the execution role, and the bucket:

```bash
# Delete all objects from the bucket first (required before deleting the bucket)
aws s3 rm s3://<bucket-name> --recursive --region <region>

# Delete the bucket
aws s3api delete-bucket \
    --bucket <bucket-name> \
    --region <region>

# Delete the Lambda function
aws lambda delete-function \
    --function-name <my-lambda-function> \
    --region <region>

# Detach all policies that were attached to the execution role before deleting the role
aws iam detach-role-policy \
    --role-name <my-lambda-execution-role> \
    --policy-arn <policy-arn>

# Delete the execution role
aws iam delete-role --role-name <my-lambda-execution-role>
```
