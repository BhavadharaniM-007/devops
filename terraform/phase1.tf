terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.85.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ───────────────
# Use existing VPC
# ───────────────
data "aws_vpc" "existing" {
  id = "vpc-0dad38df46bc55c0d" 
}

# ───────────────
# Subnets, IGW, Routing
# ───────────────
resource "aws_subnet" "public_az1" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = "10.0.24.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-az1"
  }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = "10.0.26.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-az2"
  }
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# ───────────────
# Security Groups
# ───────────────
resource "aws_security_group" "web_sg" {
  name        = "web-sg-new-111919765"
  description = "Allow inbound traffic to EC2"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend app"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg-final-61119192"
  description = "Allow MySQL traffic from EC2"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# ───────────────
# EC2 Instance
# ───────────────
resource "aws_instance" "web_server" {
  ami                         = "ami-08982f1c5bf93d976"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_az1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true              
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
   key_name      = "devops"   
  tags = {
    Name = "TerraformWebServer"
  }
}

# ───────────────
# IAM Role for EC2
# ───────────────
resource "aws_iam_role" "ec2_role" {
  name = "ec2-roledevops126789-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_prof1119191910675"
  role = aws_iam_role.ec2_role.name
}

# ───────────────
# RDS MySQL Instance
# ───────────────
resource "aws_db_subnet_group" "default" {
  name       = "maindevsample215465"
  subnet_ids = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]

  tags = {
    Name = "MainDBSubnetGroup"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage         = 20
  engine                    = "mysql"
  engine_version            = "8.0.40"
  instance_class            = "db.t3.micro"
  db_name                   = "devops"
  username                  = "admin"
  password                  = "YourStrongPassword123!"
  db_subnet_group_name      = aws_db_subnet_group.default.name
  vpc_security_group_ids    = [aws_security_group.rds_sg.id]
  skip_final_snapshot       = true
  publicly_accessible       = true

  tags = {
    Name = "MainDBInstance"
  }
}
output "ec2_public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

