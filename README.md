# Terraform AWS Infra

Foundational AWS network infrastructure — VPC, public subnet, and internet
gateway — provisioned entirely with Terraform.

## Purpose

Built to understand Infrastructure as Code from scratch: how Terraform
providers, resources, and state work together, and how AWS networking
fundamentals (VPC, subnets, gateways, routing) fit together before
building anything on top of them.

## Architecture

```
AWS Account
└── VPC (10.0.0.0/16)
    └── Public Subnet (10.0.1.0/24)
        └── Internet Gateway
            └── Route Table (0.0.0.0/0 → Internet Gateway)
```

- **VPC** — an isolated private network within AWS. Every resource you
  create on AWS lives inside a VPC.
- **Public Subnet** — a subdivision of the VPC with a route to the internet.
  Resources placed here can be reached from outside AWS.
- **Internet Gateway** — connects the VPC to the public internet. Without
  it, nothing inside the VPC can communicate externally.
- **Route Table** — directs traffic. The `0.0.0.0/0` route sends all
  non-local traffic through the Internet Gateway.
- **Route Table Association** — attaches the route table to the public
  subnet so the routing rule actually applies.

## Tech Stack

- Terraform 1.15
- AWS Provider (`hashicorp/aws` ~> 5.0)
- AWS (VPC, EC2 networking services)

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

Downloads the AWS provider plugin and sets up the local working directory.

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
this for learning/test infrastructure to avoid leaving unused resources
behind.

## Variables

| Variable | Description | Default |
|----------|--------------|---------|
| `aws_region` | AWS region to deploy into | `af-south-1` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |
| `subnet_cidr` | CIDR block for the public subnet | `10.0.1.0/24` |
| `project_name` | Name prefix for all resources | `terraform-aws-infra` |

Override any of these by creating a `terraform.tfvars` file or passing
`-var="vpc_cidr=..."` on the command line.

## Outputs

| Output | Description |
|--------|--------------|
| `vpc_id` | The ID of the created VPC |
| `public_subnet_id` | The ID of the public subnet |
| `internet_gateway_id` | The ID of the Internet Gateway |

## Project Structure

```
terraform-aws-infra/
├── providers.tf   # Terraform and AWS provider configuration
├── variables.tf   # Input variables with defaults
├── main.tf        # VPC, subnet, internet gateway, route table resources
└── outputs.tf     # Values displayed after apply
```

## Decisions & Trade-offs

- Used local Terraform state (`.tfstate`) for simplicity — fine for solo
  learning, but not suitable for team environments where state needs to
  be shared and locked
- Split configuration into separate files (`providers.tf`, `variables.tf`,
  `main.tf`, `outputs.tf`) following standard Terraform project conventions
  rather than putting everything in one file
- Used input variables with sensible defaults instead of hardcoded values,
  so the configuration can be reused for different regions or CIDR ranges
  without editing the resource definitions
- `.tfstate` files are excluded from Git since they can contain sensitive
  data and are environment-specific; `.terraform.lock.hcl` is committed
  to lock provider versions

## What I'd Improve

- Move state to a remote backend (S3 bucket with DynamoDB locking) instead
  of local state — required for any real team or production setup
- Add a private subnet alongside the public one, with a NAT Gateway
- Add an EC2 instance into the public subnet to prove end-to-end connectivity
- Add Terraform workspaces or separate `.tfvars` files for dev/staging/prod
- Add a CI/CD pipeline that runs `terraform plan` on pull requests