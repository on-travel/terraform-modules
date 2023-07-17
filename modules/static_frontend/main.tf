terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "eu-west-1"
}

locals {
    domain = var.domain
    bucket = var.bucket
    region = "eu-west-1"
}

# get the hosted zone id and domain name from the specified workspace (domain)
data "terraform_remote_state" "dns" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket
    region = var.backend_region
    key    = "env://${var.dns_backend_workspace}/tf_state_dns"
  }
}

# get the hosted zone id and domain name from the specified workspace (domain)
data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.backend_bucket
    region = var.backend_region
    key    = "env://${var.certificate_backend_workspace}/tf_state_certificate"
  }
}

resource "aws_s3_bucket" "S3Bucket" {
    bucket = "${local.bucket}"
}

resource "aws_cloudfront_distribution" "CloudFrontDistribution" {
    aliases = [
        "${data.terraform_remote_state.dns.outputs.domain_name}"
    ]
    origin {
        domain_name = "${local.bucket}.s3.${local.region}.amazonaws.com"
        origin_id = "${data.terraform_remote_state.dns.outputs.domain_name}.s3.${local.region}.amazonaws.com"
        origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
        
        origin_path = ""
        s3_origin_config {
            origin_access_identity = ""
        }
    }
    default_cache_behavior {
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        cached_methods = ["GET", "HEAD"]
        allowed_methods = [
            "HEAD",
            "GET"
        ]
        compress = true
        smooth_streaming  = false
        target_origin_id = "${data.terraform_remote_state.dns.outputs.domain_name}.s3.${local.region}.amazonaws.com"
        viewer_protocol_policy = "redirect-to-https"
    }
    comment = "Distruibution for ${data.terraform_remote_state.dns.outputs.domain_name}"
    price_class = "PriceClass_All"
    enabled = true
    viewer_certificate {
        acm_certificate_arn = "${data.terraform_remote_state.certificate.outputs.certificate_arn}"
        cloudfront_default_certificate = false
        minimum_protocol_version = "TLSv1.2_2021"
        ssl_support_method = "sni-only"
    }
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }
    http_version = "http2and3"
    is_ipv6_enabled = true

}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.bucket}-origin-access-identity"
  description                       = "Access for CloudFront to reach the S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_route53_record" "CloudFrontDistributionRecord" {
    zone_id = data.terraform_remote_state.dns.outputs.hosted_zone_id
    name = "${data.terraform_remote_state.dns.outputs.domain_name}"
    type = "A"
    alias {
        name = aws_cloudfront_distribution.CloudFrontDistribution.domain_name
        zone_id = aws_cloudfront_distribution.CloudFrontDistribution.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_s3_bucket_policy" "S3BucketPolicy" {
    bucket = "${aws_s3_bucket.S3Bucket.id}"
    policy = "{\"Version\":\"2008-10-17\",\"Id\":\"PolicyForCloudFrontPrivateContent\",\"Statement\":[{\"Sid\":\"AllowCloudFrontServicePrincipal\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"cloudfront.amazonaws.com\"},\"Action\":\"s3:GetObject\",\"Resource\":\"${aws_s3_bucket.S3Bucket.arn}/*\",\"Condition\":{\"StringEquals\":{\"AWS:SourceArn\":\"${aws_cloudfront_distribution.CloudFrontDistribution.arn}\"}}}]}"
}
