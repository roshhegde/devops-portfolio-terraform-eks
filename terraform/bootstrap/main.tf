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
  # Built from known values, not module outputs. A module output is unknown
  # until apply, which would make the inline policy unknown and break the
  # count in the iam-role module.
  cluster_arn = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-cluster"
  ecr_arn     = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
}

module "ecr" {
  source = "git::https://github.com/roshhegde/tfmodules.git//modules/ecr-repository?ref=a8634da613b133e40774cb8b82c890aab46d0644"

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
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [local.ecr_arn]
  }

  statement {
    sid       = "EksDescribe"
    actions   = ["eks:DescribeCluster"]
    resources = [local.cluster_arn]
  }
}

module "ci_role" {
  source = "git::https://github.com/roshhegde/tfmodules.git//modules/iam-github-oidc?ref=a8634da613b133e40774cb8b82c890aab46d0644"

  role_name          = "${var.project_name}-github-deploy"
  github_repository  = var.github_repository
  github_ref         = "refs/heads/main"
  # GitHub puts owner and repo IDs in the token subject. The old format no longer matches.
  subject            = "repo:roshhegde@208154472/devops-portfolio-terraform-eks@1359407300:ref:refs/heads/main"
  inline_policy_json = data.aws_iam_policy_document.deploy.json
}
