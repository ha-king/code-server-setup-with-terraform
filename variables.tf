variable "vpc_id" {
  description = "Imported VPC ID (uses default VPC if empty)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Imported subnet ID (uses default subnet if empty)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.xlarge"
}

variable "vscode_server_version" {
  description = "Code server release version"
  type        = string
  default     = "4.91.1"
}

variable "origin_request_policy_id" {
  description = "CloudFront origin request policy ID"
  type        = string
  default     = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

variable "internet_cidr_block" {
  description = "CIDR block for egress"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloudfront_prefix_list_ids" {
  description = "CloudFront prefix list IDs per region"
  type        = map(string)
  default = {
    us-west-2      = "pl-82a045eb"
    us-east-1      = "pl-3b927c52"
    ap-southeast-1 = "pl-31a34658"
  }
}
