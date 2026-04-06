terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "devops-portfolio-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devops-portfolio"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  vpc_cidr    = "10.0.0.0/16"

  tags = {
    Module = "vpc"
  }
}

module "iam" {
  source = "../../modules/iam"

  environment    = var.environment
  s3_bucket_arns = [module.artifacts_bucket.bucket_arn]
  service_name   = "flask-api"

  tags = {
    Module = "iam"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  environment      = var.environment
  instance_type    = "t3.micro"
  ami_id           = data.aws_ami.amazon_linux.id
  subnet_id        = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.vpc.security_group_id]
  user_data        = file("${path.module}/user-data.sh")

  tags = {
    Module = "ec2"
  }

  depends_on = [module.vpc]
}

module "artifacts_bucket" {
  source = "../../modules/s3"

  environment = var.environment
  bucket_name = "artifacts"

  lifecycle_rules = [
    {
      id                                     = "cleanup-old-artifacts"
      enabled                                = true
      expiration_days                        = 90
      transition_to_ia_days                  = 30
      transition_to_glacier_days             = 60
      noncurrent_version_expiration_days     = 30
      noncurrent_version_transition_to_ia    = 14
    }
  ]

  tags = {
    Module = "s3"
  }
}

module "rds" {
  source = "../../modules/rds"

  environment      = var.environment
  db_password      = var.db_password
  db_name          = "appdb"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  subnet_ids       = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.security_group_id]
  multi_az         = false
  backup_retention_period = 7

  tags = {
    Module = "rds"
  }

  depends_on = [module.vpc]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ec2_asg_name" {
  value = module.ec2.asg_name
}

output "db_endpoint" {
  value     = module.rds.db_endpoint
  sensitive = true
}

output "artifact_bucket" {
  value = module.artifacts_bucket.bucket_id
}
