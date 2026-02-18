# Deploy a serverless app using AWS Lambda and API Gateway

# 1 - Introduction
Many serverless applications use functions-as-a-service to provide application logic, along with specialized services for additional capabilities such as routing HTTP requests, message queuing, and data storage.

In this lab, you will deploy a NodeJS function to AWS Lambda, and then expose that function to the internet using Amazon API Gateway

# Preliminaries
You will need Terraform v1.2+ installed locally, the AWS CLI, and AWS Credentials configured for use with Terraform.
After installing Terraform and the AWS CLI, run the `aws configure` command to configure your AWS environment including setting your `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY`, `Region`, `output_format`, and `profile`.

- Alternatively, you can export the following variables to configure your AWS environment:

```bash
export AWS_ACCESS_KEY_ID=<value>
export AWS_SECRET_ACCESS_KEY=<value>
export AWS_DEFAULT_REGION=<value>
```
- Verify your settins by running `aws configure list`

# 1- Lab Setup
- Create a directory to store your project code and a subdirectory within it to store your terraform files, e.g. 
```bash
mkdir -p lambda-api-gateway && cd lambda-api-gateway
mkdir infra
```
- Navigate to the `infra` directory you created previously and add a `versions.tf` file.

- Copy and paste the following text into the `versions.tf` file
```hcl
terraform {
    
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.32"
        }
    }
}
```
- The code includes a `required_providers` block which targets AWS as the required provider for provisioning the resources in this lab.

- Create a `main.tf` file that defines the AWS provider you will use
for this lab and an S3 bucket which will store your Lambda function.
Copy and paste the below content into the file and update the values:

```hcl
provider "aws" {
  region  = "<region>"
  profile = "<profile>"
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "<bucket>"
  region = "<region>"
}

```

- Initialize the configuration and create the bucket:
```bash
terraform init

terraform plan # Confirm information about the bucket to be created
terraform apply # Confirm the prompt by typing 'yes'
```

# 2-  Create and upload the Lambda function archive
To deploy an AWS lambda function, you must package it in an archive containing the function source code and any dependencies.
The way you build the function code and dependencies will depend on the language and frameworks you choose. In this lab, you will deploy a NodeJS function. 

- Navigate to the project's root and create `app/hello.js` to store your NodeJS code:

```bash
mkdir -p app && cd app 
touch hello.js
```
- Copy and paste the following code into `hello.js`: 

```js

async function handler(event) {
    /*
    This function takes an incoming event object from Lambda  and logs it to the console. It then returns an object which API Gateway will use to generate an HTTP response.
    */
    console.log('Event', event);
    let responseMessage = 'Hello, World!';

    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: responseMessage,
        })
    }

}

module.exports = { handler }
```
The function receives an event object from Lambda and logs it to the console. Then it returns an object which API Gateway will use to generate an HTTP response.

- Add the following configuration to `main.tf` to package and copy the function to your S3 bucket:

```hcl
data "archive_file" "lambda_app" {
  type = "zip"

  source_dir  = "../${path.module}/app"
  output_path = "../${path.module}/app.zip"
}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "app.zip"
  source = data.archive_file.lambda_app.output_path
  etag   = filemd5(data.archive_file.lambda_app.output_path)
}
```
The configuration uses the `archive_file` data source to generate a zip archive and an `aws_s3_object` resource to upload the archive to your S3 bucket. It also applies an md5 checksum of the archive content as a tag via the `etag` attribute.

- Run `terraform apply` to create the bucket object and confirm the object has been created in the bucket using `aws s3 ls s3://<bucket-name>`

# 3- Create the Lambda function
- Add the following to `main.tf` to define your Lambda function and related resources.
```hcl
resource "aws_lambda_function" "app" {
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_app.key

  runtime = "nodejs20.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_app.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/aws/lambda/${aws_lambda_function.lambda_app.function_name}"

  retention_in_days = 30
}


data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```
- `aws_lambda_function.app` configures the Lambda function to use the bucket object containing your function code. It also sets the runtime to NodeJS, and assigns the handler to the `handler` function defined in `hello.js`. The resource also specifies a role which grants the function permission to access AWS services and resources in your account.

- `aws_cloudwatch_log_group.app` defines a log group to store log messages from your Lambda function for 30 days. By convention, Lambda stores logs in a group with the name `/aws/lambda/<function-name>`.

