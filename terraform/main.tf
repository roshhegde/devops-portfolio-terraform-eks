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

# All resources come from roshhegde/tfmodules, pinned to a commit so this
# stack does not change when the modules repo changes.
locals {
  tfmodules = "git::https://github.com/roshhegde/tfmodules.git//modules"
  tfmodules_ref = "?ref=2fd8bc1983dc436d6a6dcccd60f4255bb81a26e6"

  # Keyed by AZ name; the index drives CIDR allocation.
  azs = { for i, az in var.availability_zones : az => i }

  # Edit access is scoped to the cluster, which is enough for kubectl apply.
  ci_access = var.ci_role_arn == null ? {} : {
    ci = {
      principal_arn = var.ci_role_arn
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
    }
  }
}

module "vpc" {
  source   = "${local.tfmodules}/vpc${local.tfmodules_ref}"
  name     = var.project_name
  vpc_cidr = var.vpc_cidr
}

module "igw" {
  source = "${local.tfmodules}/internet-gateway${local.tfmodules_ref}"
  name   = var.project_name
  vpc_id = module.vpc.vpc_id
}

module "public_subnet" {
  source   = "${local.tfmodules}/subnet${local.tfmodules_ref}"
  for_each = local.azs

  name                    = "${var.project_name}-public-${each.value}"
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags                    = { "kubernetes.io/role/elb" = "1" }
}

module "private_subnet" {
  source   = "${local.tfmodules}/subnet${local.tfmodules_ref}"
  for_each = local.azs

  name              = "${var.project_name}-private-${each.value}"
  vpc_id            = module.vpc.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  availability_zone = each.key
  tags              = { "kubernetes.io/role/internal-elb" = "1" }
}

module "nat" {
  source           = "${local.tfmodules}/nat-gateway${local.tfmodules_ref}"
  name             = var.project_name
  public_subnet_id = module.public_subnet[var.availability_zones[0]].subnet_id
}

module "public_rt" {
  source = "${local.tfmodules}/route-table${local.tfmodules_ref}"
  name   = "${var.project_name}-public"
  vpc_id = module.vpc.vpc_id
}

module "private_rt" {
  source = "${local.tfmodules}/route-table${local.tfmodules_ref}"
  name   = "${var.project_name}-private"
  vpc_id = module.vpc.vpc_id
}

module "public_default_route" {
  source                 = "${local.tfmodules}/route${local.tfmodules_ref}"
  route_table_id         = module.public_rt.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.igw.internet_gateway_id
}

module "private_default_route" {
  source                 = "${local.tfmodules}/route${local.tfmodules_ref}"
  route_table_id         = module.private_rt.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat.nat_gateway_id
}

module "public_assoc" {
  source   = "${local.tfmodules}/route-table-association${local.tfmodules_ref}"
  for_each = module.public_subnet

  subnet_id      = each.value.subnet_id
  route_table_id = module.public_rt.route_table_id
}

module "private_assoc" {
  source   = "${local.tfmodules}/route-table-association${local.tfmodules_ref}"
  for_each = module.private_subnet

  subnet_id      = each.value.subnet_id
  route_table_id = module.private_rt.route_table_id
}

module "eks_cluster" {
  source = "${local.tfmodules}/eks-cluster${local.tfmodules_ref}"

  name                = var.project_name
  kubernetes_version  = var.cluster_version
  subnet_ids          = [for az in var.availability_zones : module.private_subnet[az].subnet_id]
  public_access_cidrs = var.api_public_access_cidrs
  access_entries      = local.ci_access
}

module "node_group" {
  source = "${local.tfmodules}/eks-node-group${local.tfmodules_ref}"

  name           = var.project_name
  cluster_name   = module.eks_cluster.cluster_name
  subnet_ids     = [for az in var.availability_zones : module.private_subnet[az].subnet_id]
  instance_types = [var.node_instance_type]
  desired_size   = var.desired_nodes
  min_size       = 1
  max_size       = var.desired_nodes + 1

  # Nodes need the NAT route to reach ECR and the EKS API when they join.
  depends_on = [module.private_default_route, module.private_assoc]
}
