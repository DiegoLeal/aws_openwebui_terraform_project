provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "open_webui" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = var.subnet_id

  user_data = file("scripts/install_open_webui.sh")

  tags = {
    Name      = "OpenWebUI"
    AutoStop  = "true"
  }
}

resource "aws_instance" "ollama_models" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = var.subnet_id

  user_data = file("scripts/install_models.sh")

  tags = {
    Name      = "LLM_Models"
    AutoStop  = "true"
  }
}

resource "aws_s3_bucket" "pdf_bucket" {
  bucket         = var.bucket_name
  force_destroy  = true

  tags = {
    Name        = "PDFStorage"
    Environment = "Dev"
    # (opcional, só se quiser desligar algum recurso via tag)
    AutoStop    = "true"
  }
}


resource "aws_security_group" "sg" {
  name        = "openwebui_sg"
  description = "Allow necessary ports"
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

  ingress {
    from_port   = 11434
    to_port     = 11435
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

resource "aws_sns_topic" "billing_alerts" {
  name = "billing-alerts-topic"
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.stop_instances.arn
}

resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "BillingThresholdExceeded"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600"
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Alerta quando o billing excede 1 dólar"
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.billing_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_stop_instances_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_stop_instances_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/stop_instances.py"
  output_path = "${path.module}/lambda/stop_instances.zip"
}

resource "aws_lambda_function" "stop_instances" {
  function_name = "stop_instances_on_billing"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "stop_instances.lambda_handler"
  runtime       = "python3.9"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_instances.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.billing_alerts.arn
}