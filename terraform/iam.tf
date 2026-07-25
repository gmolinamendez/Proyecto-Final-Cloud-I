data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  ses_admin_identity_arn        = "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/${var.admin_email}"
  ses_notification_identity_arn = "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/${var.notification_email}"
}

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

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Permisos especificos para las Lambdas de CloudShop"

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
          "${aws_dynamodb_table.usuarios.arn}/index/*",
          aws_dynamodb_table.tiendas.arn,
          aws_dynamodb_table.productos.arn,
          "${aws_dynamodb_table.productos.arn}/index/*",
          aws_dynamodb_table.pedidos.arn,
          "${aws_dynamodb_table.pedidos.arn}/index/*",
          aws_dynamodb_table.auditoria.arn,
          "${aws_dynamodb_table.auditoria.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminAddUserToGroup",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminDisableUser",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminRemoveUserFromGroup",
          "cognito-idp:AdminSetUserPassword",
          "cognito-idp:AdminUpdateUserAttributes"
        ]
        Resource = aws_cognito_user_pool.users.arn
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutEvents"]
        Resource = aws_cloudwatch_event_bus.order_bus.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.admin_email
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}
