# ===============================
# AWS Networking Module
# ===============================
# Creates VPC, subnets, internet gateway, and route tables

data "aws_caller_identity" "current" {}

# ===============================
# VPC
# ===============================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.prefix}-vpc"
  })
}

# ===============================
# Public Subnet
# ===============================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.prefix}-public-subnet"
  })
}

# ===============================
# Internet Gateway
# ===============================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.prefix}-igw"
  })
}

# ===============================
# Route Table
# ===============================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.prefix}-public-rt"
  })
}

# ===============================
# Route Table Association
# ===============================

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
