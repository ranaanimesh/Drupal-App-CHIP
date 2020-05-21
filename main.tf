data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

################################################
# IAM
################################################
resource "aws_iam_role" "drupal_instance_role" {
  name               = "${var.friendly_name_prefix}-drupal-instance-role-${data.aws_region.current.name}"
  path               = "/"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = merge({ Name = "${var.friendly_name_prefix}-drupal-instance-role" }, var.common_tags)
}

resource "aws_iam_role_policy" "drupal_instance_role_policy" {
  name   = "${var.friendly_name_prefix}-drupal-instance-role-policy-${data.aws_region.current.name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
  role   = aws_iam_role.drupal_instance_role.id
}

resource "aws_iam_instance_profile" "drupal_instance_profile" {
  name = "${var.friendly_name_prefix}-drupal-instance-profile-${data.aws_region.current.name}"
  path = "/"
  role = aws_iam_role.drupal_instance_role.name
}

################################################
# Security Groups
################################################
resource "aws_security_group" "drupal_alb_allow" {
  name   = "${var.friendly_name_prefix}-drupal-alb-allow"
  vpc_id = var.vpc_id
  tags   = merge({ Name = "${var.friendly_name_prefix}-drupal-alb-allow" }, var.common_tags)
}

resource "aws_security_group_rule" "drupal_alb_allow_inbound_https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_alb_allow
  description = "Allow HTTPS (port 443) traffic inbound to Drupal ALB"

  security_group_id = aws_security_group.drupal_alb_allow.id
}

resource "aws_security_group_rule" "drupal_alb_allow_inbound_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_alb_allow
  description = "Allow HTTP (port 80) traffic inbound to Drupal ALB"

  security_group_id = aws_security_group.drupal_alb_allow.id
}

resource "aws_security_group_rule" "drupal_alb_allow_inbound_console" {
  type        = "ingress"
  from_port   = 8800
  to_port     = 8800
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_alb_allow
  description = "Allow admin console (port 8800) traffic inbound to Drupal ALB for Drupal Replicated app"

  security_group_id = aws_security_group.drupal_alb_allow.id
}

resource "aws_security_group" "drupal_ec2_allow" {
  name   = "${var.friendly_name_prefix}-drupal-ec2-allow"
  vpc_id = var.vpc_id
  tags   = merge({ Name = "${var.friendly_name_prefix}-drupal-ec2-allow" }, var.common_tags)
}

resource "aws_security_group_rule" "drupal_ec2_allow_https_inbound_from_alb" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.drupal_alb_allow.id
  description              = "Allow HTTPS (port 443) traffic inbound to Drupal EC2 instance from Drupal Appication Load Balancer"

  security_group_id = aws_security_group.drupal_ec2_allow.id
}

resource "aws_security_group_rule" "drupal_ec2_allow_inbound_ssh" {
  count       = length(var.ingress_cidr_ec2_allow) > 0 ? 1 : 0
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.ingress_cidr_ec2_allow
  description = "Allow SSH inbound to Drupal EC2 instance CIDR ranges listed"

  security_group_id = aws_security_group.drupal_ec2_allow.id
}

resource "aws_security_group_rule" "drupal_ec2_allow_8800_inbound_from_alb" {
  type                     = "ingress"
  from_port                = 8800
  to_port                  = 8800
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.drupal_alb_allow.id
  description              = "Allow admin console (port 8800) traffic inbound to Drupal EC2 instance from Drupal Appication Load Balancer"

  security_group_id = aws_security_group.drupal_ec2_allow.id
}

resource "aws_security_group" "drupal_rds_allow" {
  name   = "${var.friendly_name_prefix}-drupal-rds-allow"
  vpc_id = var.vpc_id
  tags   = merge({ Name = "${var.friendly_name_prefix}-drupal-rds-allow" }, var.common_tags)
}

resource "aws_security_group_rule" "drupal_rds_allow_pg_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.drupal_ec2_allow.id
  description              = "Allow PostgreSQL traffic inbound to Drupal RDS from Drupal EC2 Security Group"

  security_group_id = aws_security_group.drupal_rds_allow.id
}

resource "aws_security_group" "drupal_outbound_allow" {
  name   = "${var.friendly_name_prefix}-drupal-outbound-allow"
  vpc_id = var.vpc_id
  tags   = merge({ Name = "${var.friendly_name_prefix}-drupal-outbound-allow" }, var.common_tags)
}

resource "aws_security_group_rule" "drupal_outbound_allow_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all traffic outbound from drupal"

  security_group_id = aws_security_group.drupal_outbound_allow.id
}
################################################
# RDS
################################################
resource "aws_db_subnet_group" "drupal_rds_subnet_group" {
  name       = "${var.friendly_name_prefix}-drupal-db-subnet-group"
  subnet_ids = var.rds_subnet_ids

  tags = merge(
    { Name = "${var.friendly_name_prefix}-drupal-db-subnet-group" },
    { Description = "Subnets for Drupal PostgreSQL RDS instance" },
    var.common_tags
  )
}

resource "random_password" "rds_password" {
  length  = 24
  special = false
}

