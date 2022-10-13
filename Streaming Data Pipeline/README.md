# Building a Realtime, Streaming, Functional Data Pipeline

We are going to build a data pipeline that using AWS Kinesis to take in Realtime sensor data and trigger AWS Lambda function to put data into AWS DynamoDB.

![Screen Shot 2022-10-13 at 12 11 05 PM](https://user-images.githubusercontent.com/102097656/195649536-730b6989-e640-4262-bb62-50ce33cf12eb.png)

## 1. Creating a DynamoDB table with JSON specification
```bash
$ aws dynamodb create-table \
  --cli-input-json file://sensor-data-table.json
```
The ```sensor-data-table.json``` JSON spec should be found in DynamoDB fold in this repo

## 2. Creating a Kinesis Stream
```bash
$ export STREAM_NAME=temperature-sensor-data
$ aws kinesis create-stream \
  --stream-name ${STREAM_NAME} \
  --shard-count 1
$ aws kinesis describe-stream \
  --stream-name ${STREAM_NAME}
$ export KINESIS_STREAM_ARN=....
```
Export kinesis stream arn as it returned.

### 3. Creating Lambda function

Before we can stitch Kinesis and Lambda together, however, we need to create an AWS security role that enables us to do that. Role management in AWS is handled by a service called Identity and Access Management, or IAM. The following set of commands will:
- Create the role using a JSON document that you can peruse in the lambda- kinesis-role.json file.
- Attach a policy to that role that will enable Kinesis to pass data to Lambda.
- Store the ARN for this role in an environment variable.


```bash
$ export IAM_ROLE_NAME=kinesis-lambda-dynamodb
$ aws iam create-role \
  --role-name ${IAM_ROLE_NAME} \
  --assume-role-policy-document file://lambda-kinesis-role.json
$ aws iam attach-role-policy \
  --role-name ${IAM_ROLE_NAME} \
  --policy-arn \
    arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole
$ aws iam attach-role-policy \
  --role-name ${IAM_ROLE_NAME} \
  --policy-arn \
    arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
$ aws iam get-role --role-name ${IAM_ROLE_NAME}
$ export ROLE_ARN=arn:aws:iam::...:role/kinesis-lambda-dynamodb
```
Replace ... with the ARN returned, ```lambda-kinesis-role.json``` could be found in Lambda fold.

Our Lambda Function should act to meet following requirements:

- The event object contains the data that has been passed to the function, in our case the JSON object written to Kinesis.
- The context object holds information about the environment in which the function is running.
- The callback object signals that the operation is finished. If called with a single argument, that means that the function returns an error; if called with null and a string, then the function is deemed successful and the string represents the success message.

```bash
$ zip ProcessKinesisRecords.zip ProcessKinesisRecords.js
$ aws lambda create-function \
  --region us-east-1 \
  --function-name ProcessKinesisRecords \
  --zip-file fileb://ProcessKinesisRecords.zip \
  --role ${ROLE_ARN} \
  --handler ProcessKinesisRecords.kinesisHandler \
  --runtime nodejs16.x
```

The ```ProcessKinesisRecords.js``` policy document could be found in Lambda fold.

## 4. Creating Lambda function source mapping and test it
What’s missing now is that Kinesis isn’t yet able to trigger and pass data to our Lambda function. For that, we need to create a source mapping that tells AWS that we want our iot- temperature-data to trigger our ```ProcessKinesisRecords``` Lambda function whenever a record passes into the stream.

```bash
$ aws lambda create-event-source-mapping \
  --function-name ProcessKinesisRecords \
  --event-source-arn ${KINESIS_STREAM_ARN} \
  --starting-position LATEST
$ aws lambda list-event-source-mappings
```
Note that the ```aws lambda invoke``` function in AWS CLI does not work, and use the contents of ```test-lambda-input.txt``` to test the function. ```test-lambda-input.txt``` could be found in Lambda fold.

Once test successes, you should get a record in DynamoDB that says: (sensor-1, 123456789, 99.9) for (SensorId, CurrentTime, Temperature). Check it in the DynamoDB management console.

At this point, the pipeline is in place. Records that are written to the temperature- sensor-stream stream in Kinesis will be processed by a Lambda function, which will write the results to the SensorData table in DynamoDB. Just to be sure, let’s put a record to the stream and see what happens:

```bash
$ export DATA=$( echo '{
    "sensor_id":"sensor-2",
    "temperature":88.8,"current_time":987654321
  }' | base64)
$ aws kinesis put-record \
  --stream-name ${STREAM_NAME} \
  --partition-key sensor-data \
  --data ${DATA}
$ aws dynamodb scan --table-name SensorData

```
There should return 2 record of JSON object with a ```ShardID``` and ```SequenceNumber``` from DynamoDB.

![Screen Shot 2022-10-13 at 12 22 00 PM](https://user-images.githubusercontent.com/102097656/195652020-7190c357-687e-495d-ade4-c7056f75ec71.png)
