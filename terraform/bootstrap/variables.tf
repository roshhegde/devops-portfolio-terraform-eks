variable "aws_region" {
  description = "AWS region for the ECR repository and the deploy role"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Must match the main stack's project_name, because the cluster name is derived from it"
  type        = string
  default     = "devops-portfolio"
}

variable "ecr_repository_name" {
  description = "ECR repository name. Must match ECR_REPOSITORY in the deploy workflow."
  type        = string
  default     = "devops-portfolio-app"
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, in owner/repo form"
  type        = string
  default     = "roshhegde/devops-portfolio-terraform-eks"
}
