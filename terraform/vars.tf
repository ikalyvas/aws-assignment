# Define variables
variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "my-upload-bucket-dragonstone-1234567890"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "Files"
}

variable "sfn_name" {
  description = "The name of the Step Functions state machine"
  type        = string
  default     = "UploadStateMachine"
}
