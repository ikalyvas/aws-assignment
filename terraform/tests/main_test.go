package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    //terratest_aws "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/stretchr/testify/assert"
    "github.com/aws/aws-sdk-go/service/dynamodb"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/aws"
    "os"
)

var ddbSession *dynamodb.DynamoDB
func init(){

sess := session.Must(session.NewSessionWithOptions(session.Options{
    SharedConfigState: session.SharedConfigEnable,
    Config: aws.Config{
        Region: aws.String("eu-central-1"),
        Endpoint: aws.String("http://localhost:4566"),
    },
}))
ddbSession = dynamodb.New(sess)
}


func TestTerraformDeployment(t *testing.T) {
    terraformOptions := terraform.WithDefaultRetryableErrors(t,&terraform.Options{
        TerraformDir: "../",

        Vars: map[string]interface{}{
            "s3_bucket_name":       "my-upload-bucket",
            "dynamodb_table_name":  "Files",
        },


        EnvVars: map[string]string{
            "AWS_ACCESS_KEY_ID":     os.Getenv("AWS_ACCESS_KEY_ID"),
            "AWS_SECRET_ACCESS_KEY": os.Getenv("AWS_SECRET_ACCESS_KEY"),
        },

        NoColor: true,
    },
    )

    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)

    // Validate that the S3 bucket exists
    s3Bucket := terraform.Output(t, terraformOptions, "s3_bucket_name")
    assert.Equal(t, "my-upload-bucket", s3Bucket)

    // Validate that the state machine exists
    state_machine_arn := terraform.Output(t, terraformOptions, "state_machine_arn")
    assert.Equal(t, "arn:aws:states:eu-central-1:000000000000:stateMachine:dynamodb_updater_workflow", state_machine_arn)

    // Validate that the DynamoDB table exists
    lambdaFunctionArn := terraform.Output(t, terraformOptions, "lambda_arn")
    assert.Equal(t, "arn:aws:lambda:eu-central-1:000000000000:function:upload_trigger_lambda", lambdaFunctionArn)

    // Validate that the DynamoDB table exists
    input := &dynamodb.ListTablesInput{}
    result, err := ddbSession.ListTables(input)
    assert.NoError(t, err)
    assert.Equal(t, "Files", *result.TableNames[0])
}
