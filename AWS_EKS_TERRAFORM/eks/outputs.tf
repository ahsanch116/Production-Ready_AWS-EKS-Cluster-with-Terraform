# EKS Module Outputs

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.eks.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.eks.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.eks.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version of the cluster"
  value       = aws_eks_cluster.eks.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.eks_worker.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "")
}

output "node_groups" {
  description = "Map of node group resources"
  value       = aws_eks_node_group.eks
}

output "kms_key_id" {
  description = "KMS key ID used for cluster encryption"
  value       = aws_kms_key.eks.id
}

output "kms_key_arn" {
  description = "KMS key ARN used for cluster encryption"
  value       = aws_kms_key.eks.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.eks.name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : ""
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].url : ""
}