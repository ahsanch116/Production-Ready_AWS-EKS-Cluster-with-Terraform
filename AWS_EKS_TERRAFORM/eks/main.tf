# KMS Key for EKS
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name} secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation = true

  tags = merge (
    var.tags,
    {     
         "Name" = "${var.cluster_name}-eks-kms-key"
    }
  )

}

# Creates a human-readable name (alias) for a KMS encryption key and links it to the actual key
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks-kms-key"
  target_key_id = aws_kms_key.eks.id
  
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = var.tags

}

# Cluster security group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS cluster ${var.cluster_name}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }

  tags = merge (
    var.tags,
    {     
         "Name" = "${var.cluster_name}-eks-cluster-sg"
    }
  )
    lifecycle {
      create_before_destroy = true
    }
}

# Worker nodes security group
resource "aws_security_group" "eks_worker" {
  name        = "${var.cluster_name}-eks-worker-sg"
  description = "Security group for EKS worker nodes ${var.cluster_name}"
  vpc_id      = var.vpc_id

    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
  tags = merge (
    var.tags,
    {     
         "Name" = "${var.cluster_name}-eks-worker-sg"
          "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
    lifecycle {
      create_before_destroy = true
    }

}

# Allows worker nodes to communicate with the cluster control plane
resource "aws_security_group_rule" "eks_worker_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_worker.id
    description = "Allow worker nodes to communicate with EKS cluster control plane"
}

# Allows cluster control plane to communicate with worker nodes
resource "aws_security_group_rule" "eks_cluster_to_worker" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_worker.id
  source_security_group_id = aws_security_group.eks_cluster.id
    description = "Allow EKS cluster control plane to communicate with worker nodes"
}

# Allows worker nodes to communicate with each other
resource "aws_security_group_rule" "eks_worker_to_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_worker.id
  self = true
    description = "Allow worker nodes to communicate with each other"
}

# EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs    = var.public_access_cidrs
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

 enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_cloudwatch_log_group.eks
  ]

  tags = var.tags
}

# OIDC provider for EKS cluster authentication
data "tls_certificate" "cluster" {
    count = var.enable_irsa ? 1 : 0
    url   = aws_eks_cluster.eks.identity[0].oidc[0].issuer
  
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count           = var.enable_irsa ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

# EKS addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name   = aws_eks_cluster.eks.name
  addon_name     = "vpc-cni"
  addon_version  = var.vpc_cni_version != "" ? var.vpc_cni_version : null
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  tags = var.tags
    
}
# Add  addon CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name   = aws_eks_cluster.eks.name
  addon_name     = "coredns"
  addon_version  = var.coredns_version != "" ? var.coredns_version : null
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
    
  depends_on = [aws_eks_node_group.eks]
  tags = var.tags
    
}

#cube-proxy addon

resource "aws_eks_addon" "kube_proxy" {
  cluster_name   = aws_eks_cluster.eks.name
  addon_name     = "kube-proxy"
  addon_version  = var.kube_proxy_version != "" ? var.kube_proxy_version : null
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  tags = var.tags
}

#launch template for EKS worker nodes
resource "aws_launch_template" "eks_worker" {
    for_each = var.node_groups
    name_prefix   = "${var.cluster_name}-${each.key}-worker-"
    description   = "Launch template for EKS worker nodes in node group ${each.key}"

    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = lookup(each.value, "disk_size", 20)
            volume_type = "gp3"
            iops        = 3000
            throughput   = 125
            delete_on_termination = true
            encrypted = true
        }
    }

    metadata_options {
        http_tokens = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags = "enabled"
        http_endpoint = "enabled"
    }
     network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [aws_security_group.eks_worker.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        "Name" = "${var.cluster_name}-${each.key}-worker"
      }
    )
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# EKS Node Groups
resource "aws_eks_node_group" "eks" {
    for_each = var.node_groups

    cluster_name    = aws_eks_cluster.eks.name
    node_group_name = each.key
    node_role_arn   = var.node_role_arn
    subnet_ids      = var.subnet_ids
    version = var.kubernetes_version
    
    scaling_config {
        desired_size = each.value.desired_size
        max_size     = each.value.max_size
        min_size     = each.value.min_size
    }
    
    instance_types = each.value.instance_types
    capacity_type  = lookup(each.value, "capacity_type", null)
    
    labels = lookup(each.value, "labels", {})

    dynamic "taint" {
      for_each = coalesce(lookup(each.value, "taints", null), [])
        content {
            key    = taint.value.key
            value  = taint.value.value
            effect = taint.value.effect
        }
    }

    launch_template {
      id = aws_launch_template.eks_worker[each.key].id
      version = aws_launch_template.eks_worker[each.key].latest_version
    }

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {})
  )
    
    depends_on = [
        aws_eks_addon.vpc_cni,
        aws_eks_addon.kube_proxy,
    ]
    lifecycle {
      ignore_changes = [ scaling_config[0].desired_size ]
    }
    }