output "api_url" {
  description = "URL base del API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}
output "cloudfront_url" {
  description = "URL de la distribucion de CloudFront para acceder al Frontend"
  value       = aws_cloudfront_distribution.cdn.domain_name
}