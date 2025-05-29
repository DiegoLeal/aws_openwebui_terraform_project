output "open_webui_public_ip" {
  value = aws_instance.open_webui.public_ip
}

output "ollama_models_public_ip" {
  value = aws_instance.ollama_models.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.pdf_bucket.id
}