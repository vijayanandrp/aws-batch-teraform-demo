provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "this" {
  length = 2
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name                  = "EtlLambdaRole"
  assume_role_policy    = data.aws_iam_policy_document.assume_role.json
}


module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "v4.0.2"

  publish = true

  function_name = "${random_pet.this.id}-lambda-batch-simple-demo"
  description   = "Trigger the AWS Batch from Lambda Function"
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.iam_for_lambda.arn
  publish       = true

  attach_policies = true
  policies = ["arn:aws:iam::aws:policy/AWSBatchFullAccess"]
  
  source_path = [
    "${path.module}/src/index.py",
  ]
  
  create_role = false
  lambda_role = aws_iam_role.lambda.arn
}
