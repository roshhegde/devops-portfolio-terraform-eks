# Bootstrap stack: ECR and the GitHub deploy role.
# Apply this once, from your machine, before the main stack. The CI role
# cannot create itself, so this stack is applied by hand.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  cluster_arn = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-cluster"
}

module "ecr" {
  source = "git::https://github.com/roshhegde/tfmodules.git//modules/ecr-repository?ref=2fd8bc1983dc436d6a6dcccd60f4255bb81a26e6"

  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"
}

# Only what the pipeline needs: push to this one repository, and read the
# cluster endpoint for kubeconfig. Nothing else.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [module.ecr.repository_arn]
  }

  statement {
    sid       = "EksDescribe"
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }
}

module "ci_role" {
  source = "git::https://github.com/roshhegde/tfmodules.git//modules/iam-github-oidc?ref=2fd8bc1983dc436d6a6dcccd60f4255bb81a26e6"

  role_name          = "${var.project_name}-github-deploy"
  github_repository  = var.github_repository
  github_ref         = "refs/heads/main"
  inline_policy_json = data.aws_iam_policy_document.deploy.json
}