- `aws_iam_role.lambda_exec` defines an IAM role that allows Lambda to acces resources in your AWS account

- `aws_iam_policy_document` defines the policy that's associated with the IAM role

- `aws_iam_role_policy_attachment.lambda_policy` attaches a policy to the IAM role. The `AWSLambdaExecutionRole` is an AWS managed policy that allows your Lambda function to write to CloudWatch logs.

- Create an `outputs.tf` file in your terraform subdirectory and add the following to the file to create an output value for your lambda function

```hcl
output "function_name" {
    description = "Name of the Lambda function."
    value = aws.lambda_function.app.function_name
}
```

- Run `terraform apply` and confirm the prompt to create the Lambda function and associated resources.

- After creating the function, invoke it using the AWS CLI.
```bash
aws lambda invoke --region=<region> --function-name=$(terraform output --raw function_name) response.json
```
- Check the contents of `response.json` to confirm that the function is working as expected.
```bash
cat response.json
{
    "statusCode" : 200,
    "headers": {
        "Content-Type": "application/json"
    },
    ...
}
```

# 4-  Create an HTTP API with API Gateway
API Gateway is a managed service that allows you to create and manage HTTP or WebSocket APIs. It supports integration with AWS Lambda functions, allowing you to implement an HTTP API using Lambda functions to handle and respond to HTTP requests.

- Create a new file named `gateway.tf` and add the following to configure an API Gateway:

```hcl
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "app" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.lambda_app.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "app" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

```


This configuration defines four API Gateway resources, and two additional resources:

`aws_apigatewayv2_api.lambda` defines a name for the API Gateway and sets its protocol to HTTP.

`aws_apigatewayv2_stage.lambda` sets up application stages for the API Gateway - such as "Test", "Staging", and "Production". The example configuration defines a single stage, with access logging enabled.

`aws_apigatewayv2_integration.app` configures the API Gateway to use your Lambda function.

`aws_apigatewayv2_route.app` maps an HTTP request to a target, in this case your Lambda function. In the example configuration, the route_key matches any `GET` request matching the path `/hello`. A target matching `integrations/<ID>` maps to a Lambda integration with the given ID.

`aws_cloudwatch_log_group.api_gw` defines a log group to store access logs for the `aws_apigatewayv2_stage.lambda` API Gateway stage.

`aws_lambda_permission.api_gw` gives API Gateway permission to invoke your Lambda function.

- The API Gateway stage will publish your API to a URL managed by AWS. Add an output value for this URL to `outputs.tf`.

```hcl
output "base_url" {
  description = "Base URL for API Gateway stage"

  value = aws_apigatewayv2_stage.lambda.invoke_url
}
```

- Run `terraform apply` to create the API Gateway and other resources.
- Test the API Gateway by sending a request to the url to invoke the Lambda function. The url consists of the `base_url` output value and the `/hello` path which you defined as the `route_key`

```bash
curl "$(terraform output -raw base_url)/hello"
{
    "message": "Hello, World!"
}
```

# 5- Update your Lambda function
When you call Lambda functions via API Gateway's proxy integration, API Gateway passes the request information to your function via the event object. You can use information about the request in your function code.

- Now, use an HTTP query parameter in your function. In `app/hello.js`, add an if statement to replace the responseMessage if the request includes a Name query parameter

```js
module.exports.handler = async (event) => {
  console.log('Event: ', event)
  let responseMessage = 'Hello, World!';
  // Check if the request includes a Name query parameter
  if (event.queryStringParameters && event.queryStringParameters['Name']) {
    responseMessage = 'Hello, ' + event.queryStringParameters['Name'] + '!';
  }

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: responseMessage,
    }),
  }
}
```

- Apply the change by executing `terraform apply`.
- Send another request to the function, including the `Name` query parameter
```bash
curl -X GET "$(terraform output -r base_url)/hello?Name=Terraform"
{
    "message": "Hello, Terraform!"
}
```
# 6- Clean up your infrastructure
Clean up the infrastructure you created by running the `terraform destroy` command and confirming at the prompt.

# 7- IaC
For reference, the IaC configuration for this lab can be found in the [infra](./lambda-api-gateway/infra/) directory