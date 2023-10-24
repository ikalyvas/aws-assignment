
# Create an S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.s3_bucket_name
}

# Create a DynamoDB Table
resource "aws_dynamodb_table" "files" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "FileName"
  attribute {
    name = "FileName"
    type = "S"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create an IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"

    actions = [
      "states:StartExecution",
    ]

    resources = [
        aws_sfn_state_machine.dynamodb_updater_workflow.arn,
    ]
  }

  statement {
        effect = "Allow"

        actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups"
        ]

        resources = ["${aws_cloudwatch_log_group.MyLambdaLogGroup.arn}:*"]
    }

    statement {
        effect = "Allow"
        actions = [
        "cloudwatch:PutMetricData",
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",
        "logs:DescribeResourcePolicies",
        ]
        resources = ["*"]
    }
}

resource "aws_iam_policy" "lambda_policy" {
  policy = data.aws_iam_policy_document.lambda_policy.json
  name = "lambda_dynamodb_policy"
  description = "Policy to allow Lambda to start a Step Function"
}

# Attach the Lambda policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}


data "archive_file" "python_zip" {
type        = "zip"
source_dir  = "${path.module}/lambda/"
output_path = "${path.module}/lambda/lambda-trigger-sm.zip"
}

# Create a Lambda Function
resource "aws_lambda_function" "upload_trigger_lambda" {
  function_name = "upload_trigger_lambda"
  handler      = "index.lambda_handler"
  runtime      = "python3.8"
  role         = aws_iam_role.lambda_execution_role.arn

  filename      = "${path.module}/lambda/lambda-trigger-sm.zip"
  source_code_hash = data.archive_file.python_zip.output_base64sha256
  timeout = 120

  environment {
    variables = {
      SM_ARN = aws_sfn_state_machine.dynamodb_updater_workflow.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "MyLambdaLogGroup" {
  retention_in_days = 1
  name              = "/aws/lambda/${aws_lambda_function.upload_trigger_lambda.function_name}"
}

resource "aws_cloudwatch_log_group" "MySFNLogGroup" {
   name_prefix       = "/aws/vendedlogs/states/${var.sfn_name}-"
  retention_in_days = 1
}

data "aws_iam_policy_document" "sf_policy" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem",
    ]

    resources = [
      aws_dynamodb_table.files.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }

}
# Attach a policy to the IAM role that allows PutItem in DynamoDB and CloudWatch Logs
resource "aws_iam_policy" "state_machine_policy" {
  name = "state_machine_policy"
  description = "Policy to allow PutItem in DynamoDB and permissions for CloudWatch Logs"
  policy = data.aws_iam_policy_document.sf_policy.json

}

data "aws_iam_policy_document" "assume_role_sf" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


# Create an IAM role for the Step Function
resource "aws_iam_role" "step_function_role" {
  name = "step_function_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_sf.json

}

resource "aws_iam_role_policy_attachment" "attach_state_machine_policy" {
  policy_arn = aws_iam_policy.state_machine_policy.arn
  role = aws_iam_role.step_function_role.name
}

resource "aws_sfn_state_machine" "dynamodb_updater_workflow" {
  name     = var.sfn_name
  definition = jsonencode({
    Comment = "A Step Function that writes to DynamoDB",
    StartAt = "Upload",
    States = {
      Upload = {
        Type     = "Task",
        Resource = "arn:aws:states:::dynamodb:putItem",
        Parameters = {
          "TableName": "Files",
          "Item": {
            "FileName": { "S.$": "$.fileName" },
          }
        },
        End     = true,
      }
    }
  })
  role_arn = aws_iam_role.step_function_role.arn
  logging_configuration {
    level = "ALL"
    include_execution_data = true
    log_destination = "${aws_cloudwatch_log_group.MySFNLogGroup.arn}:*"
    }
  timeouts {
    create = "1m"
  }
  }

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_trigger_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.my_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.my_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.upload_trigger_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
