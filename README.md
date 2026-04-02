---
title: Hosting Code Server on EC2 and CloudFront Distribution with Terraform
author: haimtran
date: 08/08/2024
---

## Supported Region

By default, the provided configuration supports the following regions.

| Region         | CloudFront Prefix List ID |
| -------------- | ------------------------- |
| us-west-2      | pl-82a045eb               |
| us-east-1      | pl-3b927c52               |
| ap-southeast-1 | pl-31a34658               |

To deploy in other regions, update the `cloudfront_prefix_list_ids` variable. Check [docs](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-aws-managed-prefix-lists.html) for more details.

```hcl
cloudfront_prefix_list_ids = {
  us-west-2      = "pl-82a045eb"
  us-east-1      = "pl-3b927c52"
  ap-southeast-1 = "pl-31a34658"
  <YOUR_REGION>  = "<CLOUDFRONT_PREFIX_LIST_ID>"
}
```

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

To deploy with custom variables:

```bash
terraform apply \
  -var="instance_type=t2.medium" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx"
```

This configuration will:

- Create an EC2 instance and install the [code server](https://github.com/coder/code-server) using UserData.
- Expose the code server via a CloudFront distribution.
- Deploy a Lambda function to stop the EC2 instance when idle (CPU < 10% for 30 minutes).

## Code Server Configuration

You can change the following variables in `variables.tf` or pass them via `-var` flags:

- EC2 instance type (default `t2.xlarge`)
- Amazon Machine Image (AMI) (default Ubuntu 22.04 LTS via SSM parameter)
- Code server [release version](https://github.com/coder/code-server/releases) (default `4.91.1`)
- Select an existing VPC ID and Subnet ID (otherwise default VPC is selected)

You can change configuration of the code server by editing config.yaml:

```bash
/home/ubuntu/.config/code-server/config.yaml
```

Sample config.yaml with authentication disabled:

```yaml
bind-addr: 0.0.0.0:8080
auth: none
password: 8766aa4b66cf555763e9564d
cert: false
```

## Access Code Server

**Option 1.** The code server is exposed via a CloudFront distribution. Find the HTTPS endpoint in the Terraform output:

```bash
terraform output vscode_server_cloudfront_domain_name
```

**Option 2.** Use AWS Systems Manager (SSM) port forwarding:

```bash
aws ssm start-session \
--target <INSTANCE_ID> \
--document-name AWS-StartPortForwardingSessionToRemoteHost \
--parameters "{\"portNumber\":[\"8080\"],\"localPortNumber\":[\"8080\"],\"host\":[\"<CODE_SERVER_EC2_PRIVATE_IP>\"]}" \
--profile <PROFILE_NAME> \
--region <REGION>
```

## Destroy

```bash
terraform destroy
```
