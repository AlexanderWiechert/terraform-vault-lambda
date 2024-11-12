resource "null_resource" "prepare_lambda" {

  provisioner "local-exec" {

    command = <<EOF
        mkdir ${path.cwd}/build
        cp ${path.cwd}/lambda_function/lambda_function.py ${path.cwd}/build/
        python3 -m venv .venv
        source .venv/bin/activate
        ${path.cwd}/.venv/bin/pip install -r ${path.cwd}/lambda_function/requirements.txt -t ${path.cwd}/build
    EOF

  }
  triggers = {
    build_number = "${timestamp()}"
  }
}

# Verpacken der Lambda-Funktion als ZIP-Archiv
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/lambda_function_deploy.zip"

  # Abhängigkeit sicherstellen, dass die Abhängigkeiten installiert sind
  depends_on = [null_resource.prepare_lambda]
}

# Lambda-Funktion erstellen
resource "aws_lambda_function" "vault_login_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "vault_login_function"
  role             = aws_iam_role.api_gateway_invoke_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  timeout          = 10
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      VAULT_ADDR = "http://${aws_instance.vault.public_ip}:8200"
    }
  }

  #depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]
  depends_on = [
    null_resource.prepare_lambda,
    data.archive_file.lambda_zip
  ]
}

# Lambda-Berechtigung für API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.vault_login_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.vault_api.execution_arn}/*/*"
}

