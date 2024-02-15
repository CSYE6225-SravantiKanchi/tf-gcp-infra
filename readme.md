# Terraform VPC Creation Guide

## Overview

This README provides instructions for creating a VPC, subnets, and one route specific to a subnet in GCP.

## Prerequisites

- Sign up for GCP.
- Create a Project.
- Disable all the unnecessary APIs.
- Enable the Compute Engine API, which we will be using for resource creation using Terraform.

## Local Setup

- Clone the repo of the main branch.
- Set up gcloud.
- Switch to the created project in gcloud,

```bash
gcloud auth login
gcloud config set project [PROJECT_ID]
```
- Authenticate, which will be used by Terraform for resource creation.

  ```bash
    gcloud auth application-default login
  ```
    
- Once done, revoke the auth login.

    ```bash
    gcloud auth revoke
    gcloud auth application-default revoke
    ```

### Terraform variables configuration

create a terraform.tfvars file, and configure the variables with the required setup

```bash
project_id = "test-project"
region     = "required region"
vpc_config = {
  name                            = "vpc-name"
  delete_default_routes_on_create = true/false
  auto_create_subnetworks         = true/false
  routing_mode                    = "required mode"
}

subnets = [
  {
    name          = "subnet1"
    ip_cidr_range = "required range"
    private_ip_google_access = true/false
  },
  ....
]

webapp_route = {
  name             = "custom route"
  dest_range       = "required range"
  next_hop_gateway = "required gateway"
}

webapp_route_tags = [
  "unique tag which we will be adding to the webapp specific instances"
]

```

### Terraform Commands

After Configuring the tfvars,

1. Initialize Terraform to download all the required libraries.

```bash
terraform init
````
2. Terraform workspace is useful to maintain different states for different resources. For example, if we want to create multiple VPCs, then we can create a different workspace for each VPC, which will not destroy the existing VPCs and will also maintain the states of each created VPC in their corresponding workspace. (https://developer.hashicorp.com/terraform/language/state/workspaces)

```bash
terraform workspace 'vpc workspace name'
terraform workspace select 'vpc workspace name'
```

3.Review the plan of creation/destroy/replacement using the below command.

```bash
terraform plan --var-file='use this only if the tfvars name is not terraform.tfvars'
```
4. Post-review, apply the changes using the below command.

```bash
terraform apply
```

### Conclusion

Follow these step, once done revoke the auth to avoid security issues