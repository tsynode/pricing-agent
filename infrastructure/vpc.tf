# Main VPC for all resources
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  # Prevent conflicts with existing VPC
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore these specific attributes, not the entire resource
      cidr_block,
      enable_dns_support,
      enable_dns_hostnames
    ]
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )
}

# Output the VPC ID for reference in other modules or scripts
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

# Public subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    }
  )
}

# Private subnets
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = length(var.availability_zones)
  domain = "vpc"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-eip-${count.index + 1}"
    }
  )
}

# NAT Gateway
# NAT Gateway for private subnet internet access
# This is required for ECS tasks in private subnets to access the internet
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-nat-${count.index + 1}"
    }
  )
  
  # Explicit dependency on Internet Gateway and public subnets
  depends_on = [
    aws_internet_gateway.main,
    aws_subnet.public,
    aws_route_table.public,
    aws_route_table_association.public
  ]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-public-rt"
    }
  )
}

# Route table for private subnets
# Routes all internet-bound traffic through the NAT Gateway
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    }
  )
  
  # Explicit dependency on NAT Gateway
  depends_on = [aws_nat_gateway.main]
}

# Route table association for public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
  
  # This prevents conflicts with existing route table associations
  # while still allowing Terraform to manage them
  lifecycle {
    ignore_changes = [route_table_id, subnet_id]
  }
}

# Route table association for private subnets
# Associates the private subnets with their respective route tables
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
  
  # This prevents conflicts with existing route table associations
  # while still allowing Terraform to manage them
  lifecycle {
    ignore_changes = [route_table_id, subnet_id]
  }
  
  # Explicit dependency on private subnets and route tables
  depends_on = [
    aws_subnet.private,
    aws_route_table.private
  ]
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Prevent conflicts with existing security groups
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      description
    ]
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )
}

# Security group for ECS tasks
# Allows inbound traffic only from the ALB and outbound traffic to anywhere
resource "aws_security_group" "ecs" {
  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id
  
  # Only allow inbound traffic from the ALB security group
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow inbound traffic from ALB on container port"
  }
  
  # Allow all outbound traffic (needed for pulling container images, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  # Prevent conflicts with existing security groups
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Only ignore these specific attributes, not the entire resource
      name,
      description
    ]
  }
  
  # Explicit dependency on the VPC and ALB security group
  depends_on = [
    aws_vpc.main,
    aws_security_group.alb
  ]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-sg"
    }
  )
}
