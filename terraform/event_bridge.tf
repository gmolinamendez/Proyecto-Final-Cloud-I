resource "aws_cloudwatch_event_bus" "order_bus" {
  name = "${var.project_name}-order-bus"
}

resource "aws_cloudwatch_event_rule" "order_created_rule" {
  name           = "order-created-rule"
  description    = "Escucha cuando se crea un nuevo pedido"
  event_bus_name = aws_cloudwatch_event_bus.order_bus.name

  event_pattern = jsonencode({
    "source" : ["cloudshop.orders"],
    "detail-type" : ["Pedido Creado"]
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  event_bus_name = aws_cloudwatch_event_bus.order_bus.name
  rule           = aws_cloudwatch_event_rule.order_created_rule.name
  target_id      = "SendToEventProcessorLambda"
  arn            = aws_lambda_function.event_processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_created_rule.arn
}
