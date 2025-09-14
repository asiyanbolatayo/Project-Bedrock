# Project-Bedrock
InnovateMart’s Inaugural EKS Deployment

# Architecture Overview 🏛️

I designed and deployed a cloud-native microservices architecture on Amazon Web Services (AWS) to host the retail-store-sample-app. The infrastructure is fully defined as code using Terraform to ensure consistency and repeatability.

The application runs on a dedicated Amazon EKS (Elastic Kubernetes Service) cluster for high availability and scalability. The cluster’s worker nodes are isolated in private subnets within a custom VPC, which enhances security. To allow the nodes to access the internet for critical tasks like pulling container images from ECR and communicating with the EKS control plane, I provisioned a NAT Gateway in a public subnet.

To expose the application to the internet securely, I used an `Application Load Balancer (ALB)`, managed by the AWS Load Balancer Controller running within the cluster. This ALB automatically handles routing and scaling of the frontend service.

I implemented a comprehensive CI/CD pipeline with GitHub Actions to automate the deployment of my Terraform infrastructure. This pipeline triggers a terraform plan on pull requests for validation and a terraform apply on merges to the main branch to automatically update the infrastructure.

# How to Access the Application 🚀

The application is accessible via a custom domain name I configured in AWS Route 53.

Simply navigate to the following URL in your web browser:
`https://muhammed-innovate-mart.click/`

The ALB handles all incoming traffic, automatically redirecting HTTP requests to HTTPS and routing them to the correct Kubernetes service.

# Read-Only Developer Access 🧑‍💻

To provide secure, read-only access for a developer, I created a dedicated IAM user with limited permissions. This user can view the cluster's resources but cannot modify or delete them.


## kubeconfig Instructions:

You can configure kubectl to use these credentials by running the following command. This command will update your local kubeconfig file and set the context for the EKS cluster.

`aws eks update-kubeconfig --name innovate-mart-eks-cluster --role-arn arn:aws:iam::710271919629:role/eksctl-innovate-mart-eks-cluster-cluster-role --kubeconfig ./kube-config`

Note: The **kube-config file** with the cluster’s details is included in the repository for your convenience. After running the command above, you can use kubectl to interact with the cluster. For example: kubectl get pods -n retail-store.

# Bonus Objective: HTTPS with ACM and Route 53 

I successfully implemented a production-grade HTTPS setup using AWS Certificate Manager (ACM) and Route 53.

First, I requested an SSL certificate for my domain, `muhammed-innovate-mart.click`, from ACM. I used DNS validation to prove ownership of the domain, and ACM automatically issued a valid certificate.

Then, I configured a Kubernetes Ingress resource with specific annotations that instructed the AWS Load Balancer Controller to:

Provision an internet-facing ALB.

Attach the ACM certificate to the ALB to handle HTTPS traffic.

Automatically redirect all incoming HTTP traffic on port 80 to HTTPS on port 443.

Finally, in Route 53, I created an Alias record for my domain. This record points directly to the DNS name of the newly created ALB, ensuring that all traffic to my domain is routed through the load balancer and securely encrypted before reaching the application. This setup provides end-to-end security and a seamless user experience.