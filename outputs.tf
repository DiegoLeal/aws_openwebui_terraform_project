# --- Outputs dos IPs públicos das instâncias ---

output "instance_1_public_ip" {
  description = "IP público da primeira instância EC2"
  value       = aws_instance.instance_1.public_ip
}

output "instance_2_public_ip" {
  description = "IP público da segunda instância EC2"
  value       = aws_instance.instance_2.public_ip
}

# --- Output do nome do bucket S3 ---

output "s3_bucket_name_output" { 
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.open_webui_terraform_bucket.id 
}