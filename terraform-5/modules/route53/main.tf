resource "aws_route53_record" "cloudfront_ipv4" {
  name    = var.domain_name
  type    = "A"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
  }
}

resource "aws_route53_record" "cloudfront_ipv6" {
  count = var.create_ipv6_record ? 1 : 0

  name    = var.domain_name
  type    = "AAAA"
  zone_id = var.hosted_zone_id

  alias {
    evaluate_target_health = false
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
  }
}
