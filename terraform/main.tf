terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "trading-bot-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "trading-bot-public" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_ssm_parameter" "alpaca_api_key" {
  name  = "/trading-bot/ALPACA_API_KEY"
  type  = "SecureString"
  value = var.alpaca_api_key
}

resource "aws_ssm_parameter" "alpaca_secret_key" {
  name  = "/trading-bot/ALPACA_SECRET_KEY"
  type  = "SecureString"
  value = var.alpaca_secret_key
}

resource "aws_security_group" "ec2" {
  name   = "trading-bot-sg"
  vpc_id = aws_vpc.main.id
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

resource "aws_key_pair" "trading_bot" {
  key_name   = "trading-bot-key"
  public_key = var.ssh_public_key
}

resource "aws_iam_role" "ec2" {
  name = "trading-bot-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/trading-bot/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "trading-bot-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "trading_bot" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  key_name               = aws_key_pair.trading_bot.key_name
  tags = { Name = "trading-bot" }
}

output "ec2_public_ip" {
  value = aws_instance.trading_bot.public_ip
}

output "ssh_command" {
  value = "ssh ec2-user@${aws_instance.trading_bot.public_ip}"
}
