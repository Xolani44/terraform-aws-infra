# Terraform AWS Infra

Modular AWS network infrastructure — VPC, public and private subnets,
internet gateway, and NAT gateway — provisioned entirely with Terraform
using a reusable module structure.

## Purpose

Built to understand Infrastructure as Code from scratch: how Terraform
providers, resources, modules, and state work together, and how AWS
networking fundamentals (VPC, subnets, gateways, routing) fit together
before building compute and event-driven services on top of them.

This project is intentionally built incrementally and documented as it
grows, rather than generated all at once — the goal is genuine
understanding of each AWS/Terraform concept, not just a working `apply`.

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

- **VPC** — an isolated private network within AWS. Every resource you
  create on AWS lives inside a VPC.
- **Public Subnet** — a subdivision of the VPC with a direct route to the
  internet via the Internet Gateway. Resources placed here can be reached
  from outside AWS.
- **Private Subnet** — a subdivision of the VPC with no direct inbound
  route from the internet. Resources here (e.g. future Lambda functions)
  stay unreachable from outside AWS, but can still reach out via the NAT
  Gateway.
- **Internet Gateway** — connects the VPC to the public internet. Without
  it, nothing inside the VPC can communicate externally.
- **NAT Gateway** — lives in the public subnet, but exists to give private
  subnet resources outbound-only internet access (e.g. calling AWS APIs)
  without exposing them to inbound traffic. Requires an Elastic IP.
- **Route Tables** — one per subnet type. The public route table sends
  traffic through the Internet Gateway; the private route table sends
  traffic through the NAT Gateway. This distinction is what actually makes
  a subnet "public" or "private" — the labels alone do nothing without it.
- **Route Table Associations** — attach each route table to its subnet so
  the routing rules actually apply.

## Tech Stack

- Terraform 1.15
- AWS Provider (`hashicorp/aws` ~> 5.0)
- AWS VPC (networking — VPC, subnets, internet gateway, NAT gateway, route
  tables)

## Project Structure

The project uses a **root module calling a child module**, rather than a
flat file layout. This keeps networking logic self-contained, reusable,
and easy to extend as new modules (compute, event-driven pipeline) are
added.

```
terraform-aws-infra/
├── main.tf                    # Calls the networking module, passes variables
├── variables.tf                # Root-level input variables with defaults
├── outputs.tf                  # Exposes module outputs after apply
├── providers.tf                 # Terraform and AWS provider configuration
├── modules/
│   └── networking/
│       ├── main.tf             # VPC, subnets, gateways, route tables
│       ├── variables.tf        # Module input variables
│       └── outputs.tf          # Values exposed to the root module
├── .gitignore
└── README.md
```

A module's resources are private by default — `outputs.tf` inside
`modules/networking/` is what exposes values like `vpc_id` so the root
module (and future modules like `compute`) can reference them via
`module.networking.vpc_id`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
  (`aws configure`) with valid credentials
- An AWS account

## Run Locally

**1. Clone the repository:**

```bash
git clone https://github.com/Xolani44/terraform-aws-infra.git
cd terraform-aws-infra
```

**2. Initialize Terraform:**

```bash
terraform init
```

Downloads the AWS provider plugin and registers the local `networking`
module.

**3. Review the plan:**

```bash
terraform plan
```

Shows exactly what Terraform will create, without making any changes yet.
Always review this before applying.

**4. Apply the changes:**

```bash
terraform apply
```

Type `yes` when prompted. This creates real resources in your AWS account.

**5. Destroy when done:**

```bash
terraform destroy
```

Removes all resources created by this configuration. Important to run
this for learning/test infrastructure — the NAT Gateway in particular
incurs an hourly cost while running, unlike the VPC/subnets/IGW.

## Variables

| Variable | Description | Default |
|----------|--------------|---------|
| `aws_region` | AWS region to deploy into | `af-south-1` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `subnet_cidr` | CIDR block for the public subnet | `10.0.1.0/24` |
| `private_subnet_cidr` | CIDR block for the private subnet | `10.0.2.0/24` |
| `project_name` | Name prefix for all resources | `terraform-aws-infra` |

Override any of these by creating a `terraform.tfvars` file or passing
`-var="vpc_cidr=..."` on the command line.

## Outputs

| Output | Description |
|--------|--------------|
| `vpc_id` | The ID of the created VPC |
| `public_subnet_id` | The ID of the public subnet |
| `private_subnet_id` | The ID of the private subnet |
| `internet_gateway_id` | The ID of the Internet Gateway |
| `nat_gateway_id` | The ID of the NAT Gateway |

## Decisions & Trade-offs

- Refactored from a flat file layout into a `modules/networking` child
  module — cleaner separation of concerns and reusable if a second VPC is
  ever needed for another project
- Rejected an `environments/dev` layering approach as unnecessary overhead
  for a solo portfolio project with a single deployment target
- Used local Terraform state (`.tfstate`) for simplicity — fine for solo
  learning, but not suitable for team environments where state needs to
  be shared and locked
- Used input variables with sensible defaults instead of hardcoded values,
  so the configuration can be reused for different regions or CIDR ranges
  without editing resource definitions
- Availability zones are looked up dynamically via
  `data.aws_availability_zones` rather than hardcoded, so the config
  doesn't silently break if AZ naming differs across regions
- Chose destroy-and-recreate over `terraform state mv` when migrating to
  the module structure, since the AWS account was clean with no orphaned
  resources — simpler and lower-risk for a small resource count
- `.tfstate` files are excluded from Git since they can contain sensitive
  data and are environment-specific; `.terraform.lock.hcl` is committed
  to lock provider versions

## What I'd Improve

- Move state to a remote backend (S3 bucket with DynamoDB locking) instead
  of local state — required for any real team or production setup
- Add a `modules/compute` module: Lambda + API Gateway + DynamoDB, with
  the Lambda deployed into the private subnet
- Add a `modules/security` module for scoped security groups, rather than
  relying on defaults
- Add an event-driven pipeline (S3 → Lambda → SNS/SQS) as a further
  extension once the REST API is in place
- Add a CI/CD pipeline that runs `terraform plan` on pull requests

## Roadmap

1. ✅ Networking foundation — VPC, public/private subnets, NAT gateway
2. ⬜ Serverless REST API — Lambda + API Gateway + DynamoDB, inside the VPC
3. ⬜ Event-driven pipeline — S3 → Lambda → SNS/SQS