# Define o provedor AWS e a região
provider "aws" {
  region = var.aws_region
}

# --- Máquinas EC2 ---

# Security Group para permitir SSH e HTTP (se necessário)
resource "aws_security_group" "web_sg" {
  name        = "web-instance-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = var.vpc_id

  # Regra para SSH (Porta 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acesso de qualquer IP (em ambiente de produção, restrinja!)
  }

  # Regra para HTTP (Porta 80) - se suas máquinas forem servir algo na web
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída (permite toda a comunicação para fora)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Todos os protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Primeira instância Ubuntu
resource "aws_instance" "instance_1" {
  ami                    = var.ami_id
  instance_type          = "t2.micro" # Free Tier
  key_name               = var.key_name # Certifique-se de que sua chave SSH existe na AWS
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id

  tags = {
    Name = "Ubuntu-Instance-1"
  }
}

# Segunda instância Ubuntu
resource "aws_instance" "instance_2" {
  ami                    = var.ami_id
  instance_type          = "t2.micro" # Free Tier
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id

  tags = {
    Name = "Ubuntu-Instance-2"
  }
}

# --- Bucket S3 ---

resource "aws_s3_bucket" "open-webUI-terraform" {
  bucket        = var.bucket_name # Use uma variável para o nome do bucket
  force_destroy = true            # Permite a destruição do bucket mesmo com objetos

  tags = {
    Name        = "open-webUI-terraform"
    Environment = "Dev"
  }
}

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

output "s3_bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.open-webUI-terraform.id
}