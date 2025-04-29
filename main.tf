provider "aws" {
  region     = "us-east-1"
 }

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env_prefix}-rtb-public"
  }
}

# Subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_block_public
  map_public_ip_on_launch = true
  availability_zone       = var.avail_zone

  tags = {
    Name = "${var.env_prefix}-subnet-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_block_private
  availability_zone = var.avail_zone

  tags = {
    Name = "${var.env_prefix}-subnet-private"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.public.id # Consider using a separate private route table for security best practices
}

# Security Groups
resource "aws_security_group" "public" {
  name   = "${var.env_prefix}-sec-pub"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "RDP access"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  dynamic "ingress" {
    for_each = [
      { port = 80, desc = "HTTP" },
      { port = 443, desc = "HTTPS" },
      { port = 8080, desc = "Web UI" },
      { port = 8443, desc = "Secure Web UI" },
      { port = 5586, desc = "Custom Port" },
      { port = 123, desc = "NTP", protocol = "udp" }
    ]
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = lookup(ingress.value, "protocol", "tcp")
      cidr_blocks = ["0.0.0.0/0"]
      description = ingress.value.desc
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_prefix}-pub"
  }
}

resource "aws_security_group" "private" {
  name   = "${var.env_prefix}-sec-pri"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "RDP access from trusted IP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env_prefix}-pri"
  }
}

# EC2 Instances
resource "aws_instance" "windows" {
  ami                         = "ami-00df034fb08ddb498"
  instance_type               = var.instance_type
  count                       = var.instant_count
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.public.id]
  associate_public_ip_address = true
  key_name                    = var.key_name_win

  tags = {
    Name    = "${var.env_prefix}-btuser-win"
    Project = "btusertest"
  }
}

resource "aws_instance" "linux" {
  ami                         = "ami-0a0d2c67ef01a6863"
  instance_type               = "t3.xlarge"
  count                       = 1
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.private.id]
  associate_public_ip_address = true
  key_name                    = var.key_name_linux
  tags = {
    Name    = "${var.env_prefix}-btuser-linux"
    Project = "btusertest"
  }
}
