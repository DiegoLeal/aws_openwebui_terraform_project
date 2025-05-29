provider "aws" {
  region = var.aws_region
}

# --- Máquinas EC2 ---

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

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "instance_1" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id
  user_data              = file("${path.module}/scripts/install_models.sh")

  tags = {
    Name     = "Ollama-Models-Instance"
    AutoStop = "true"
  }
}

resource "aws_instance" "instance_2" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = var.subnet_id
  user_data              = file("${path.module}/scripts/install_open_webui.sh")

  tags = {
    Name     = "OpenWebUI-Instance"
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

  lifecycle {
    prevent_destroy = true
  }
}

# --- ZIP Lambda ---

data "archive_file" "lambda_autostop_zip" {
  type        = "zip"
  source_file = "lambda/stop_instances.py"
  output_path = "lambda/stop_instances.zip"
}

# --- IAM Role Lambda ---

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
      }
    ]
  })

  tags = {
    Name = "lambda-autostop-role"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# --- IAM Policy ---

resource "aws_iam_policy" "lambda_autostop_policy" {
  name        = "lambda_autostop_policy"
  description = "IAM policy for Lambda to stop EC2 instances based on tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  lifecycle {
    prevent_destroy = true
  }
}

# --- Attach IAM Policy to Role ---

resource "aws_iam_role_policy_attachment" "lambda_autostop_role_policy_attach" {
  role       = aws_iam_role.lambda_autostop_role.name
  policy_arn = aws_iam_policy.lambda_autostop_policy.arn

  lifecycle {
    prevent_destroy = true
  }
}

# --- Lambda Function ---

resource "aws_lambda_function" "autostop_instances" {
  function_name    = "autostop-billing-alarm"
  handler          = "stop_instances.lambda_handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_autostop_role.arn
  filename         = data.archive_file.lambda_autostop_zip.output_path
  source_code_hash = data.archive_file.lambda_autostop_zip.output_base64sha256

  timeout     = 60
  memory_size = 128

  tags = {
    Name = "autostop-billing-alarm"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# --- Permissão para CloudWatch invocar Lambda ---

resource "aws_lambda_permission" "allow_cloudwatch_to_call_autostop_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autostop_instances.function_name
  principal     = "cloudwatch.amazonaws.com"

  lifecycle {
    prevent_destroy = true
  }
}

# --- CloudWatch Billing Alarm ---

resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "HighBillingAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600
  statistic           = "Maximum"
  threshold           = 1.0
  unit                = "None"

  alarm_actions = [
    aws_lambda_function.autostop_instances.arn
  ]

  ok_actions = []

  tags = {
    Name = "HighBillingAlarm"
  }

  lifecycle {
    prevent_destroy = true
  }
}
