output "vault_address" {
  description = "Die öffentliche IP-Adresse der Vault-Instanz"
  value       = aws_instance.vault.public_ip
}

output "api_invoke_url" {
  description = "Die Invoke URL der API Gateway für die Lambda-Funktion"
  value       = aws_api_gateway_deployment.api_deployment.invoke_url
}

output "vault_public_ip" {
  value = aws_instance.vault.public_ip
}

output "vault_private_ip" {
  value = aws_instance.vault.private_ip
}