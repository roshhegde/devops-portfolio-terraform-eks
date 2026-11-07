output "ecr_repository_url" {
  description = "ECR repository the pipeline pushes to"
  value       = module.ecr.repository_url
}

output "ci_role_arn" {
  description = "Set this as the AWS_ROLE_ARN GitHub secret, and pass it to the main stack as ci_role_arn"
  value       = module.ci_role.role_arn
}
