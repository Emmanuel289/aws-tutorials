# Compute Services - Lambda
## Lambda
AWS lambda is an event-driven service that allows developers to write lambda functions that are executed
in response to certain events, e.g., a file upload to S3 or inserting a record to a Dynamo DB database.
AWS lambda allows you to focus solely on your code, while it handles all infrastructure management, enabling faster development, improved performance, enhanced security, and cost efficiency
Lambda functions should typically execute a single task as they have a time limit of 15 minutes.
AWS lambda supports multiple standard runtime environments and programming languages including Java, Go, Powershell, Node.js, Python, etc., as well as custom runtime environments via the runtime API.

## Use cases
- Interactive web and mobile backends: You can build and operate powerful web and mobile backends that deliver uninterrupted service to end users by auto-scaling up and down based on real-time needs. You can enhance the functionalities of your application by easily connecting them to other systems or
modifying components without re-architecting the entire system.

- Batch data processing: AWS lambda is ideal for batch data processing tasks which often require substantial compute and storage resources to handle large volumes of information for short periods. With such workloads, Lambda offers cost-effective, millisecond-billed compute that auto-scales out to meet processing demands and down upon completion, ensuring efficient
resource use and preventing exhaustion. You can focus on building
and analyzing data without needing to be an expert in AWS infrastructure management.

- Real-time data processing: This involves processing continuous data instantly and efficiently to gather analytical insights and drive better user experiences. The volume of streamed or queued data can vary unpredictably based on end-user actions and demands.
AWS Lambda natively integrates with both AWS and third-party real-time data sources, such as SQS, Kinesis, Managed Streaming for Apache Kafka, and Apache Kafka, enabling you to process real-time data without the overhead of managing streaming client libraries or learning specialized data processing frameworks.

- Generative AI: Generative AI is evolving rapidly and this evolution is catayzed by a significant surge in LLMs that meet diverse needs. Organizations are building distributed architectures that leverage specific LLMs based on unique requirements. AWS Lambda is ideal for generative AI applications, enabling you to start small and scale seamlessly while handling distributed, event-driven workflows securely at scale.

## How it works
Below is a simple lambda function that you can run from the AWS console or upload as a zip file via the CLI

```python
def lambda(event, context):
    print(event)
    return 'Hello from lambda'
```
Once you create a lambda function, you can configure it to respond to events from a variety of sources e.g., mobile notifications streaming data, placing a photo in an S3 bucket, etc.
Lambda is able to seamlessly scale up and down to automatically handle your workloads. Plus, you don't pay anything when your code isn't running.

