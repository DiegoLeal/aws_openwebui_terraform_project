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

resource "aws_s3_bucket" "open_webui_terraform_bucket" { # Renomeado para seguir convenções do Terraform (underscore)
  bucket        = var.bucket_name # Use uma variável para o nome do bucket
  force_destroy = true            # Permite a destruição do bucket mesmo com objetos

  tags = {
    Name        = "open-webUI-terraform"
    Environment = "Dev"
  }
}