#! Todo lo de las APIs esta aca, porfavor no tocar nada ya que me tomo annos

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["Authorization", "Content-Type"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip = "$context.identity.sourceIp"
      requestTime = "$context.requestTime"
      httpMethod = "$context.httpMethod"
      routeKey = "$context.routeKey"
      status = "$context.status"
      protocol = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErr = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 50
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id = aws_apigatewayv2_api.main.id
  authorizer_type = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name = "${var.project_name}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.users.id}"
  }
}

resource "aws_apigatewayv2_integration" "auth_lambda" {
  api_id = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.users.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_usuarios" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "POST /usuarios"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_usuarios" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /usuarios"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_usuario" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /usuarios/{usuario_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

resource "aws_apigatewayv2_route" "put_usuario" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "PUT /usuarios/{usuario_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_usuario" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "DELETE /usuarios/{usuario_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.auth_lambda.id}"
}

resource "aws_lambda_permission" "api_gw_users" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "stores_lambda" {
  api_id = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.stores.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_tiendas" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "POST /tiendas"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.stores_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_tiendas" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /tiendas"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.stores_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_tienda" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /tiendas/{tienda_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.stores_lambda.id}"
}

resource "aws_apigatewayv2_route" "put_tienda" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "PUT /tiendas/{tienda_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.stores_lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_tienda" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "DELETE /tiendas/{tienda_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.stores_lambda.id}"
}

resource "aws_lambda_permission" "api_gw_stores" {
  statement_id = "AllowExecutionFromAPIGatewayStores"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stores.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "products_lambda" {
  api_id = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.products.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_productos" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "POST /productos"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.products_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_productos" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /productos"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.products_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_producto" {
  api_id = aws_apigatewayv2_api.main.id
  route_key          = "GET /productos/{producto_id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.products_lambda.id}"
}

resource "aws_apigatewayv2_route" "put_producto" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "PUT /productos/{producto_id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.products_lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_producto" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "DELETE /productos/{producto_id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.products_lambda.id}"
}

resource "aws_lambda_permission" "api_gw_products" {
  statement_id  = "AllowExecutionFromAPIGatewayProducts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "orders_lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.orders.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_pedidos" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /pedidos"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_pedidos" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /pedidos"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
}

resource "aws_apigatewayv2_route" "get_pedido" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /pedidos/{pedido_id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
}

resource "aws_apigatewayv2_route" "put_pedido_estado" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "PUT /pedidos/{pedido_id}/estado"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_pedido" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "DELETE /pedidos/{pedido_id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.orders_lambda.id}"
}

resource "aws_lambda_permission" "api_gw_orders" {
  statement_id = "AllowExecutionFromAPIGatewayOrders"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "dashboard_lambda" {
  api_id = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.dashboard.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_dashboard" {
  api_id = aws_apigatewayv2_api.main.id
  route_key = "GET /dashboard"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  target = "integrations/${aws_apigatewayv2_integration.dashboard_lambda.id}"
}

resource "aws_lambda_permission" "api_gw_dashboard" {
  statement_id = "AllowExecutionFromAPIGatewayDashboard"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dashboard.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