resource "aws_db_instance" "drupal_rds" {
  allocated_storage         = var.rds_storage_capacity
  identifier                = "${var.friendly_name_prefix}-drupal-rds-${data.aws_caller_identity.current.account_id}"
  final_snapshot_identifier = "${var.friendly_name_prefix}-drupal-rds-${data.aws_caller_identity.current.account_id}-final-snapshot"
  storage_type              = "gp2"
  engine                    = "postgres"
  engine_version            = var.rds_engine_version
  db_subnet_group_name      = aws_db_subnet_group.drupal_rds_subnet_group.id
  name                      = "drupal"
  storage_encrypted         = true
  kms_key_id                = var.kms_key_arn != "" ? var.kms_key_arn : ""
  multi_az                  = var.rds_multi_az
  instance_class            = var.rds_instance_size
  username                  = "drupal"
  password                  = random_password.rds_password.result

  vpc_security_group_ids = [
    aws_security_group.drupal_rds_allow.id
  ]

  tags = merge(
    { Name = "${var.friendly_name_prefix}-drupal-rds-${data.aws_caller_identity.current.account_id}" },
    { Description = "Drupal PostgreSQL database storage" },
    var.common_tags
  )
}

################################################
# Route53
################################################
data "aws_route53_zone" "selected" {
  count        = var.route53_hosted_zone_name != "" ? 1 : 0
  name         = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "drupal_alb_alias_record" {
  count   = var.route53_hosted_zone_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.drupal_hostname
  type    = "A"

  alias {
    name                   = aws_lb.drupal_alb.dns_name
    zone_id                = aws_lb.drupal_alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "drupal_cert_validation_record" {
  count   = length(aws_acm_certificate.drupal_cert) == 1 && var.route53_hosted_zone_name != "" ? 1 : 0
  name    = aws_acm_certificate.drupal_cert[0].domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.drupal_cert[0].domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.selected[0].zone_id
  records = [aws_acm_certificate.drupal_cert[0].domain_validation_options[0].resource_record_value]
  ttl     = 60
}

################################################
# ACM
################################################
resource "aws_acm_certificate" "drupal_cert" {
  count             = var.tls_certificate_arn == "" && var.route53_hosted_zone_name != "" ? 1 : 0
  domain_name       = var.drupal_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({ Name = "${var.friendly_name_prefix}-drupal-alb-acm-cert" }, var.common_tags)
}

resource "aws_acm_certificate_validation" "drupal_cert_validation" {
  count                   = length(aws_acm_certificate.drupal_cert) == 1 ? 1 : 0
  certificate_arn         = aws_acm_certificate.drupal_cert[0].arn
  validation_record_fqdns = [aws_route53_record.drupal_cert_validation_record[0].fqdn]
}

################################################
# Load Balancing
################################################
resource "aws_lb" "drupal_alb" {
  name               = "${var.friendly_name_prefix}-drupal-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.drupal_alb_allow.id,
    aws_security_group.drupal_outbound_allow.id
  ]

  subnets = var.alb_subnet_ids

  tags = merge({ Name = "${var.friendly_name_prefix}-drupal-alb" }, var.common_tags)
}

resource "aws_lb_listener" "drupal_listener_443" {
  load_balancer_arn = aws_lb.drupal_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = element(coalescelist(aws_acm_certificate.drupal_cert[*].arn, list(var.tls_certificate_arn)), 0)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.drupal_tg_443.arn
  }

  depends_on = [aws_acm_certificate.drupal_cert]
}

resource "aws_lb_listener" "drupal_listener_80_rd" {
  load_balancer_arn = aws_lb.drupal_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "drupal_listener_8800" {
  load_balancer_arn = aws_lb.drupal_alb.arn
  port              = 8800
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = element(coalescelist(aws_acm_certificate.drupal_cert[*].arn, list(var.tls_certificate_arn)), 0)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.drupal_tg_8800.arn
  }

  depends_on = [aws_acm_certificate.drupal_cert]
}

resource "aws_lb_target_group" "drupal_tg_443" {
  name     = "${var.friendly_name_prefix}-drupal-alb-tg-443"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/_health_check"
    protocol            = "HTTPS"
    matcher             = 200
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }

  tags = merge(
    { Name = "${var.friendly_name_prefix}-drupal-alb-tg-443" },
    { Description = "ALB Target Group for Drupal web application HTTPS traffic" },
    var.common_tags
  )
}

resource "aws_lb_target_group" "drupal_tg_8800" {
  name     = "${var.friendly_name_prefix}-drupal-alb-tg-8800"
  port     = 8800
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    path     = "/authenticate"
    protocol = "HTTPS"
    matcher  = 200
  }

  tags = merge(
    { Name = "${var.friendly_name_prefix}-drupal-alb-tg-8800" },
    { Description = "ALB Target Group for Drupal/Replicated web admin console traffic over port 8800" },
    var.common_tags
  )
}

################################################
# Auto Scaling
################################################
resource "aws_launch_template" "drupal_lt" {
  name          = "${var.friendly_name_prefix}-drupal-ec2-asg-lt-primary"
  image_id      = var.aws_ami
  instance_type = var.instance_size
  key_name      = var.ec2_ecs_ssh_key_pair != "" ? var.ec2_ecs_ssh_key_pair : ""
  user_data     = ""

  iam_instance_profile {
    name = aws_iam_instance_profile.drupal_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
    }
  }

  vpc_security_group_ids = [
    aws_security_group.drupal_ec2_allow.id,
    aws_security_group.drupal_outbound_allow.id
  ]

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      { Name = "${var.friendly_name_prefix}-drupal-ec2-primary" },
      { Type = "autoscaling-group" },
      var.common_tags
    )
  }

  tags = merge({ Name = "${var.friendly_name_prefix}-drupal-ec2-launch-template" }, var.common_tags)
}

resource "aws_autoscaling_group" "drupal_asg" {
  name                      = "${var.friendly_name_prefix}-drupal-asg"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.ec2_subnet_ids
  health_check_grace_period = 600
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.drupal_lt.id
    version = "$Latest"
  }
  target_group_arns = [
    aws_lb_target_group.drupal_tg_443.arn,
    aws_lb_target_group.drupal_tg_8800.arn
  ]
}
