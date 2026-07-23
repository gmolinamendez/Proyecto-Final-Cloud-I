data "archive_file" "auth_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambdas/auth_service.py"
  output_path = "${path.module}/../backend/lambdas/auth_service.zip"
}

resource "aws_lambda_function" "auth_service" {
  filename         = data.archive_file.auth_zip.output_path
  function_name    = "${var.project_name}-auth-service"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "auth_service.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.auth_zip.output_base64sha256

  environment {
    variables = {
      USER_TABLE = aws_dynamodb_table.usuarios.name
    }
  }
}