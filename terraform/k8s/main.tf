terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubernetes-alpha = {
      source  = "hashicorp/kubernetes-alpha"
      version = ">= 0.4.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get current AWS caller identity
data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.project_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  enable_irsa = true
  enable_cluster_creator_admin_permissions = true

  # Enable encryption
  cluster_encryption_config = [
  {
    resources        = ["secrets"]
    provider_key_arn = "arn:aws:kms:us-east-1:943538516758:key/595b9719-ce22-429a-a772-87579cb74b04"
  }
]


  eks_managed_node_groups = {
    general = {
      desired_size = var.desired_node_count
      min_size     = var.min_node_count
      max_size     = var.max_node_count

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }

      tags = {
        Environment = var.environment
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for EBS CSI driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  depends_on = [module.eks]
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# IAM role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  depends_on = [module.eks]
}

# Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# Configure kubectl immediately after cluster creation
resource "null_resource" "configure_kubectl" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  }

  depends_on = [module.eks]
}

# Wait for cluster to be fully ready using PowerShell
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "powershell -Command \"Start-Sleep -Seconds 120\""
  }

  depends_on = [null_resource.configure_kubectl]
}

# Kubernetes provider - using exec for authentication
provider "kubernetes" {
  host                   = var.enable_k8s_providers ? module.eks.cluster_endpoint : ""
  cluster_ca_certificate = var.enable_k8s_providers ? base64decode(module.eks.cluster_certificate_authority_data) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]

    env = {}
  }
}


provider "kubernetes-alpha" {
  host                   = var.enable_k8s_providers ? module.eks.cluster_endpoint : ""
  cluster_ca_certificate = var.enable_k8s_providers ? base64decode(module.eks.cluster_certificate_authority_data) : ""

  exec = var.enable_k8s_providers ? {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
    env = {}
  } : null
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}


provider "kubectl" {
  apply_retry_count = 5
  load_config_file  = false

  host                   = var.enable_k8s_providers ? module.eks.cluster_endpoint : ""
  cluster_ca_certificate = var.enable_k8s_providers ? base64decode(module.eks.cluster_certificate_authority_data) : ""

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region
    ]
    env = {}
  }
}

provider "helm" {
  kubernetes {
    host                   = var.enable_k8s_providers ? module.eks.cluster_endpoint : ""
    cluster_ca_certificate = var.enable_k8s_providers ? base64decode(module.eks.cluster_certificate_authority_data) : ""

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region
      ]
      env = {}
    }
  }
}


# EBS CSI Driver addon with service account
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  depends_on = [
    module.eks,
    null_resource.wait_for_cluster,
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
  
  timeouts {
    create = "60m"
    update = "30m"
    delete = "20m"
  }
}

# Wait for EBS CSI driver and verify
resource "null_resource" "wait_for_ebs_csi" {
  provisioner "local-exec" {
    command = <<-EOT
      powershell -Command "Write-Host 'Waiting for EBS CSI driver to be ready...'; Start-Sleep -Seconds 180"
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=300s
    EOT
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Storage Class
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [null_resource.wait_for_ebs_csi]
}

# Wait after storage class creation
resource "null_resource" "wait_for_storage_class" {
  provisioner "local-exec" {
    command = "powershell -Command \"Write-Host 'Waiting for storage class...'; Start-Sleep -Seconds 30\""
  }

  depends_on = [kubernetes_storage_class.ebs_sc]
}

# Application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
  
  depends_on = [null_resource.wait_for_cluster]
}
