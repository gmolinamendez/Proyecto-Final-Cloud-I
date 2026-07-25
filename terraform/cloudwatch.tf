locals {
  lambda_function_names = [
    aws_lambda_function.users.function_name,
    aws_lambda_function.stores.function_name,
    aws_lambda_function.products.function_name,
    aws_lambda_function.orders.function_name,
    aws_lambda_function.event_processor.function_name,
    aws_lambda_function.dashboard.function_name
  ]
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = toset(local.lambda_function_names)
  name              = "/aws/lambda/${each.value}"
  retention_in_days = 7
}

resource "aws_cloudwatch_metric_alarm" "api_4xx" {
  alarm_name          = "${var.project_name}-api-4xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "4xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project_name}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 2000
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.default.name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = toset(local.lambda_function_names)
  alarm_name          = "${each.value}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }
}

resource "aws_cloudwatch_metric_alarm" "eventbridge_failed_invocations" {
  alarm_name          = "${var.project_name}-eventbridge-failed-invocations"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.order_created_rule.name
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway errores y latencia"
          region = var.aws_region
          metrics = [
            ["AWS/ApiGateway", "4xx", "ApiId", aws_apigatewayv2_api.main.id, "Stage", aws_apigatewayv2_stage.default.name],
            [".", "5xx", ".", ".", ".", "."],
            [".", "Latency", ".", ".", ".", "."]
          ]
          stat = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda errores"
          region = var.aws_region
          metrics = [
            for name in local.lambda_function_names :
            ["AWS/Lambda", "Errors", "FunctionName", name]
          ]
          stat = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "EventBridge"
          region  = var.aws_region
          metrics = [["AWS/Events", "Invocations", "RuleName", aws_cloudwatch_event_rule.order_created_rule.name]]
          stat    = "Sum"
        }
      }
    ]
  })
}
