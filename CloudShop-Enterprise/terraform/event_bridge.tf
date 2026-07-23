resource "aws_cloudwatch_event_bus" "order_bus" {
  name = "${var.project_name}-order-bus"
}

data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambdas/order_processor.py"
  output_path = "${path.module}/../backend/lambdas/order_processor.zip"
}

resource "aws_lambda_function" "order_processor" {
  filename         = data.archive_file.processor_zip.output_path
  function_name    = "${var.project_name}-order-processor"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "order_processor.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.processor_zip.output_base64sha256

  environment {
    variables = {
      AUDIT_TABLE   = aws_dynamodb_table.auditoria.name
      PRODUCT_TABLE = aws_dynamodb_table.productos.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "order_created_rule" {
  name           = "order-created-rule"
  description    = "Escucha cuando se crea un nuevo pedido"
  event_bus_name = aws_cloudwatch_event_bus.order_bus.name

  event_pattern = jsonencode({
    "source": ["cloudshop.orders"],
    "detail-type": ["Pedido Creado"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  event_bus_name = aws_cloudwatch_event_bus.order_bus.name
  rule           = aws_cloudwatch_event_rule.order_created_rule.name
  target_id      = "SendToOrderProcessorLambda"
  arn            = aws_lambda_function.order_processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_created_rule.arn
}