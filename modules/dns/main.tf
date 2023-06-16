# Define the Route 53 DNS zone
resource "aws_route53_zone" "zone" {
  name = var.domain_name
}

# Define the Route 53 DNS records using a for_each loop - records consistent across environments
resource "aws_route53_record" "records" {
  for_each = var.global_dns_records

  zone_id = aws_route53_zone.zone.zone_id
  name    = "${each.value.name}${aws_route53_zone.zone.name}"
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}

# Define the Route 53 DNS records using a for_each loop - individual records that are different between environments
resource "aws_route53_record" "environment_records" {
  for_each = var.environment_dns_records

  zone_id = aws_route53_zone.zone.zone_id
  name    = "${each.value.name}${aws_route53_zone.zone.name}"
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
