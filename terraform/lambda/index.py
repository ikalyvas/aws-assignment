import json
import os
import time
import uuid

import boto3
import logging

sfn_client = boto3.client("stepfunctions", endpoint_url="http://localstack:4566", region_name="eu-central-1")


def generate_execution_name():
    unique_id = str(uuid.uuid4())
    current_time = int(time.time())
    execution_name = f"Execution-{current_time}-{unique_id}"
    return execution_name


def lambda_handler(event, context):
    # Assuming the event contains information about the uploaded file
    s3_bucket = event["Records"][0]["s3"]["bucket"]["name"]
    s3_object_key = event["Records"][0]["s3"]["object"]["key"]

    input_data = {
        "bucket": s3_bucket,
        "fileName": s3_object_key
    }

    print(f"Input Data: {input_data}")
    print(f"Event: {event}")

    # Define the Step Function's ARN
    state_machine_arn = os.environ.get("SM_ARN")

    # Start the Step Function execution
    response = sfn_client.start_execution(
        stateMachineArn=state_machine_arn,
        name=generate_execution_name(),
        input=json.dumps(input_data)
    )

    # Log the response for debugging
    logging.info(f"Step Function Execution Response: {response}")

    return {
        "statusCode": 200,
        "body": json.dumps("Step Function execution started successfully.")
    }
