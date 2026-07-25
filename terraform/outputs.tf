output "api_url" {
  description = "URL base del API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cloudfront_url" {
  description = "URL de la distribucion de CloudFront para acceder al Frontend"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = aws_cognito_user_pool.users.id
}

output "user_pool_client_id" {
  description = "ID del cliente web de Cognito"
  value       = aws_cognito_user_pool_client.web.id
}

output "frontend_bucket" {
  description = "Bucket S3 del frontend"
  value       = aws_s3_bucket.frontend_bucket.id
}

output "cloudfront_distribution_id" {
  description = "ID de la distribucion CloudFront"
  value       = aws_cloudfront_distribution.cdn.id
}

output "cloudwatch_dashboard_url" {
  description = "URL del dashboard de CloudWatch"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
