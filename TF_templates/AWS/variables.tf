variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "rhel-server"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change this default to your IP for production!
}

# Vault Configuration
variable "vault_addr" {
  description = "HashiCorp Vault address"
  type        = string
  # Set via TF_VAR_vault_addr or in terraform.tfvars
}

variable "vault_role_id" {
  description = "Vault AppRole Role ID for Terraform"
  type        = string
  sensitive   = true
  # Set via TF_VAR_vault_role_id or in terraform.tfvars
}

variable "vault_secret_id" {
  description = "Vault AppRole Secret ID for Terraform"
  type        = string
  sensitive   = true
  # Set via TF_VAR_vault_secret_id or in terraform.tfvars
}

# Ansible Automation Platform Configuration
variable "aap_host" {
  description = "Ansible Automation Platform URL"
  type        = string
  # Example: https://aap.example.com
}

variable "aap_username" {
  description = "AAP username"
  type        = string
  sensitive   = true
}

variable "aap_password" {
  description = "AAP password"
  type        = string
  sensitive   = true
}

variable "aap_workflow_job_template_id" {
  description = "AAP Workflow Job Template ID to execute (already exists in AAP)"
  type        = number
  default     = 2
  # This is the ID of your existing workflow job template in AAP
  # Find it in the URL: https://aap.example.com/#/templates/workflow_job_template/2
}

variable "aap_inventory_id" {
  description = "AAP Inventory ID"
  type        = number
  # Get this from AAP UI or API
  # Find it in the URL when viewing your inventory
}