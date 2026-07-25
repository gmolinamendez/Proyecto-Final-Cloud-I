# 1. Cambiar el WAF a ámbito CLOUDFRONT
resource "aws_wafv2_web_acl" "api_waf" {
  name        = "${var.project_name}-waf"
  description = "Proteccion base en CloudFront para CloudShop"
  scope       = "CLOUDFRONT" # <-- Cambiado de REGIONAL a CLOUDFRONT
  provider    = aws          # Requiere estar en us-east-1

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 100
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudShopWAFMetric"
    sampled_requests_enabled   = true
  }
}