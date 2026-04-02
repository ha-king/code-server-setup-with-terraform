output "vscode_server_cloudfront_domain_name" {
  value = "https://${aws_cloudfront_distribution.vscode_server.domain_name}"
}

output "vscode_server_public_ip" {
  value = aws_eip.vscode_server.public_ip
}

output "vscode_server_private_ip" {
  value = aws_instance.vscode_server.private_ip
}

output "vscode_server_role_arn" {
  value = aws_iam_role.vscode_server.arn
}

output "vscode_server_instance_id" {
  value = aws_instance.vscode_server.id
}
