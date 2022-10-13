# Streaming data pipeline using AWS Kinesis, AWS Lambda, AWS DynamoDB, AWS Data Pipeline, AWS S3 and AWS Athena

DynamoDB is a good choice for an IoT database because it’s built to handle not just huge data sets but data sets whose size can’t be determined in advanced. The downside of DynamoDB, as we discussed before, is that it isn’t built for complex queries of the type you’d be able to run on a relational database. For our needs here, though, DynamoDB’s “key-value plus” querying system will do just fine. Our tables will be fairly simple, and range queries will enable us to use DynamoDB as a powerful timeseries database. Any processing logic we need to apply beyond this can happen on the application side if we need it to.

![Screen Shot 2022-10-13 at 12 32 56 PM](https://user-images.githubusercontent.com/102097656/195654001-fdf316f3-0a1d-402b-9822-604cde97b46e.png)
