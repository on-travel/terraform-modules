# variables.tf

variable backend_bucket {
  type = string
}

variable backend_region {
  type = string
}

variable dns_backend_workspace {
  type = string
  default = "primary"
}

variable certificate_backend_workspace {
  type = string
  default = "primary"
}

variable domain {
  type = string
}

variable bucket {
  type = string
}
