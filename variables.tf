variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "172.0.0.0/16"
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
  default     = "dev-vpc"
}

variable "availability_zones" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  default = [
    "172.0.1.0/24",
    "172.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  default = [
    "172.0.11.0/24",
    "172.0.12.0/24"
  ]
}

variable "ami_name_filter" {
  description = "AMI name pattern for Amazon Linux 2"
  type        = string
  default     = "amzn2-ami-hvm-*-x86_64-gp2"
}

variable "ami_owner" {
  description = "AMI owner account ID"
  type        = list(string)
  default     = ["amazon"]
}