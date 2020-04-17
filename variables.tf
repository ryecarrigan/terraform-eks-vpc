variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "cluster_name" {}

variable "extra_tags" {
  type = "map"
}

variable "nat_gateway_count" {
  default = 1
}

variable "zone_count" {
  default = 2
}
