
/*terraform {
  backend "s3" {
    bucket                                = "tf-remote-state"
    key                                   = "terraform.tfstate"
    region                                = "eu-central-1"
    encrypt                               = true
    dynamodb_table                        = "my-terraform-state-lock"
    endpoint= "http://localhost:4566"
    force_path_style = true
    dynamodb_endpoint = "http://localhost:4566"
    skip_credentials_validation = true

  }
}*/