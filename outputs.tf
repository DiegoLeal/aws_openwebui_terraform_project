# --- Output (Opcional, mas útil) ---
# Para ver os IPs públicos das instâncias após o apply

output "instance_1_public_ip" {
  description = "IP público da primeira instância EC2"
  value       = aws_instance.instance_1.public_ip
}

output "instance_2_public_ip" {
  description = "IP público da segunda instância EC2"
  value       = aws_instance.instance_2.public_ip
}

output "s3_bucket_name_output" { # RENOMEADO para ser único e claro
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.open-webUI-terraform.id # Referenciando o novo bucket
}