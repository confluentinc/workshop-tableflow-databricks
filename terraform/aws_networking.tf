data "aws_caller_identity" "current" {}

# -------------------------------
# Networking
# -------------------------------

# -------------------------------
#  VPC and Subnets
# -------------------------------

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# -------------------------------
# Internet Gateway
# -------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}


# -------------------------------
# Public Route Table
# -------------------------------

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"                 # This route allows all outbound traffic
    gateway_id = aws_internet_gateway.igw.id # Route to the Internet Gateway
  }
}

# -------------------------------
# Associate Public Route Table with Public Subnet
# -------------------------------

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}


# -------------------------------
# Security Group for EC2
# -------------------------------

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NEW NETWORKING

# data "aws_availability_zones" "available" {
#   state = "available"
#   filter {
#     name   = "zone-type"
#     values = ["availability-zone"] # This excludes Local Zones and Wavelength Zones
#   }
# }

# # ------------------------------------------------------
# # VPC
# # ------------------------------------------------------
# resource "aws_vpc" "main" {
#   cidr_block           = var.vpc_cidr
#   enable_dns_hostnames = true
#   tags = {
#     Name = "${local.prefix}-vpc-${random_id.env_display_id.hex}"
#   }

# }

# # ------------------------------------------------------
# # Public SUBNETS
# # ------------------------------------------------------

# resource "aws_subnet" "public_subnets" {
#   count                   = 3
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.${count.index + 1}.0/24"
#   availability_zone       = data.aws_availability_zones.available.names[count.index]
#   map_public_ip_on_launch = true
#   tags = {
#     Name                     = "${local.prefix}-public-${count.index}-${random_id.env_display_id.hex}"
#     "kubernetes.io/role/elb" = "1" # Required for public LoadBalancer
#   }
# }

# # ------------------------------------------------------
# # Private SUBNETS
# # ------------------------------------------------------

# resource "aws_subnet" "private_subnets" {
#   count                   = 3
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.${count.index + 10}.0/24"
#   availability_zone       = data.aws_availability_zones.available.names[count.index]
#   map_public_ip_on_launch = false
#   tags = {
#     Name = "${local.prefix}-private-${count.index}-${random_id.env_display_id.hex}"
#   }
# }

# # ------------------------------------------------------
# # IGW
# # ------------------------------------------------------
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "${local.prefix}-internet-gateway-${random_id.env_display_id.hex}"
#   }
# }

# # ------------------------------------------------------
# # EIP
# # ------------------------------------------------------

# resource "aws_eip" "eip" {
#   tags = {
#     Name = "${local.prefix}-aws-eip-${random_id.env_display_id.hex}"
#   }
# }

# # ------------------------------------------------------
# # NAT
# # ------------------------------------------------------

# resource "aws_nat_gateway" "natgw" {
#   allocation_id = aws_eip.eip.id
#   subnet_id     = aws_subnet.public_subnets[1].id
#   tags = {
#     Name = "${local.prefix}-nat-gateway-${random_id.env_display_id.hex}"
#   }
# }

# # ------------------------------------------------------
# # ROUTE TABLE
# # ------------------------------------------------------
# resource "aws_route_table" "public_route_table" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.igw.id
#   }
#   tags = {
#     Name = "${local.prefix}-public-route-table-${random_id.env_display_id.hex}"
#   }
# }

# resource "aws_route_table" "private_route_table" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.natgw.id
#   }
#   tags = {
#     Name = "${local.prefix}-private-route-table-${random_id.env_display_id.hex}"
#   }
# }

# resource "aws_route_table_association" "pub_subnet_associations" {
#   count          = 3
#   subnet_id      = aws_subnet.public_subnets[count.index].id
#   route_table_id = aws_route_table.public_route_table.id
# }

# resource "aws_route_table_association" "pri_subnet_associations" {
#   count          = 3
#   subnet_id      = aws_subnet.private_subnets[count.index].id
#   route_table_id = aws_route_table.private_route_table.id
# }

# # ------------------------------------------------------
# # SG
# # ------------------------------------------------------

# # Inbound rule for port 443 from the main security group
# resource "aws_security_group_rule" "self_ingress_443" {
#   type                     = "ingress"
#   from_port                = 443
#   to_port                  = 443
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.sg.id
#   source_security_group_id = aws_security_group.sg.id
# }

# resource "aws_security_group" "sg" {
#   name        = "${local.prefix}-aws-security-group-${random_id.env_display_id.hex}"
#   description = "Allow TLS inbound traffic"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port = 443
#     to_port   = 443
#     protocol  = "tcp"
#   }


#   ingress {
#     from_port   = 9092
#     to_port     = 9092
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "allow_tls"
#     Name = "${local.prefix}-security-group-${random_id.env_display_id.hex}"

#   }
# }

# output "aws_caller_info" {
#   value = {
#     caller_arn = data.aws_caller_identity.current.arn
#   }
# }
