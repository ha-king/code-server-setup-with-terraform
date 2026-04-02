terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

#------------------------------------------------------
# Security Group
#------------------------------------------------------
resource "aws_security_group" "vscode_server" {
  name_prefix = "VSCodeServer-"
  description = "Allow ingress from CloudFront prefix list"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : null

  tags = { Name = "VSCodeServer-SG" }
}

resource "aws_vpc_security_group_ingress_rule" "vscode_server" {
  security_group_id = aws_security_group.vscode_server.id
  description       = "Open port 8080 for the CloudFront prefix list"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  prefix_list_id    = var.cloudfront_prefix_list_ids[data.aws_region.current.name]
}

resource "aws_vpc_security_group_egress_rule" "vscode_server" {
  security_group_id = aws_security_group.vscode_server.id
  description       = "Egress for VSCode security group"
  ip_protocol       = "-1"
  cidr_ipv4         = var.internet_cidr_block
}

#------------------------------------------------------
# IAM Role and Instance Profile
#------------------------------------------------------
resource "aws_iam_role" "vscode_server" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vscode_server_ssm" {
  role       = aws_iam_role.vscode_server.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_instance_profile" "vscode_server" {
  role = aws_iam_role.vscode_server.name
}

#------------------------------------------------------
# Elastic IP
#------------------------------------------------------
resource "aws_eip" "vscode_server" {
  domain = "vpc"
  tags   = { Name = "VSCodeServer-EIP" }
}

resource "aws_eip_association" "vscode_server" {
  allocation_id = aws_eip.vscode_server.id
  instance_id   = aws_instance.vscode_server.id
}

#------------------------------------------------------
# EC2 Instance
#------------------------------------------------------
resource "aws_instance" "vscode_server" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.vscode_server.name
  subnet_id              = var.subnet_id != "" ? var.subnet_id : null
  vpc_security_group_ids = [aws_security_group.vscode_server.id]
  monitoring             = true

  associate_public_ip_address = true

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    version = var.vscode_server_version
  }))

  tags = { Name = "VSCodeServer" }
}

#------------------------------------------------------
# CloudFront Cache Policy
#------------------------------------------------------
resource "aws_cloudfront_cache_policy" "vscode_server" {
  name        = "VSCodeServer-${substr(sha256(aws_instance.vscode_server.id), 0, 8)}"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Accept-Charset",
          "Authorization",
          "Origin",
          "Accept",
          "Referer",
          "Host",
          "Accept-Language",
          "Accept-Encoding",
          "Accept-Datetime",
        ]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
    enable_accept_encoding_gzip = false
  }
}

#------------------------------------------------------
# CloudFront Distribution
#------------------------------------------------------
resource "aws_cloudfront_distribution" "vscode_server" {
  enabled = true

  origin {
    domain_name = aws_instance.vscode_server.public_dns
    origin_id   = "VS-code-server"

    custom_origin_config {
      http_port              = 8080
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "VS-code-server"
    viewer_protocol_policy   = "allow-all"
    compress                 = false
    origin_request_policy_id = var.origin_request_policy_id
    cache_policy_id          = aws_cloudfront_cache_policy.vscode_server.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [aws_eip_association.vscode_server]
}

#------------------------------------------------------
# Lambda - Stop Idle EC2
#------------------------------------------------------
data "archive_file" "idle_checker" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_iam_role" "lambda" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "LambdaEC2Policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["ec2:DescribeInstances", "ec2:StopInstances"]
          Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.vscode_server.id}"
        },
        {
          Effect   = "Allow"
          Action   = ["cloudwatch:GetMetricStatistics"]
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name = "LambdaLogsPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }]
    })
  }
}

resource "aws_lambda_function" "idle_checker" {
  filename         = data.archive_file.idle_checker.output_path
  source_code_hash = data.archive_file.idle_checker.output_base64sha256
  function_name    = "IdleEC2Checker"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      TARGET_INSTANCE_ID = aws_instance.vscode_server.id
    }
  }
}

resource "aws_cloudwatch_event_rule" "idle_check" {
  description         = "ScheduledRule"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "idle_check" {
  rule = aws_cloudwatch_event_rule.idle_check.name
  arn  = aws_lambda_function.idle_checker.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  function_name = aws_lambda_function.idle_checker.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.idle_check.arn
}
