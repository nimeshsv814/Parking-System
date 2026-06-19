locals {
  edge_origin_domain_name      = var.cloudfront_origin_domain_name
  create_route53_hosted_zone   = var.enable_edge_stack && var.create_route53_hosted_zone
  edge_hosted_zone_id          = local.create_route53_hosted_zone ? aws_route53_zone.edge[0].zone_id : var.route53_hosted_zone_id
  create_cloudfront_dns_record = var.enable_edge_stack && var.create_cloudfront_route53_alias_record && var.app_domain_name != "" && local.edge_hosted_zone_id != ""
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  count = var.enable_edge_stack ? 1 : 0

  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  count = var.enable_edge_stack ? 1 : 0

  name = "Managed-AllViewer"
}

resource "aws_route53_zone" "edge" {
  count = local.create_route53_hosted_zone ? 1 : 0

  name = var.route53_zone_domain_name != "" ? var.route53_zone_domain_name : var.app_domain_name

  tags = {
    Name        = var.route53_zone_domain_name != "" ? var.route53_zone_domain_name : var.app_domain_name
    Application = "smart-parking"
  }
}

resource "aws_wafv2_web_acl" "edge" {
  count = var.enable_edge_stack ? 1 : 0

  name        = "${var.cluster_name}-edge-waf"
  description = "WAF for QuickSlot CloudFront edge distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.cluster_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.cluster_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.cluster_name}-edge-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.cluster_name}-edge-waf"
    Application = "smart-parking"
  }
}

resource "aws_cloudfront_distribution" "edge" {
  count = var.enable_edge_stack ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "QuickSlot EKS edge distribution"
  price_class     = var.cloudfront_price_class
  aliases         = var.app_domain_name != "" ? [var.app_domain_name] : []
  web_acl_id      = aws_wafv2_web_acl.edge[0].arn

  origin {
    domain_name = local.edge_origin_domain_name
    origin_id   = "quickslot-alb"

    dynamic "custom_header" {
      for_each = var.cloudfront_origin_custom_header_name != "" && var.cloudfront_origin_custom_header_value != "" ? [1] : []

      content {
        name  = var.cloudfront_origin_custom_header_name
        value = var.cloudfront_origin_custom_header_value
      }
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "quickslot-alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled[0].id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer[0].id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.app_domain_name == ""
    acm_certificate_arn            = var.cloudfront_certificate_arn != "" ? var.cloudfront_certificate_arn : null
    ssl_support_method             = var.cloudfront_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.cloudfront_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = {
    Name        = "${var.cluster_name}-edge"
    Application = "smart-parking"
  }

  lifecycle {
    precondition {
      condition     = var.cloudfront_origin_domain_name != ""
      error_message = "cloudfront_origin_domain_name must be set when enable_edge_stack is true."
    }

    precondition {
      condition     = var.app_domain_name == "" || var.cloudfront_certificate_arn != ""
      error_message = "cloudfront_certificate_arn must be set when app_domain_name is set."
    }
  }
}

resource "aws_route53_record" "cloudfront_ipv4" {
  count = local.create_cloudfront_dns_record ? 1 : 0

  zone_id = local.edge_hosted_zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = aws_cloudfront_distribution.edge[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_ipv6" {
  count = local.create_cloudfront_dns_record && var.cloudfront_create_ipv6_record ? 1 : 0

  zone_id = local.edge_hosted_zone_id
  name    = var.app_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = aws_cloudfront_distribution.edge[0].hosted_zone_id
    evaluate_target_health = false
  }
}
