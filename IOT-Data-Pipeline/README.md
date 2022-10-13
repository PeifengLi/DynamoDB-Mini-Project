# IOT Data Pipeline Around DynamoDB

DynamoDB is a good choice for an IoT database because it’s built to handle not just huge data sets but data sets whose size can’t be determined in advanced. The downside of DynamoDB, as we discussed before, is that it isn’t built for complex queries of the type you’d be able to run on a relational database. For our needs here, though, DynamoDB’s “key-value plus” querying system will do just fine. Our tables will be fairly simple, and range queries will enable us to use DynamoDB as a powerful timeseries database. Any processing logic we need to apply beyond this can happen on the application side if we need it to.

![Screen Shot 2022-10-13 at 12 32 56 PM](https://user-images.githubusercontent.com/102097656/195654001-fdf316f3-0a1d-402b-9822-604cde97b46e.png)

Amazon’s Data Pipeline service enables you to create batch jobs that efficiently move data between Amazon services (including S3, the Redshift data ware- housing service, and many more). You can write your own pipeline logic from scratch or you can use a template for ease of use. Fortunately for us, there’s a predefined Export DynamoDB table to S3 pipeline definition that will make this very simple. Ultimately, our streaming pipeline plus querying interface will look like the architecture in the figure that follows.

## 1. Mock Data Inputs

We’ll use a Ruby script that auto-generates temper- ature data and writes that data to our data pipeline as JSON. First install nessesary gems:

```bash
$ gem install random-walk aws-sdk
```

To make the temp-sensor-1 sensor write 1,000 times to the pipeline:

```bash
$ ruby upload-sensor-data.rb temp-sensor-1 1000
```

Or write 1,000 sensor readings each for 10 sensors labeled sensor-1, sensor-2, and so on.

```bash
$ for n in {1..10}; do
    ruby upload-sensor-data.rb sensor-${n} 1000 &
  done
```

Shut down all the running mock sensors at any time:

```bash
$ pgrep -f upload-sensor-data | xargs kill -9
```

Now you can see there are sensor data you just generate in your DynamoDB table.

## 2. An SQL Quering Interface

### 2.1 Create a new S3 Bucket

Create a new S3 bucket to store JSON data from the $SensorData$ table in DynamoDB. You can call this bucket whatever you’d like, so long as it’s globally unique. 

```bash
$ export BUCKET_NAME=s3://sensor-data-$USER
$ aws s3 mb ${BUCKET_NAME}
```

*Note: Also create a bucket for the DynamoDB data and a bucket for the execution logs.*

### 2.2 Setting up IAM Roles and Policy for AWS Data Pipeline
According to the [guide](https://docs.aws.amazon.com/datapipeline/latest/DeveloperGuide/dp-iam-roles.html.Links to an external site.), go to this link and follow the directions for creating the roles manually.  Here is a description:

#### Setting up Policy
- Navigate into IAM Management Console and click into policy
- Use the file ```SensorDataPipelinePolicy.json``` as a template. Change the resource identifier starting with ```arn:aws:iam::``` to include your account number. There are two instances of this prefix. Change the resource identifier starting with ```arn:aws:s3:::```  to include your S3 bucket name. Also change the resource identifier starting with ```arn:aws:dynamodb:``` to include your account number assuming you used the same ```SensorData``` Table Name. Then, to the IAM console and create a policy called $SensorDataPipelinePolicy$.  You can paste the policy you just edited into the window for creating the policy with JSON.
- Use the file ```SensorDataPipelineResourcePolicy.json``` to create the $SensorDataPipelineResourcePolicy$.

#### Creating Roles
- Create the role $SensorDataPipelineRole$ choosing usecase as *Data Pipeline* and attach the $SensorDataPipelinePolicy$ to the role and also attach the $AWSDataPipelineRole$ to this role.
- Create the role $SensorDataPipelineResourceRole$ and choosing usecase as *EC2* and attach the $SensorDataPipelineResourcePolicy$ to that role.  *Avoid the temptation to add the EC2 Data Pipeline Role to the SensorDataPipelineResourceRole.* The $SensorDataPipelineResourceRole$ must be pure EC2 in order to create the EC2 Instance Profile that you need for the data pipeline.
- Go to the IAM Role Console and create a role for a service.  Pick EMR, and then pick $EMR Cleanup$. The role should be named automatically. If it is not, use the name $AWSServiceRoleForEMRCleanup$.

### 2.3 Creating a New Data Pipeline
- Go to the Data Pipeline in the AWS Management Console and choose Create New Pipeline. Fill in the form according to the following illustration but use your bucket names in the appropriate place.

![Screen Shot 2022-10-13 at 1 01 10 PM](https://user-images.githubusercontent.com/102097656/195659911-5a0b0952-911c-4e4d-8480-1ef9c3a5fdfa.png)

- You will receive a message that the pipeline has warnings. Choose the button to edit the pipeline in Architect. Edit the resources tab to add the termination after parameter according to the next illustration. Add a timeout on the cluster to avoid excessive expenses. The remaining warning can be ignored and you can activate the cluster.

![Step3DataPipelineClusterTermination](https://user-images.githubusercontent.com/102097656/195660143-bc1a6dfe-6365-44c1-ba28-0d1ddc13977f.png)

- IMPORTANT: After a few minutes, go to your output bucket in S3 and delete the ```_SUCCESS``` and the ```Manifest``` files. The remaining file is the data that was exported from Amazon DynamoDB. It is in JSON format. Also you should set up a S3 output bucket before you starting query from Athena.

### 2.4 Querying from Athena

Athena is an AWS service that enables you to query data files stored in S3 using plain SQL queries. We’ll use Athena to get some aggregate metrics out of the data stored in our SensorData table. Go to the Athena console and click on Query Editor. This is the interface that you can use to create tables and run queries. Run this query to create a sensor_data table (substituting the appropriate name for the S3 bucket that you created).

```sql
CREATE EXTERNAL TABLE IF NOT EXISTS sensor_data (
	sensorid    struct<s:string>,
	currenttime struct<n:bigint>,
	temperature struct<n:float>
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
with serdeproperties ('paths' = 'SensorId,CurrentTime,Temperature')
LOCATION 's3://sensor-data-bryton/';
```

Structs will enable us to easily handle this nested JSON data. Second, the ROW FORMAT information simply specifies that we’re querying files storing JSON as well as which JSON fields we’re interested in (SensorId and so on). Finally, the LOCATION points to our S3 bucket (don’t forget the slash at the end).

Now we are setting up a Data Pipeline to retrieve IOT realtime data from DynamoDB.
