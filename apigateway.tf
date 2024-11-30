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

resource "aws_api_gateway_method_settings" "login_method" {
  rest_api_id = aws_api_gateway_rest_api.vault_api.id
  stage_name  = aws_api_gateway_stage.vault_api.stage_name
  method_path = "${aws_api_gateway_resource.login_resource.path_part}/${aws_api_gateway_method.login_method.http_method}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# API Gateway Integration mit Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.vault_api.id
  resource_id             = aws_api_gateway_resource.login_resource.id
  http_method             = aws_api_gateway_method.login_method.http_method
  integration_http_method = "POST"
  type                    = "AWS" # Nicht mehr AWS_PROXY
  uri                     = aws_lambda_function.vault_login_function.invoke_arn

  # Mapping Templates für die Transformation der Anfrage
  request_templates = {
    "application/json" = <<EOF
    #if($input.json('$.username') && $input.json('$.password'))
    {
      "username": "$input.json('$.username')",
      "password": "$input.json('$.password')"
    }
    #else
    {
      "errorMessage": "Missing required fields"
    }
    #end
    EOF
  }

  # Antwortvorlagen (optional)
  passthrough_behavior = "WHEN_NO_MATCH"
}


# API Gateway Deployment erstellen
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.vault_api.id
}

# API Gateway Stage
resource "aws_api_gateway_stage" "vault_api" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.vault_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format          = "$context.requestId $context.identity.sourceIp $context.httpMethod $context.resourcePath $context.status $context.responseLength $context.requestTime"
  }

  depends_on = [aws_api_gateway_account.account_settings]
}

# API Gateway Account Settings konfigurieren
resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logs_role.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/api-gateway/vault-api-logs"
  retention_in_days = 30
}