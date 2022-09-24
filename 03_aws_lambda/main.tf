provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "this" {
  length = 2
}


module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "v4.0.2"

  publish = true

  function_name = "${random_pet.this.id}-lambda-batch-simple-demo"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  attach_policies = true
  policies = ["arn:aws:iam::aws:policy/AWSBatchFullAccess"]
  
  source_path = [
    "${path.module}/src/index.py",
  ]
}
