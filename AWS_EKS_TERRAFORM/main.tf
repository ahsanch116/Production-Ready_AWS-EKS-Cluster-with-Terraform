#data source
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# custom VPC module
module "vpc" {
  source = "./vpc"

  name_prefix = var.cluster_name
  vpc_cidr = var.vpc_cidr
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  
  enable_nat_gateway = true
  single_nat_gateway = true
#tags for public and private subnets, mainly used for Kubernetes (EKS) integration with AWS
    public_subnet_tags = {
      "kubernetes.io/role/elb"  = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"

    }

    private_subnet_tags = {
      "kubernetes.io/role/internal-elb"  = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  tags = {
    Environment = var.environment
    Project     = "EKS Cluster on AWS"
    Terraform   = "true"
    }
}

# custom IAM module
module "iam" {
  source = "./iam"

  cluster_name = var.cluster_name
  tags = {
    Environment = var.environment
    Project     = "EKS Cluster on AWS"
    Terraform   = "true"
  }
}

# custom EKS module
module "eks" {
  source = "./eks"

  cluster_name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id = module.vpc.vpc_id
  cluster_role_arn = module.iam.cluster_role_arn
  subnet_ids = module.vpc.private_subnet_ids  
  node_role_arn      = module.iam.node_group_role_arn

  endpoint_public_access = true
  endpoint_private_access = true
  public_access_cidrs = ["0.0.0.0/0"]

  enable_irsa = true

   # Node groups configuration
  node_groups = {
    general = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
      capacity_type  = "ON_DEMAND"
      disk_size      = 20

      labels = {
        role = "general"
      }

      tags = {
        NodeGroup = "general"
      }
    }

    spot = {
      instance_types = ["t3.medium", "t3a.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 3
      capacity_type  = "SPOT"
      disk_size      = 20

      labels = {
        role = "spot"
      }

      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      tags = {
        NodeGroup = "spot"
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Project     = "EKS Cluster on AWS"
  }
  depends_on = [ module.iam ]
}