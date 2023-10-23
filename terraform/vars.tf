# Define variables
variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "my-upload-bucket"
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  type        = string
  default     = "Files"
}

