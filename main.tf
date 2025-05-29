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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Adicione a porta 11434 para o Ollama
  ingress {
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Primeira instância Ubuntu (para Ollama Models)
resource "aws_instance" "instance_1" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id

  # Adiciona o script de user_data para instalar o Ollama e baixar o modelo
  # CORRIGIDO: Nome do arquivo agora é 'install_models.sh'
  user_data = file("${path.module}/scripts/install_models.sh")

  tags = {
    Name = "Ollama-Models-Instance"
  }
}

# Segunda instância Ubuntu (para Open WebUI)
resource "aws_instance" "instance_2" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id

  # Adiciona o script de user_data para instalar o Open WebUI
  # CORRIGIDO: Nome do arquivo agora é 'install_open_webui.sh'
  user_data = file("${path.module}/scripts/install_open_webui.sh")

  tags = {
    Name = "OpenWebUI-Instance"
  }
}

# --- Bucket S3 ---

resource "aws_s3_bucket" "open_webui_terraform_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name        = "open-webUI-terraform"
    Environment = "Dev"
  }
}