module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  depends_on = [aws_codepipeline.app]

  name            = local.name_vpc
  cidr            = local.cidr_vpc
  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  map_public_ip_on_launch = true
}
