variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "cluster_name" {}

variable "extra_tags" {
  default = {}
  type    = "map"
}

variable "zone_count" {
  default = 2
}
