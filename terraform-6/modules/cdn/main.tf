locals {
  origin_id = "external-alb-origin"
  api_path_patterns = [
    "/api/*",
    "/auth/*",
    "/parking/*",
    "/booking/*",
    "/payment/*",
    "/notification/*"
  ]
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  aliases         = var.enable_custom_domain ? [var.domain_name] : []
  comment         = "Smart Parking CloudFront distribution"
  is_ipv6_enabled = true
  price_class     = var.price_class
  web_acl_id      = var.web_acl_arn

  origin {
    domain_name = var.origin_domain_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_read_timeout    = 30
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    dynamic "custom_header" {
      for_each = var.origin_custom_header_name != "" && var.origin_custom_header_value != "" ? [1] : []

      content {
        name  = var.origin_custom_header_name
        value = var.origin_custom_header_value
      }
    }
  }

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    compress                 = true
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    target_origin_id         = local.origin_id
    viewer_protocol_policy   = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(local.api_path_patterns)

    content {
      path_pattern             = ordered_cache_behavior.value
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      compress                 = true
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
      target_origin_id         = local.origin_id
      viewer_protocol_policy   = "redirect-to-https"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [1] : []

    content {
      acm_certificate_arn      = var.certificate_arn
      minimum_protocol_version = "TLSv1.2_2021"
      ssl_support_method       = "sni-only"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [] : [1]

    content {
      cloudfront_default_certificate = true
    }
  }

  lifecycle {
    ignore_changes = [
      aliases,
      viewer_certificate
    ]
  }
}
