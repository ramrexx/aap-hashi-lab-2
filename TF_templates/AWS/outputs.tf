output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.rhel_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.rhel_server.public_ip
}

output "vault_ssh_key_path" {
  description = "Path to SSH private key in Vault"
  value       = vault_generic_secret.ssh_private_key.path
}

output "ssh_connection" {
  description = "How to connect to the server"
  value       = "1. Get key: vault kv get -field=private_key ${vault_generic_secret.ssh_private_key.path} > key.pem && chmod 600 key.pem\n2. Connect: ssh -i key.pem ec2-user@${aws_instance.rhel_server.public_ip}"
}