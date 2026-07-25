data "archive_file" "users_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/users.zip"
}

resource "aws_lambda_function" "users" {
  filename         = data.archive_file.users_zip.output_path
  function_name    = "${var.project_name}-users"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "users.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.users_zip.output_base64sha256

  environment {
    variables = {
      USER_TABLE   = aws_dynamodb_table.usuarios.name
      USER_POOL_ID = aws_cognito_user_pool.users.id
      AUDIT_TABLE  = aws_dynamodb_table.auditoria.name
    }
  }
}

data "archive_file" "stores_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/stores.zip"
}

resource "aws_lambda_function" "stores" {
  filename         = data.archive_file.stores_zip.output_path
  function_name    = "${var.project_name}-stores"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "stores.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.stores_zip.output_base64sha256

  environment {
    variables = {
      STORE_TABLE = aws_dynamodb_table.tiendas.name
      AUDIT_TABLE = aws_dynamodb_table.auditoria.name
    }
  }
}

data "archive_file" "products_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/products.zip"
}

resource "aws_lambda_function" "products" {
  filename         = data.archive_file.products_zip.output_path
  function_name    = "${var.project_name}-products"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "products.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.products_zip.output_base64sha256

  environment {
    variables = {
      PRODUCT_TABLE = aws_dynamodb_table.productos.name
      STORE_TABLE   = aws_dynamodb_table.tiendas.name
      AUDIT_TABLE   = aws_dynamodb_table.auditoria.name
    }
  }
}

data "archive_file" "orders_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/orders.zip"
}

resource "aws_lambda_function" "orders" {
  filename         = data.archive_file.orders_zip.output_path
  function_name    = "${var.project_name}-orders"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "orders.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.orders_zip.output_base64sha256

  environment {
    variables = {
      ORDER_TABLE    = aws_dynamodb_table.pedidos.name
      PRODUCT_TABLE  = aws_dynamodb_table.productos.name
      AUDIT_TABLE    = aws_dynamodb_table.auditoria.name
      EVENT_BUS_NAME = aws_cloudwatch_event_bus.order_bus.name
    }
  }
}

data "archive_file" "event_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/event_processor.zip"
}

resource "aws_lambda_function" "event_processor" {
  filename         = data.archive_file.event_processor_zip.output_path
  function_name    = "${var.project_name}-event-processor"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "event_processor.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.event_processor_zip.output_base64sha256

  environment {
    variables = {
      ORDER_TABLE        = aws_dynamodb_table.pedidos.name
      PRODUCT_TABLE      = aws_dynamodb_table.productos.name
      AUDIT_TABLE        = aws_dynamodb_table.auditoria.name
      ADMIN_EMAIL        = var.admin_email
      NOTIFICATION_EMAIL = var.notification_email
    }
  }
}

data "archive_file" "dashboard_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/lambdas"
  output_path = "${path.module}/build/dashboard.zip"
}

resource "aws_lambda_function" "dashboard" {
  filename         = data.archive_file.dashboard_zip.output_path
  function_name    = "${var.project_name}-dashboard"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "dashboard.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.dashboard_zip.output_base64sha256

  environment {
    variables = {
      ORDER_TABLE   = aws_dynamodb_table.pedidos.name
      PRODUCT_TABLE = aws_dynamodb_table.productos.name
      USER_TABLE    = aws_dynamodb_table.usuarios.name
    }
  }
}
