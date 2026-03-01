locals {
  # General Information
  name = "eks-argocd"

  # VPC Information
  name_vpc        = "${local.name}-vpc"
  cidr_vpc        = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # EKS Information
  cluster_name    = "${local.name}-cluster"
  cluster_version = "1.35"

  tags = {
    Environment = "Development"
    Terraform   = "true"
    Project     = "Chamo"
  }
}
