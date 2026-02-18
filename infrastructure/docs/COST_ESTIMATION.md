# Cost Estimation Documentation (2026 Estimates)

This document provides a monthly cost estimate for the `dev` environment. Estimates are based on AWS pricing as of early 2026.

| Component | Resource Details | Est. Monthly Cost (USD) |
|-----------|------------------|-------------------------|
| **VPC** | NAT Gateway (1) + Data Processing | $32.00 + usage |
| **EKS** | Cluster Management Fee | $73.00 |
| **EKS Nodes** | 2 x t3.medium Instances | $62.00 |
| **RDS** | db.t3.micro (Multi-AZ OFF) | $13.00 |
| **S3** | 100GB Standard + API Requests | $2.50 |
| **EBS** | 40GB GP3 (Nodes + RDS) | $3.20 |
| **ALB** | 1 Application Load Balancer | $18.00 |
| **Total (Est.)** | | **$203.70** |

## Cost Optimization Strategies
1. **Spot Instances**: Use Spot instances for dev/staging node groups to save ~70% on compute.
2. **S3 Lifecycle**: Transition old logs or assets to S3 Glacier Instant Retrieval.
3. **GP3 Volumes**: Utilize GP3 for custom throughput without scaling capacity.
4. **NAT Gateway Alternatives**: For dev environments, use NAT Instances or VPC Endpoints for S3/DynamoDB to reduce NAT GW costs.
