# Production-Ready AWS EKS Infrastructure with Custom Terraform Modules

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Custom Modules Explained](#custom-modules-explained)
4. [Resources Provisioned](#resources-provisioned)
5. [Component Purpose & Dependencies](#component-purpose--dependencies)
6. [Step-by-Step Deployment](#step-by-step-deployment)
7. [Verification & Testing](#verification--testing)
8. [Cost Breakdown](#cost-breakdown)
9. [Cleanup](#cleanup)

---

## 🎯 Project Overview

This project demonstrates **production-ready EKS cluster deployment** using **custom Terraform modules** instead of public community modules. The infrastructure showcases enterprise-level practices including:

- ✅ **Full infrastructure ownership** - Every resource is defined in custom modules
- ✅ **Multi-AZ high availability** - 3 availability zones for fault tolerance
- ✅ **Security best practices** - KMS encryption, IRSA, private subnets
- ✅ **Cost optimization** - Single NAT Gateway, Spot instances
- ✅ **Modular design** - Reusable modules for VPC, IAM, EKS, Secrets Manager

### Why Custom Modules?

| Aspect | Public Modules | Custom Modules (This Project) |
|--------|----------------|-------------------------------|
| **Control** | Limited | ✅ Full control over every resource |
| **Learning** | Abstract complexity | ✅ Learn exactly how EKS works |
| **Customization** | Pre-defined patterns | ✅ Tailor to your needs |
| **Transparency** | Need to read source code | ✅ All code is local & clear |
| **Enterprise Use** | Version dependencies | ✅ Self-maintained, no surprises |

---

## 🏗️ Architecture Diagram

<img width="3064" height="1015" alt="Blank diagram (1)" src="https://github.com/user-attachments/assets/84a7bb13-34f1-4bf6-a3aa-baf957ac2b00" />


### Traffic Flow

1. **Internet → IGW** - External traffic enters through Internet Gateway
2. **IGW → Public Subnets** - Routed to public subnets
3. **Public Subnets → NAT Gateway** - Outbound traffic from private subnets
4. **NAT → Private Subnets** - NAT translates private IPs to public
5. **Private Subnets → EKS** - Kubernetes nodes communicate internally
6. **EKS → Internet** - Pods reach internet via NAT Gateway

---

## 📦 Custom Modules Explained

### Module 1: VPC Module (`modules/vpc/`)

**Purpose:** Creates the networking foundation for EKS cluster.

**Why We Need It:**
- EKS requires specific VPC configuration with public and private subnets
- Proper subnet tagging is critical for Kubernetes service discovery
- NAT Gateway enables private nodes to access internet (for pulling images, updates)

**Resources Created:**
- 1 VPC (10.0.0.0/16)
- 3 Public Subnets (across 3 AZs)
- 3 Private Subnets (across 3 AZs)
- 1 Internet Gateway
- 1 NAT Gateway (cost optimization - single NAT)
- 1 Elastic IP (for NAT Gateway)
- Route Tables (public + private)
- Route Table Associations

**Key Features:**
```hcl
# Automatic EKS subnet tagging
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"  # For public load balancers
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"  # For internal LBs
}
```

**Why These Components:**
- **Internet Gateway:** Required for public subnet internet access
- **NAT Gateway:** Allows private subnets (EKS nodes) to reach internet without exposing them
- **Multiple AZs:** High availability - if one AZ fails, others continue working
- **Subnet Tagging:** Kubernetes uses these tags to automatically create load balancers

---

### Module 2: IAM Module (`modules/iam/`)

**Purpose:** Creates IAM roles and policies for EKS cluster and worker nodes.

**Why We Need It:**
- EKS control plane needs permissions to manage AWS resources
- Worker nodes need permissions to join cluster and run workloads
- OIDC enables pods to assume IAM roles (IRSA - IAM Roles for Service Accounts)

**Resources Created:**
- EKS Cluster IAM Role
- EKS Node Group IAM Role
- IAM Policy Attachments (AWS managed policies)
  - `AmazonEKSClusterPolicy`
  - `AmazonEKSVPCResourceController`
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEKS_CNI_Policy`
  - `AmazonEC2ContainerRegistryReadOnly`

**Why These Components:**
- **Cluster Role:** EKS control plane needs to create/manage load balancers, security groups
- **Node Role:** Worker nodes need to pull container images, register with cluster
- **Separate Roles:** Principle of least privilege - different permissions for different components

**How It Works:**
```
EKS Cluster → Assumes Cluster Role → Creates Load Balancers, Security Groups
Worker Nodes → Assumes Node Role → Pulls Images, Joins Cluster, Runs Pods
```

---

### Module 3: EKS Module (`modules/eks/`)

**Purpose:** Creates the Kubernetes cluster and worker nodes.

**Why We Need It:**
- Provisions the actual Kubernetes control plane
- Creates managed node groups (worker nodes)
- Configures cluster security, logging, and encryption

**Resources Created:**

**Control Plane:**
- EKS Cluster
- KMS Key (for etcd encryption)
- CloudWatch Log Group (cluster logs)
- Cluster Security Group

**Worker Nodes:**
- 2 Node Groups (general + spot)
- Launch Templates (with custom configurations)
- Node Security Group

**Add-ons:**
- CoreDNS (DNS for Kubernetes)
- kube-proxy (Network proxy)
- VPC CNI (AWS networking for pods)

**IRSA (IAM Roles for Service Accounts):**
- OIDC Provider (enables pod-level IAM permissions)

**Why These Components:**

1. **KMS Encryption:**
   ```hcl
   encryption_config {
     resources = ["secrets"]  # Encrypts Kubernetes secrets in etcd
   }
   ```
   - **Why:** Kubernetes secrets contain sensitive data (passwords, tokens)
   - **Benefit:** Even if someone accesses etcd database, secrets are encrypted

2. **CloudWatch Logs:**
   ```hcl
   enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
   ```
   - **Why:** Monitor cluster health, troubleshoot issues, security audits
   - **Benefit:** Centralized logging for debugging and compliance

3. **Security Groups:**
   - **Cluster SG:** Controls traffic to/from control plane
   - **Node SG:** Controls traffic to/from worker nodes
   - **Why:** Network-level security, restrict unauthorized access

4. **Node Groups:**
   - **General (ON_DEMAND):** Stable, always-available nodes for critical workloads
   - **Spot (SPOT):** 90% cheaper, but can be terminated - for batch jobs
   - **Why:** Cost optimization while maintaining reliability

5. **Launch Templates:**
   ```hcl
   metadata_options {
     http_tokens = "required"  # IMDSv2 enforced
   }
   
   ebs {
     encrypted = true  # All volumes encrypted
   }
   ```
   - **Why:** Security hardening, encryption at rest
   - **Benefit:** Protects against metadata service attacks

6. **OIDC Provider:**
   - **Why:** Enables Kubernetes pods to assume IAM roles
   - **Example:** Pod needs to access S3 bucket - instead of storing AWS keys, pod assumes IAM role
   - **Benefit:** No credentials in code, better security

---



EKS cluster DOES encrypt Kubernetes secrets also:

```hcl
# modules/eks/main.tf
encryption_config {
  resources = ["secrets"]  # Kubernetes secrets encrypted with KMS
}
```

**Example of Kubernetes Secret (encrypted by EKS KMS key):**
```bash
# Create a Kubernetes secret
kubectl create secret generic my-app-secret \
  --from-literal=api-key=abc123

# This secret is automatically encrypted in etcd using the KMS key
```

**Cost Impact:**
- Current setup: $0 (not deployed)
- If enabled: ~$2-3/month (1 KMS key + secrets storage)

**Note:** This is an optional module for demonstration purposes. The infrastructure works perfectly without it since there's no database or external APIs requiring secret storage.

---

## 📊 Resources Provisioned

### Complete Resource List (44 Resources)

**Note:** The Secrets Manager module is included in the code but NOT deployed (0 resources). Only VPC, IAM, and EKS modules are active.

#### VPC Module (18 resources)
```
✅ aws_vpc.main                              # VPC
✅ aws_internet_gateway.main                 # Internet Gateway
✅ aws_eip.nat[0]                           # Elastic IP for NAT
✅ aws_nat_gateway.main[0]                  # NAT Gateway
✅ aws_subnet.public[0]                     # Public Subnet 1
✅ aws_subnet.public[1]                     # Public Subnet 2
✅ aws_subnet.public[2]                     # Public Subnet 3
✅ aws_subnet.private[0]                    # Private Subnet 1
✅ aws_subnet.private[1]                    # Private Subnet 2
✅ aws_subnet.private[2]                    # Private Subnet 3
✅ aws_route_table.public                   # Public Route Table
✅ aws_route.public_internet_gateway        # Route to IGW
✅ aws_route_table_association.public[0]    # Public RT Association 1
✅ aws_route_table_association.public[1]    # Public RT Association 2
✅ aws_route_table_association.public[2]    # Public RT Association 3
✅ aws_route_table.private[0]               # Private Route Table
✅ aws_route.private_nat_gateway[0]         # Route to NAT
✅ aws_route_table_association.private[0]   # Private RT Association 1
✅ aws_route_table_association.private[1]   # Private RT Association 2
✅ aws_route_table_association.private[2]   # Private RT Association 3
```

#### IAM Module (8 resources)
```
✅ aws_iam_role.cluster                                    # EKS Cluster Role
✅ aws_iam_role_policy_attachment.cluster_policy          # Cluster Policy 1
✅ aws_iam_role_policy_attachment.cluster_vpc_controller  # Cluster Policy 2
✅ aws_iam_role.node_group                                # Node Group Role
✅ aws_iam_role_policy_attachment.node_worker_policy      # Node Policy 1
✅ aws_iam_role_policy_attachment.node_cni_policy         # Node Policy 2
✅ aws_iam_role_policy_attachment.node_registry_policy    # Node Policy 3
```

#### EKS Module (18 resources)
```
✅ aws_kms_key.eks                          # KMS Key for EKS
✅ aws_kms_alias.eks                        # KMS Alias
✅ aws_cloudwatch_log_group.eks             # CloudWatch Log Group
✅ aws_security_group.cluster               # Cluster Security Group
✅ aws_security_group.node                  # Node Security Group
✅ aws_security_group_rule.node_to_cluster  # SG Rule 1
✅ aws_security_group_rule.cluster_to_node  # SG Rule 2
✅ aws_security_group_rule.node_to_node     # SG Rule 3
✅ aws_eks_cluster.main                     # EKS Cluster
✅ aws_iam_openid_connect_provider.cluster  # OIDC Provider
✅ aws_eks_addon.coredns                    # CoreDNS Addon
✅ aws_eks_addon.kube_proxy                 # kube-proxy Addon
✅ aws_eks_addon.vpc_cni                    # VPC CNI Addon
✅ aws_launch_template.node["general"]      # General Launch Template
✅ aws_launch_template.node["spot"]         # Spot Launch Template
✅ aws_eks_node_group.main["general"]       # General Node Group
✅ aws_eks_node_group.main["spot"]          # Spot Node Group
```

**Total:** 44 active resources (VPC + IAM + EKS only)

---

## 🔗 Component Purpose & Dependencies

### Dependency Chain

```
1. VPC Module
   ↓ (provides: vpc_id, subnet_ids)
2. IAM Module
   ↓ (provides: cluster_role_arn, node_role_arn)
3. EKS Module
   ↓ (uses: vpc_id, subnet_ids, IAM roles)
   ↓ (creates: OIDC provider, KMS key for K8s secrets)

```




### How Components Work Together

#### Example: Pod Accessing S3 Bucket

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Pod wants to access S3 bucket                                │
│    ↓                                                             │
│ 2. Pod uses Kubernetes Service Account with annotation          │
│    eks.amazonaws.com/role-arn: arn:aws:iam::...:role/s3-reader  │
│    ↓                                                             │
│ 3. EKS OIDC Provider validates the service account              │
│    ↓                                                             │
│ 4. AWS STS issues temporary credentials                         │
│    ↓                                                             │
│ 5. Pod uses temporary credentials to access S3                  │
│    ↓                                                             │
│ 6. Success! Pod reads/writes to S3 without storing AWS keys     │
└─────────────────────────────────────────────────────────────────┘
```

#### Example: User Accessing Application

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User visits website (app.example.com)                        │
│    ↓                                                             │
│ 2. DNS resolves to AWS Load Balancer (in public subnet)         │
│    ↓                                                             │
│ 3. Load Balancer forwards to EKS Service (internal)             │
│    ↓                                                             │
│ 4. Service routes to Pod on worker node (in private subnet)     │
│    ↓                                                             │
│ 5. Pod processes request, may access RDS/S3                     │
│    ↓                                                             │
│ 6. Response returns through Load Balancer to user               │
└─────────────────────────────────────────────────────────────────┘
```

### Why Each Layer Matters

| Layer | Purpose | Without It... |
|-------|---------|---------------|
| **VPC** | Network isolation | No place to deploy resources |
| **Public Subnets** | Internet-facing resources | Can't receive external traffic |
| **Private Subnets** | Protected workloads | Nodes exposed to internet |
| **IGW** | Public internet access | Public subnets can't reach internet |
| **NAT** | Private internet access | Nodes can't pull images/updates |
| **IAM Roles** | AWS permissions | Nodes/pods can't access AWS services |
| **Security Groups** | Network firewall | Unrestricted access (security risk) |
| **KMS** | Data encryption | Secrets stored in plain text |
| **OIDC** | Pod-level IAM | Need to hardcode AWS credentials |
| **CloudWatch** | Logging & monitoring | No visibility into cluster health |

---

## 🚀 Step-by-Step Deployment

### Prerequisites

```bash
# Check prerequisites
aws --version        # AWS CLI v2.x
terraform --version  # Terraform >= 1.3
kubectl version      # kubectl v1.35
```

### Step 1: Clone & Navigate


### Step 2: Review Configurations


### Step 3: Initialize Terraform

```bash
terraform init
```

**What happens:**
- Downloads AWS provider plugin
- Initializes backend (local state)
- Prepares modules

### Step 4: Validate Configuration

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 5: Plan Deployment

```bash
terraform plan
```

**What to look for:**
```
Plan: 44 to add, 0 to change, 0 to destroy.
```

**Review the plan carefully:**
- Check resource names
- Verify CIDR blocks
- Confirm costs

### Step 6: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**What Gets Created:**
```
✅ VPC Module: 18 resources (VPC, subnets, IGW, NAT, routes)
✅ IAM Module: 8 resources (roles, policies)
✅ EKS Module: 18 resources (cluster, nodes, security groups, OIDC)
───────────────────────────────
Total: 44 resources
```

**Timeline:**
```
00:00 - Starting...
01:30 - VPC created (18 resources)
03:00 - IAM roles created (8 resources)
10:00 - EKS cluster creating (this takes time)
15:00 - Node groups creating
25:00 - Complete! ✅ (44 resources deployed)
```

### Step 7: Configure kubectl

```bash
# Get the command from Terraform output
terraform output configure_kubectl

# Or run directly
aws eks --region us-east-1 update-kubeconfig --name AWS_EKS_Terraform
```

**What this does:**
- Adds EKS cluster to ~/.kube/config
- Configures authentication

---

## ✅ Verification & Testing

### 1. Verify Cluster Access

```bash
kubectl cluster-info
```

**Expected output:**
```
Kubernetes control plane is running at https://xxxxx.eks.us-east-1.amazonaws.com
CoreDNS is running at https://xxxxx.eks.us-east-1.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 2. Check Nodes

```bash
kubectl get nodes
```

**Expected output:**
```
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
ip-10-0-3-xxx.ec2.internal   Ready    <none>   5m    v1.31.x
```

**Verify:**
- ✅ 3 nodes total (2 general + 1 spot)
- ✅ All nodes in Ready status
- ✅ Correct Kubernetes version

### 3. Check Add-ons

```bash
kubectl get pods -n kube-system
```

**Expected output:**
```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-xxxxx              1/1     Running   0          10m
coredns-xxxxx              1/1     Running   0          10m
aws-node-xxxxx             2/2     Running   0          5m
aws-node-xxxxx             2/2     Running   0          5m
kube-proxy-xxxxx           1/1     Running   0          5m
```

**Verify:**
- ✅ CoreDNS pods running (2 replicas)
- ✅ VPC CNI (aws-node) running on each node
- ✅ kube-proxy running on each node

### 4. Test Workload Deployment

```bash
# Deploy test nginx app
kubectl create deployment nginx --image=nginx:latest

# Check deployment
kubectl get deployments

# Check pods
kubectl get pods

# Expose as service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get service (wait for EXTERNAL-IP)
kubectl get svc nginx -w
```

**Expected flow:**
```
1. Pod scheduled on worker node ✅
2. Image pulled from Docker Hub (via NAT) ✅
3. Load Balancer created in public subnet ✅
4. External IP assigned ✅
5. Can access nginx via LoadBalancer URL ✅
```

### 5. Verify IAM/OIDC (IRSA)

```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Create test service account with IAM role
kubectl create sa test-sa
kubectl annotate sa test-sa \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT:role/test-role

# Verify
kubectl describe sa test-sa
```

### 6. Check Logs

```bash
# View cluster logs in CloudWatch

# Or via AWS Console:

```

### 7. Verify Encryption


### 8. Test Node Groups


## 💰 Cost Breakdown

### Monthly Costs (us-east-1)

| Component | Cost | Calculation |
|-----------|------|-------------|
| **EKS Control Plane** | $73.00 | $0.10/hour × 730 hours |
| **EC2 Instances** | | |
| └─ General (2x t3.medium) | $60.74 | 2 × $0.0416/hour × 730 hours |
| └─ Spot (1x t3.medium) | $12.41 | 1 × $0.017/hour × 730 hours (70% savings) |
| **NAT Gateway** | | |
| └─ Hourly charge | $32.85 | $0.045/hour × 730 hours |
| └─ Data processing | ~$5-20 | $0.045/GB (varies by usage) |
| **EBS Volumes (60GB total)** | $6.00 | 60 GB × $0.10/GB-month |
| **Data Transfer** | ~$5-10 | First 100GB free, then $0.09/GB |
| **KMS Keys (2)** | $2.00 | 2 × $1/month |
| **CloudWatch Logs** | ~$2-5 | $0.50/GB ingested |
| **Load Balancer** (if created) | $16.20 | $0.0225/hour × 730 hours |
| | | |
| **Total (without LB)** | **~$195-225/month** | |
| **Total (with LB)** | **~$211-241/month** | |

### Cost Optimization Strategies

✅ **Already Implemented:**
- Single NAT Gateway (saves ~$65/month vs 3 NAT Gateways)
- Spot instances for non-critical workloads (saves ~$18/month)
- Right-sized instances (t3.medium sufficient for dev/test)
- Secrets Manager disabled by default (saves ~$1.20/month)

🔧 **Additional Savings (optional):**
- Use Fargate for some workloads (no EC2 costs, pay per pod)
- Schedule non-prod clusters to stop at night (save 50%)
- Use Reserved Instances for production (save 40-60%)
- Enable Cluster Autoscaler to scale down when idle

### Free Tier Eligible

- First 20,000 KMS requests/month
- First 100GB data transfer out/month
- First 5GB CloudWatch Logs ingested/month

---

## 🧹 Cleanup

### Important: Delete Resources in Order

#### Step 1: Delete Kubernetes Services (LoadBalancers)

```bash
# This deletes AWS Load Balancers created by Kubernetes
kubectl delete svc --all

# Wait for LBs to be deleted
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?VpcId==`vpc-xxx`].LoadBalancerArn'
```

**Why:** Terraform doesn't know about Kubernetes-created LBs. If not deleted, they'll remain after `terraform destroy`.

#### Step 2: Delete Kubernetes Deployments/Pods

```bash
kubectl delete deployments --all
kubectl delete pods --all
```

#### Step 3: Destroy Terraform Resources

```bash
terraform destroy
```

Type `yes` when prompted.

**Timeline:**
```
00:00 - Starting destruction...
05:00 - Node groups deleting
15:00 - EKS cluster deleting
18:00 - NAT Gateway deleting
20:00 - VPC resources deleting
22:00 - Complete! ✅
```

#### Step 4: Verify Cleanup

```bash
# Check no EKS clusters
aws eks list-clusters

# Check no EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/day20-eks,Values=owned" \
  --query 'Reservations[].Instances[].InstanceId'

# Check no NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"

# Check CloudWatch logs (optional - can keep for auditing)
aws logs describe-log-groups --log-group-name-prefix /aws/eks/day20
```

#### Step 5: Check for Orphaned Resources

```bash
# Check for lingering security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-xxx" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId'

# Check for lingering ENIs
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=vpc-xxx"
```

**If found, delete manually:**
```bash
aws ec2 delete-security-group --group-id sg-xxx
aws ec2 delete-network-interface --network-interface-id eni-xxx
```

---

## 📚 Additional Resources

### Official Documentation
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Terraform Modules Source Code
- `modules/vpc/` - VPC, subnets, NAT, IGW
- `modules/iam/` - IAM roles, policies, OIDC
- `modules/eks/` - EKS cluster, node groups, add-ons
- `modules/secrets-manager/` - KMS, secrets, IAM policies

### Architecture Files
- `README.md` - Quick start guide
- `CUSTOM_MODULES.md` - Module documentation
- `architecture.md` - Architecture diagrams
- `DEMO_GUIDE.md` - This comprehensive guide

---

## 🔧 Troubleshooting

### Common Issues

**Issue: `terraform apply` fails with "InvalidPermissions"`**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Ensure you have required permissions (AdministratorAccess or EKS permissions)
```

**Issue: Nodes not joining cluster**
```bash
# Check node IAM role has correct policies
aws iam list-attached-role-policies --role-name day20-eks-node-xxx

# Check security group rules
kubectl describe node <node-name>
```

**Issue: Cannot connect with kubectl**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name day20-eks --region us-east-1

# Test authentication
kubectl auth can-i get pods
```

**Issue: Pods can't pull images**
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways

# Check route table has route to NAT
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxx"

# Check node security group allows outbound traffic
```

---
