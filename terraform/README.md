# Terraform assignment

Welcome to the Terraform assignment. In this assignment we kindly ask you to provision
some AWS resources by using Terraform. To be independent of any AWS accounts, we've prepared
a docker-compose configuration that will start the [localstack](https://github.com/localstack) 
AWS cloud stack on your machine. Terraform is already fully configured to work together with 
localstack. Please see the usage section on how to authenticate.

# Assignment

![Assignment](assignment.drawio.png)

The practical use of the assignment shouldn't be questioned :-)

We'd like to track a list of files that have been uploaded. For this we require:
- A S3 Bucket to where we upload files
- A DynamoDb table called `Files` with an attribute `FileName`
- A Stepfunction that writes to the DynamoDb table
- A Lambda that get's triggered after a file upload and then executes the stepfunction.

# Usage

## Start localstack

```shell
docker-compose up
```

Watch the logs for `Execution of "preload_services" took 986.95ms`

## Authentication
```shell
export AWS_ACCESS_KEY_ID=foobar
export AWS_SECRET_ACCESS_KEY=foobar
export AWS_REGION=eu-central-1
```

## AWS CLI examples
### S3
```shell
aws --endpoint-url http://localhost:4566 s3 cp README.md s3://test-bucket/
```

## StepFunctions
```shell
aws --endpoint-url http://localhost:4566 stepfunctions list-state-machines
```

## DynamoDb

```shell
aws --endpoint-url http://localhost:4566 dynamodb scan --table-name Files
```

## Solution
### Terraform
I have used terraform to create the resources. The terraform code is in the terraform folder.
```shell
cd terraform #(or assuming you are already in the terraform folder)
terraform init #(i have used a local backend, so you don't need to configure a remote backend. However, in a real world scenario, you should use a remote backend. I put a reference to a s3 backend in the backend)
terraform plan
terraform apply -auto-approve
```
Then you can upload a file to the bucket and check the dynamodb table to see if the file name is there.
```shell
aws --endpoint-url http://localhost:4566 s3 cp README.md s3://my-upload-bucket/
```
Response:
```text
upload: ./README.md to s3://my-upload-bucket/README.md
```
```shell
aws --endpoint-url http://localhost:4566 dynamodb scan --table-name Files
```
Response:
```json
{
    "Items": [
        {
            "FileName": {
                "S": "README.md"
            }
        }
    ],
    "Count": 1,
    "ScannedCount": 1,
    "ConsumedCapacity": null
}
```




## Terratest
I have included an example of how to use terratest to test the terraform code.
```shell
cd tests
go test -v -timeout 30m

Note: the local stack should be running, however the step functions need the PROVIDER_OVERRIDE_STEPFUNCTIONS=v2 environment variable to be set as some operations are not supported in localstack v1 (ListStateMachineVersions for example)
Also the test fail when the stack is getting destroyed, there seems to be some issue in the localstack implementation (there are many issues on github)
```