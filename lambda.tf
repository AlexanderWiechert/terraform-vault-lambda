# Lokale Dateien einlesen
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function"
  output_path = "${path.module}/lambda_function_deploy.zip"
}

# IAM-Rolle für Lambda-Funktion
resource "aws_iam_role" "lambda_role" {
  name = "vault_lambda_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }]
  })
}

# Anfügen von Richtlinien an die IAM-Rolle
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda-Funktion erstellen
resource "aws_lambda_function" "vault_login_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "vault_login_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  timeout          = 10
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      VAULT_ADDR = "http://${aws_instance.vault.public_ip}:8200"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
}

# API Gateway REST API erstellen
resource "aws_api_gateway_rest_api" "vault_api" {
  name        = "VaultLoginAPI"
  description = "API Gateway für Vault Login"
}

# API Gateway Resource erstellen
resource "aws_api_gateway_resource" "login_resource" {
  rest_api_id = aws_api_gateway_rest_api.vault_api.id
  parent_id   = aws_api_gateway_rest_api.vault_api.root_resource_id
  path_part   = "login"
}

# API Gateway Method erstellen
resource "aws_api_gateway_method" "login_method" {
  rest_api_id   = aws_api_gateway_rest_api.vault_api.id
  resource_id   = aws_api_gateway_resource.login_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration mit Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vault_api.id
  resource_id             = aws_api_gateway_resource.login_resource.id
  http_method             = aws_api_gateway_method.login_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.vault_login_function.invoke_arn
}

# Lambda-Berechtigung für API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vault_login_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.vault_api.execution_arn}/*/*"
}

# API Gateway Deployment erstellen
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.vault_api.id
  stage_name  = "prod"
}

output "api_invoke_url" {
  description = "Die Invoke URL der API Gateway für die Lambda-Funktion"
  value       = "${aws_api_gateway_deployment.api_deployment.invoke_url}/login"
}
