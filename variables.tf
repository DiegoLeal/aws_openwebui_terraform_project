variable "aws_region" {
  type        = string
  description = ""
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID to be used for the instance"
  type        = string
  default     = "ami-084568db4383264d4"
}

variable "instance_type" {
  type        = string
  description = ""
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for SSH"
  default     = "terraform"
}

variable "subnet_id" {
  description = "Subnet ID"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "bucket-openwebui"
}
