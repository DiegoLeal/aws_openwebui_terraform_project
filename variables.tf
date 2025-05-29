# Região AWS
variable "aws_region" {
  description = "Região AWS para provisionar os recursos."
  type        = string
  default     = "us-east-1"
}

# AMI ID (Ubuntu 22.04 LTS para us-east-1, verifique se ainda é a mais recente)
variable "ami_id" {
  description = "ID da AMI para as instâncias EC2 (Ubuntu)."
  type        = string
  default     = "ami-084568db4383264d4" # Certifique-se de que esta AMI está disponível na us-east-1
}

# Nome da chave SSH
variable "key_name" {
  description = "Nome do par de chaves SSH existente na AWS para acesso às instâncias."
  type        = string
  # Por questões de segurança, remova o default em produção e force o usuário a informá-lo
  default     = "aws-key" # SUBSTITUA PELO NOME DA SUA CHAVE SSH
}

# ID da VPC
variable "vpc_id" {
  description = "ID da VPC onde os recursos serão criados."
  type        = string
  default     = "vpc-035f94c6ec27ed3ee" 
}

# ID da Subnet
variable "subnet_id" {
  description = "ID da Subnet onde as instâncias EC2 serão lançadas."
  type        = string
  default     = "subnet-012e39ff86aa56847" 
}

# Nome do Bucket S3
variable "bucket_name" {
  description = "Nome único globalmente para o bucket S3."
  type        = string
  default     = "open-webui-tf-bucket-pdfs" 
}