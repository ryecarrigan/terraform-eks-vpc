terraform {
  required_version = ">= 0.12.0"
}

data "aws_availability_zones" "current" {}

resource "aws_eip" "ip" {
  vpc  = true
  tags = local.common_tags
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = merge(
    {
      "${local.cluster_name_tag}": "shared",
    },
    local.common_tags,
  )
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = local.vpc_id
  tags   = local.common_tags
}

resource "aws_nat_gateway" "gateway" {
  allocation_id = aws_eip.ip.id
  depends_on    = [aws_internet_gateway.gateway]
  subnet_id     = aws_subnet.public[0].id
  tags          = local.common_tags
}

resource "aws_subnet" "public" {
  count = local.active_zone_count

  availability_zone       = local.active_zones[count.index]
  cidr_block              = cidrsubnet(local.vpc_cidr_block, 8, 100 + count.index)
  map_public_ip_on_launch = true
  vpc_id                  = local.vpc_id

  tags = merge(
    {
      "${local.cluster_name_tag}": "shared",
      "kubernetes.io/role/elb": 1,
    },
    local.common_tags,
  )
}

resource "aws_subnet" "private" {
  count = local.active_zone_count

  availability_zone       = local.active_zones[count.index]
  cidr_block              = cidrsubnet(local.vpc_cidr_block, 8, 200 + count.index)
  map_public_ip_on_launch = false
  vpc_id                  = local.vpc_id

  tags = merge(
    {
      "${local.cluster_name_tag}": "shared",
      "kubernetes.io/role/internal-elb": 1,
    },
    local.common_tags,
  )
}

resource "aws_route_table" "private" {
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gateway.id
  }

  tags = local.common_tags
}

resource "aws_route_table" "public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "private" {
  count = local.active_zone_count

  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private.*.id[count.index]
}

resource "aws_route_table_association" "public" {
  count = local.active_zone_count

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.*.id[count.index]
}

locals {
  active_zone_count = length(local.active_zones)
  active_zones      = slice(data.aws_availability_zones.current.names, 0, var.zone_count)
  cluster_name_tag  = "kubernetes.io/cluster/${var.cluster_name}"
  common_tags       = merge({Name: var.cluster_name}, var.extra_tags)
  total_zone_count  = length(data.aws_availability_zones.current.names)
  vpc_cidr_block    = aws_vpc.vpc.cidr_block
  vpc_id            = aws_vpc.vpc.id
}
