# IAM Module Outputs

output "cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  
  value       = aws_iam_role.eks_cluster_role.arn
}

output "cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  
  value       = aws_iam_role.eks_cluster_role.name
}

output "node_group_role_arn" {
  description = "ARN of the node group IAM role"
 
  value       = aws_iam_role.eks_node_group_role.arn
}

output "node_group_role_name" {
  description = "Name of the node group IAM role"
 
  value       = aws_iam_role.eks_node_group_role.name
}