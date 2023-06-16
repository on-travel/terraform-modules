variable "domain_name" {
  type = string
}

# Records that are common between every environment with each environments extension
variable "global_dns_records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = string
    records = list(string)
  }))
}

variable "environment_dns_records" {
  type = map(object({
    name    = string
    type    = string
    ttl     = string
    records = list(string)
  }))
}
