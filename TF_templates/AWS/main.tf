terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
   ## aap = {
   ##   source  = "ansible/aap"
   ##   version = "~> 1.0"
    }
  }
}

# Provider configuration for AWS (credentials from Vault)
provider "aws" {
  region     = var.aws_region
  access_key = data.vault_generic_secret.aws_creds.data["access_key"]
  secret_key = data.vault_generic_secret.aws_creds.data["secret_key"]
}

# Provider configuration for Vault using AppRole authentication
provider "vault" {
  address = var.vault_addr
  
  auth_login {
    path = "auth/approle/login"
    
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# Provider configuration for Ansible Automation Platform
provider "aap" {
  host     = var.aap_host
  username = var.aap_username
  password = var.aap_password
  
  # Alternative: Use Vault for AAP credentials
  # username = data.vault_generic_secret.aap_creds.data["username"]
  # password = data.vault_generic_secret.aap_creds.data["password"]
}

# Data source to retrieve AWS credentials from Vault
data "vault_generic_secret" "aws_creds" {
  path = "secret/aws/credentials"
}

# Generate TLS private key for SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key-latest"
  public_key = tls_private_key.ssh_key.public_key_openssh
  
  tags = {
    Name        = "${var.project_name}-ssh-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Generate random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Store SSH private key in Vault at a fixed path
resource "vault_generic_secret" "ssh_private_key" {
  path = "secret/${var.project_name}/ssh-keys/latest"
  
  data_json = jsonencode({
    private_key = tls_private_key.ssh_key.private_key_pem
    public_key  = tls_private_key.ssh_key.public_key_openssh
    key_name    = aws_key_pair.deployer.key_name
    instance_id = aws_instance.rhel_server.id
    public_ip   = aws_instance.rhel_server.public_ip
  })
}

# Get latest RHEL AMI
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's official AWS account ID
  
  filter {
    name   = "name"
    values = ["RHEL-9*_HVM-*-x86_64-*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create security group
resource "aws_security_group" "rhel_server" {
  name_prefix = "${var.project_name}-sg-"
  description = "Security group for RHEL server"
  vpc_id      = aws_vpc.main.id
  
  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }
  
  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "${var.project_name}-security-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create RHEL EC2 instance
resource "aws_instance" "rhel_server" {
  ami                    = data.aws_ami.rhel.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.rhel_server.id]
  
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }
  
  user_data = <<-EOF
              #!/bin/bash
              echo "Server provisioned by Terraform" > /tmp/terraform-provisioned.txt
              EOF
  
  tags = {
    Name        = "${var.project_name}-rhel-server"
    Environment = var.environment
    ManagedBy   = "Terraform"
    OS          = "RHEL"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Launch existing AAP workflow job template after instance is ready
resource "aap_workflow_job" "configure_server" {
  workflow_job_template_id = var.aap_workflow_job_template_id
  
  # Wait for instance to be ready and SSH key stored
  depends_on = [
    aws_instance.rhel_server,
    vault_generic_secret.ssh_private_key
  ]
}