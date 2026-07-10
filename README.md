# Terraform AWS Infra

Modular AWS network infrastructure — VPC, public and private subnets,
internet gateway, and NAT gateway — provisioned with Terraform using a
reusable module structure.

## Overview

Foundational networking layer for a multi-stage AWS infrastructure
project. The VPC, subnets, and gateways defined here are designed to
support compute workloads (Lambda, API Gateway) and event-driven services
(S3, SNS/SQS) in later stages, without requiring rework of the networking
layer itself.

## Architecture

```
AWS Account
└── VPC (10.0.0.0/16)
    ├── Public Subnet (10.0.1.0/24)
    │   ├── Internet Gateway
    │   ├── Route Table (0.0.0.0/0 → Internet Gateway)
    │   └── NAT Gateway (+ Elastic IP)
    └── Private Subnet (10.0.2.0/24)
        └── Route Table (0.0.0.0/0 → NAT Gateway)
```

- **VPC** — isolated network boundary for all resources in this project.
- **Public Subnet** — routes directly to the internet via the Internet
  Gateway. Hosts internet-facing resources and the NAT Gateway.
- **Private Subnet** — no inbound route from the internet. Reserved for
  internal compute (e.g. Lambda functions) that requires outbound access
  without public exposure.
- **Internet Gateway** — provides the VPC's connection to the public
  internet.
- **NAT Gateway** — deployed in the public subnet; gives private subnet
  resources outbound internet access (e.g. AWS API calls) while keeping
  them unreachable from outside the VPC.
- **Route Tables** — separate tables per subnet enforce the public/private
  boundary: public traffic routes through the Internet Gateway, private
  traffic routes through the NAT Gateway.

## Tech Stack

- Terraform 1.15
- AWS Provider (`hashicorp/aws` ~> 5.0)
- AWS VPC, subnets, Internet Gateway, NAT Gateway, route tables

## Project Structure

Root module composed of a `networking` child module, rather than a flat
file layout — keeps networking logic self-contained and reusable as
additional modules (compute, event-driven pipeline) are added.

```
terraform-aws-infra/
├── main.tf                 # Calls the networking module, passes variables
├── variables.tf             # Root-level input variables
├── outputs.tf                # Exposes module outputs
├── providers.tf               # Terraform and AWS provider configuration
├── modules/
│   └── networking/
│       ├── main.tf          # VPC, subnets, gateways, route tables
│       ├── variables.tf     # Module inputs
│       └── outputs.tf       # Values exposed to the root module
├── .gitignore
└── README.md
```

Module resources are private by default; `outputs.tf` in
`modules/networking/` exposes values (e.g. `vpc_id`) to the root module
and to future modules via `module.networking.vpc_id`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://aws.amazon.com/cli/), configured with valid
  credentials (`aws configure`)
- An AWS account

## Usage

```bash
git clone https://github.com/Xolani44/terraform-aws-infra.git
cd terraform-aws-infra

terraform init      # Installs the AWS provider, registers the networking module
terraform plan       # Review planned changes
terraform apply      # Provision resources (type 'yes' to confirm)
terraform destroy    # Tear down when done
```

The NAT Gateway incurs an hourly cost while running — destroy the stack
when not actively in use.

## Variables

| Variable | Description | Default |
|----------|--------------|---------|
| `aws_region` | AWS region to deploy into | `af-south-1` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `subnet_cidr` | CIDR block for the public subnet | `10.0.1.0/24` |
| `private_subnet_cidr` | CIDR block for the private subnet | `10.0.2.0/24` |
| `project_name` | Name prefix for all resources | `terraform-aws-infra` |

Override via `terraform.tfvars` or `-var="vpc_cidr=..."`.

## Outputs

| Output | Description |
|--------|--------------|
| `vpc_id` | ID of the VPC |
| `public_subnet_id` | ID of the public subnet |
| `private_subnet_id` | ID of the private subnet |
| `internet_gateway_id` | ID of the Internet Gateway |
| `nat_gateway_id` | ID of the NAT Gateway |

## Design Decisions

- **Module structure over flat files** — networking resources live in
  `modules/networking`, isolating them from root-level configuration and
  making the module reusable for a second VPC if needed.
- **No `environments/` layering** — a single deployment target is
  sufficient for this project's scope; added abstraction wasn't
  justified.
- **Dynamic AZ lookup** — `data.aws_availability_zones` avoids hardcoding
  zone names, so the configuration isn't tied to a specific region's AZ
  naming.
- **Destroy-and-recreate migration** — chosen over `terraform state mv`
  when refactoring to the module structure, given a small resource count
  and no orphaned infrastructure to preserve.
- **Local state** — sufficient for a single-maintainer project; flagged
  below as the first thing to change for any team or production use.
- **State files excluded from Git** — `.tfstate` and `.tfstate.backup`
  can contain sensitive data and are environment-specific.
  `.terraform.lock.hcl` is committed to pin provider versions.

## Roadmap

1. ✅ Networking foundation — VPC, public/private subnets, NAT Gateway
2. ⬜ Serverless REST API — Lambda + API Gateway + DynamoDB, deployed into
   the private subnet
3. ⬜ Event-driven pipeline — S3 → Lambda → SNS/SQS

## Next Steps

- Remote state backend (S3 + DynamoDB locking) for team/production use
- `modules/compute` — Lambda + API Gateway + DynamoDB
- `modules/security` — scoped security groups in place of defaults
- Event-driven pipeline module (S3 → Lambda → SNS/SQS)
- CI/CD pipeline running `terraform plan` on pull requests