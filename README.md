# AWS VPC Terraform module with IPv6 support 

Terraform module which creates VPC resources on AWS.

## Usage

```hcl
provider "aws" {
  region = "REGION"
}

module "vpc" {  
  source           = "github.com/Radkowski/ipv6-vpc"
  
  DeploymentName   = "MyVPC"
  VPC_CIDR         = "10.0.0.0/16"
  IPv6_ENABLED     = true
  PubPrivPairCount = 3
    AuthTags = {
        "Key1": "Value1",
        "Key2": "Value2",
        "Key3": "Value3"
    }
}
```

## Parameters

* `REGION`: Deployment Region
* `DeploymentName`: prefix to be added to resources name (VPC and subnets)
* `VPC_CIDR`: IPv4 VPC CIDR to be allocated with VPC
* `IPv6_ENABLED`: if true, VPC will be deployed in dual stack scenario
* `PubPrivPairCount`: number of public and private subnets to be deployed. For each public subnet solution deploys corresponding private. This parameter defines number of pairs, for example setting this parameter to 2 will deploy 2 public and 2 private subnets (4 in total). Setting this parameter to 3 will deploy 6 subnets in total. Each pair is fairly distributed across all available AZs.
* `AuthTags`: Tags to be attached to resources


