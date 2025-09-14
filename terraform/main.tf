# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Create a new VPC
resource "aws_vpc" "innovate-mart-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "innovate-mart-vpc"
    Project = "Bedrock"
  }
}

# Create public subnets
resource "aws_subnet" "public" {
  count = 2
  vpc_id = aws_vpc.innovate-mart-vpc.id
  cidr_block = "10.0.${count.index + 1}.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "innovate-mart-public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.innovate-mart-vpc.id
  cidr_block = "10.0.${count.index + 10}.0/24"
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "innovate-mart-private-subnet-${count.index + 10}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.innovate-mart-vpc.id
  tags = {
    Name = "innovate-mart-igw"
  }
}

# Create a route table for public subnets
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.innovate-mart-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate public subnets with the route table
resource "aws_route_table_association" "public-a" {
  count = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public-rt.id
}

# Add a NAT Gateway for internet access from private subnets
resource "aws_eip" "nat" {
  # No attributes are needed for a VPC EIP as it's the default behavior.
  # The 'vpc = true' attribute is now deprecated.
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.gw]
}

# Add a route table and routes for private subnets
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.innovate-mart-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }
}

resource "aws_route_table_association" "private-a" {
  count = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private-rt.id
}

# EKS Cluster and Node Group
# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "innovate-mart-eks-cluster-role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "Service" = "eks.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "innovate-mart-eks" {
  name = "innovate-mart-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [for s in aws_subnet.private : s.id]
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group_role" {
  name = "innovate-mart-eks-node-group-role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "Service" = "ec2.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# EKS Node Group
resource "aws_eks_node_group" "innovate-mart-ng" {
  cluster_name    = aws_eks_cluster.innovate-mart-eks.name
  node_group_name = "innovate-mart-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policy_worker,
    aws_iam_role_policy_attachment.eks_node_group_policy_cni,
    aws_eks_cluster.innovate-mart-eks,
  ]
}

resource "aws_db_instance" "orders_db" {
  identifier            = "innovate-mart-orders"
  engine                = "postgres"
  engine_version        = "11.22-rds.20240509"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  db_name               = "orders"
  username              = "postgres"
  password              = "innovate-mart-pw" # Use a random password generator in a real-world scenario
  skip_final_snapshot   = true
}

resource "aws_db_instance" "catalog_db" {
  identifier            = "innovate-mart-catalog"
  engine                = "mysql"
  engine_version        = "5.7.44-rds.20240529"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  db_name               = "catalog"
  username              = "admin"
  password              = "innovate-mart-pw" # Use a random password generator in a real-world scenario
  skip_final_snapshot   = true
}

resource "aws_dynamodb_table" "carts_table" {
  name         = "Carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customerId"
  attribute {
    name = "customerId"
    type = "S"
  }
}

data "aws_availability_zones" "available" {}
