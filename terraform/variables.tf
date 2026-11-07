variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix used for all resources"
  type        = string
  default     = "devops-portfolio"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across (two or more)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes (kept small to control cost)"
  type        = string
  default     = "t3.small"
}

variable "desired_nodes" {
  description = "Desired worker node count"
  type        = number
  default     = 1
}

variable "api_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint. Restrict to your own IP range where possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ci_role_arn" {
  description = "ARN of the GitHub deploy role from the bootstrap stack. Grants it edit access on the cluster. Leave null to skip."
  type        = string
  default     = null
  nullable    = true
}
