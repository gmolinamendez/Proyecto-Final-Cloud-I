# policy de confianza
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM role
resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.project_name}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# 3. Policies about iam roles and all
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Politicas de dynamo para lambdas
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-dynamodb-policy"
  description = "Permisos de lectura y escritura especificos para las tablas de CloudShop"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.usuarios.arn,
          aws_dynamodb_table.tiendas.arn,
          aws_dynamodb_table.productos.arn,
          aws_dynamodb_table.pedidos.arn,
          aws_dynamodb_table.auditoria.arn
        ]
      }
    ]
  })
}

# Politica de dynamo para lambdas
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}