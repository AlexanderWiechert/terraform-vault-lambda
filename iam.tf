#ec2
resource "aws_iam_role" "vault_ec2_role" {
  name = "VaultEC2Role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "VaultInstanceProfile"
  role = aws_iam_role.vault_ec2_role.name
}
#ec2

#kms
resource "aws_iam_role_policy" "vault_kms_policy" {
  name = "VaultKMSPolicy"
  role = aws_iam_role.vault_ec2_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource" : aws_kms_key.vault_unseal_key.arn
    }]
  })
}
#kms

#lambda
resource "aws_iam_role" "api_gateway_invoke_lambda_role" {
  name = "api_gateway_invoke_lambda_role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Action" : "sts:AssumeRole",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.api_gateway_invoke_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "api_gateway_invoke_lambda" {
  name = "APIGatewayInvokeLambdaPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = aws_lambda_function.vault_login_function.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_invoke_lambda" {
  role       = aws_iam_role.api_gateway_invoke_lambda_role.name
  policy_arn = aws_iam_policy.api_gateway_invoke_lambda.arn
}

#lambda

#apigw
resource "aws_iam_role" "api_gateway_logs_role" {
  name = "APIGatewayCloudWatchLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "api_gateway_logs_policy" {
  name        = "APIGatewayCloudWatchLogsPolicy"
  description = "Policy for API Gateway to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:*",

        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_logs_policy" {
  role       = aws_iam_role.api_gateway_logs_role.name
  policy_arn = aws_iam_policy.api_gateway_logs_policy.arn
}

#apigw