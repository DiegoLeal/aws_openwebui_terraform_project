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
    AutoStop = "true"
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
    AutoStop = "true"
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


# --- Recurso para empacotar o código Python da Lambda ---
# Isso cria um arquivo ZIP do seu script Python, necessário para a Lambda.
data "archive_file" "lambda_autostop_zip" {
  type        = "zip"
  source_file = "lambda/stop_instances.py" # Caminho para o seu script Python
  output_path = "lambda/stop_instances.zip" # Onde o arquivo ZIP será criado
}

# --- Role IAM para a Função Lambda ---
# A Lambda precisa de uma role com permissões para ser executada e interagir com outros serviços.
resource "aws_iam_role" "lambda_autostop_role" {
  name = "lambda_autostop_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "lambda-autostop-role"
  }
}

# --- Política IAM para a Função Lambda ---
# Esta política dá à Lambda as permissões necessárias:
# 1. Criar logs no CloudWatch Logs
# 2. Descrever e parar instâncias EC2 com tags
resource "aws_iam_policy" "lambda_autostop_policy" {
  name        = "lambda_autostop_policy"
  description = "IAM policy for Lambda to stop EC2 instances based on tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissões para CloudWatch Logs
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      # Permissões para interagir com EC2
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrinja isso em produção, se possível, a recursos específicos
      },
    ]
  })
}

# --- Anexar a política à role da Lambda ---
resource "aws_iam_role_policy_attachment" "lambda_autostop_role_policy_attach" {
  role       = aws_iam_role.lambda_autostop_role.name
  policy_arn = aws_iam_policy.lambda_autostop_policy.arn
}

# --- Definição da Função Lambda ---
resource "aws_lambda_function" "autostop_instances" {
  function_name    = "autostop-billing-alarm"
  handler          = "stop_instances.lambda_handler" # Nome do arquivo.funcao_no_arquivo
  runtime          = "python3.9"                     # Python 3.9 é uma boa escolha atual
  role             = aws_iam_role.lambda_autostop_role.arn
  filename         = data.archive_file.lambda_autostop_zip.output_path # Caminho para o ZIP gerado
  source_code_hash = data.archive_file.lambda_autostop_zip.output_base64sha256 # Para detectar mudanças no código

  timeout          = 60 # Tempo máximo de execução em segundos
  memory_size      = 128 # Memória em MB

  tags = {
    Name = "autostop-billing-alarm"
  }
}

# --- Permissão para o CloudWatch invocar a Lambda ---
# Isso é fundamental para que o alarme possa disparar a função.
resource "aws_lambda_permission" "allow_cloudwatch_to_call_autostop_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autostop_instances.function_name
  principal     = "cloudwatch.amazonaws.com"
  # O source_arn pode ser mais específico se você souber o ARN do alarme antes
  # mas para começar, pode ser mais genérico para testar.
  # source_arn = aws_cloudwatch_metric_alarm.billing_alarm.arn # Se você tiver apenas um alarme
}

# --- Alarme de Faturamento do CloudWatch ---
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "HighBillingAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 horas em segundos (6 * 60 * 60)
  statistic           = "Maximum"
  threshold           = 1.0 # Alarme dispara se o custo estimado ultrapassar $1.00
  # CORRIGIDO: A unidade para EstimatedCharges deve ser "None"
  unit                = "None" 

  alarm_actions = [
    aws_lambda_function.autostop_instances.arn # Ação a ser tomada: invocar a função Lambda
  ]
  ok_actions = []

  tags = {
    Name = "HighBillingAlarm"
  }
}