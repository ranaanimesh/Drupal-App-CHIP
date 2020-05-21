################################################
# Common
################################################
variable "friendly_name_prefix" {
  type        = string
  description = "String value for freindly name prefix for AWS resource names and tags"
  default     = "animesh"
}

variable "common_tags" {
  type        = map(string)
  description = "Map of common tags for taggable AWS resources"
  default     = {}
}

################################################
# Compute
################################################
variable "aws_ami" {
  type        = string
  description = "AWS ami id to create for Drupal app EC2 instances"
  default     = "ami-0276cbf32e041c21b"
}

variable "instance_size" {
  type        = string
  description = "EC2 instance type for Drupal server"
  default     = "t2.micro"
}

################################################
# Network
################################################
variable "vpc_id" {
  type        = string
  description = "VPC ID that Drupal app will be deployed into"
  default     = "vpc-0ba870f2ed28213aa"
}

variable "route53_hosted_zone_name" {
  type        = string
  description = "Route53 Hosted Zone where Drupal Alias Record and Certificate Validation record will reside (required if tls_certificate_arn is left blank)"
  default     = "animeshpartsunlimited.com"
}

################################################
# Storage
################################################
variable "alb_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for Application Load Balancer (ALB)"
  default     = ["subnet-02db707b414471517", "subnet-0085d030eb13c24a4"]
}

variable "ec2_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to use for EC2 instance - preferably private subnets"
  default     = ["subnet-08b6ab1e446a45eee", "subnet-016b31bd42985acc1"]
}

variable "rds_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to use for RDS Database Subnet Group - preferably private subnets"
  default     = ["subnet-08b6ab1e446a45eee", "subnet-016b31bd42985acc1"]
}

variable "rds_storage_capacity" {
  type        = string
  description = "Size capacity (GB) of RDS PostgreSQL database"
  default     = 20
}

variable "rds_engine_version" {
  type        = string
  description = "Version of PostgreSQL for RDS engine"
  default     = "11"
}

variable "rds_multi_az" {
  type        = string
  description = "Set to true to enable multiple availability zone RDS"
  default     = "true"
}

variable "rds_instance_size" {
  type        = string
  description = "Instance size for RDS"
  default     = "db.m4.large"
}

################################################
# Security
################################################
variable "ingress_cidr_alb_allow" {
  type        = list(string)
  description = "List of CIDR ranges to allow web traffic ingress to Drupal Application Load Balancer (ALB)"
  default     = ["0.0.0.0/0"]
}

variable "ingress_cidr_ec2_allow" {
  type        = list(string)
  description = "List of CIDRs to allow SSH ingress to Drupal EC2 instance"
  default     = ["0.0.0.0/0"]
}

variable "tls_certificate_arn" {
  type        = string
  description = "ARN of ACM or IAM certificate to be used for Application Load Balancer HTTPS listeners (required if route53_hosted_zone_name is left blank)"
  default     = ""
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key to encrypt TFE S3 and RDS resources"
  default     = ""
}

variable "ec2_ecs_ssh_key_pair" {
  type        = string
  description = "Name of SSH key pair for Drupal EC2 instance"
  default     = "terraform_ec2"
}

################################################
# App
################################################
variable "drupal_hostname" {
  type        = string
  description = "Hostname of Drupal instance"
  default     = "app.animeshpartsunlimited.com"
}
