# DevOps Portfolio Project — Terraform + EKS + CI/CD

A small end-to-end project demonstrating Infrastructure as Code, container
orchestration, and automated deployment on AWS.

## Architecture

- **Terraform** provisions a VPC (public + private subnets, NAT gateway) and
  an EKS cluster with a managed node group — written as reusable modules
  (`modules/vpc`, `modules/eks`) rather than one flat file.
- **Docker** containerizes a small Flask app (`app/`).
- **Kubernetes manifests** (`k8s/`) deploy the app to EKS with a rolling
  update strategy, resource limits, and readiness/liveness probes.
- **GitHub Actions** (`.github/workflows/deploy.yml`) builds the image on
  every push to `main`, pushes it to Amazon ECR, and rolls it out to EKS
  automatically.

## Why these choices

- **EKS over ECS**: chosen to demonstrate Kubernetes-specific skills
  (manifests, rolling updates, probes) relevant to DevOps/SRE roles.
- **t3.small nodes, single node group**: kept small deliberately to control
  AWS cost during development — this is not sized for production load.
- **Terraform modules**: split into `vpc` and `eks` so either can be reused
  independently or swapped out later (e.g. adding a second environment).

## Running it yourself

1. Create an ECR repository named `devops-portfolio-app` in your AWS account.
2. `cd terraform && terraform init && terraform apply`
3. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as GitHub Actions
   secrets in your repo settings.
4. Push a change under `app/` to `main` — the pipeline builds, pushes, and
   deploys automatically.
5. `kubectl get svc devops-portfolio-app` to get the LoadBalancer URL once
   deployed.

## Tearing down

`cd terraform && terraform destroy` — do this after you're done demoing to
avoid ongoing AWS charges (NAT gateway and the EKS control plane both incur
hourly cost even when idle).

## What broke, and how it was fixed

_(Fill this in once you've actually hit an issue — e.g. a bad rollout, a
misconfigured probe, an IAM permission gap. This section is the most
valuable part of the whole repo for interviews — it's proof you debugged a
real system, not just followed a tutorial.)_
