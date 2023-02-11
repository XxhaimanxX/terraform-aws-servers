###########
## Data
###########

data "aws_network_interface" "sub_interface_0"{
  filter {
    name = "tag:Name"
    values = ["sub_net_interface0"]
  }
}
data "aws_network_interface" "sub_interface_1"{
  filter {
    name = "tag:Name"
    values = ["sub_net_interface1"]
  }
}
data "aws_network_interface" "sub2_interface_0"{
  filter {
    name = "tag:Name"
    values = ["sub2_net_interface0"]
  }
}
data "aws_network_interface" "sub2_interface_1"{
  filter {
    name = "tag:Name"
    values = ["sub2_net_interface1"]
  }
}
data "aws_subnet" "pub_subnet" {
  filter {
    name = "tag:Name"
    values = ["Public Subnet"]
  }
}
data "aws_subnet" "pub_subnet2" {
  filter {
    name = "tag:Name"
    values = ["Public Subnet_2"]
  }
}
data "aws_security_group" "security_group" {
  filter {
    name = "tag:Name"
    values = ["allow_http"]
  }
}
data "aws_vpc" "vpc" {
  filter {
    name = "tag:Name"
    values = ["main_vpc"]
  }
}

###########
## EC2 Instances
###########
resource "aws_instance" "whiskey_web"{
  ami = var.image_id
  instance_type = var.web_instance_type
  user_data = var.user_data
  availability_zone = "us-east-1a"
  key_name = var.key_pair
  iam_instance_profile = aws_iam_instance_profile.web_log_profile.name
  network_interface {
    device_index = 0
    network_interface_id = data.aws_network_interface.sub_interface_0.id
  }
  root_block_device{
    volume_size = 10
    volume_type = "gp2"
  }
  tags = {
    Owner = "admin"
    "Server name" = "Nginx server"
    Purpose = "whiskey"
  }
}
resource "aws_instance" "whiskey_web2"{
  ami = var.image_id
  instance_type = var.web_instance_type
  user_data = var.user_data
  availability_zone = "us-east-1b"
  key_name = var.key_pair
  iam_instance_profile = aws_iam_instance_profile.web_log_profile.name
  network_interface {
    device_index = 0
    network_interface_id = data.aws_network_interface.sub2_interface_0.id
  }
  root_block_device{
    volume_size = 10
    volume_type = "gp2"
  }
  tags = {
    Owner = "admin"
    "Server name" = "Nginx server"
    Purpose = "whiskey"
  }
}
resource "aws_instance" "DB_server" {
  ami = var.image_id
  instance_type = var.db_instance_type
  availability_zone = "us-east-1a"
  key_name = var.key_pair
  network_interface {
    device_index = 0
    network_interface_id = data.aws_network_interface.sub_interface_1.id
  }
  tags = {
    "Owner" = "DBA"
    "server name" = "DB Server"
  }
}
resource "aws_instance" "DB_server2" {
  ami = var.image_id
  instance_type = var.db_instance_type
  availability_zone = "us-east-1b"
  key_name = var.key_pair
  network_interface {
    device_index = 0
    network_interface_id = data.aws_network_interface.sub2_interface_1.id
  }
  tags = {
    "Owner" = "DBA"
    "server name" = "DB Server"
  }
}

###########
## S3 Bucket
###########

resource "aws_s3_bucket" "b" {
  bucket = var.s3_logs_bucket

  tags = {
    Name = "My bucket"
  }
}

###########
## IAM Role
###########

resource "aws_iam_role_policy" "web_log_policy" {
  name = "web_log_policy"
  role = aws_iam_role.web_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "VisualEditor0"
        Effect = "Allow"
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.b.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role" "web_log_role" {
  name = "web_log_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "web_log_profile" {
  name = "web_log_profile"
  role = aws_iam_role.web_log_role.name
}

###########
## Volumes
###########

resource "aws_ebs_volume" "gp2_disk"{
  availability_zone = "us-east-1a"
  size = 10
  encrypted = true
  type = "gp2"
}
resource "aws_ebs_volume" "gp2_disk2"{
  availability_zone = "us-east-1b"
  size = 10
  encrypted = true
  type = "gp2"
}
resource "aws_volume_attachment" "gp2_disk_att"{
  device_name = "/dev/sdh"
  volume_id = aws_ebs_volume.gp2_disk.id
  instance_id = aws_instance.whiskey_web.id
}
resource "aws_volume_attachment" "gp2_disk_att1"{
  device_name = "/dev/sdh"
  volume_id = aws_ebs_volume.gp2_disk2.id
  instance_id = aws_instance.whiskey_web2.id
}

###########
## Load Balancer + TG
###########

resource "aws_lb" "lb" {
  name = "my-lb-tf"
  load_balancer_type = "application"
  subnets = [data.aws_subnet.pub_subnet.id,data.aws_subnet.pub_subnet2.id]
  #subnets = [aws_subnet.public_sub.id,aws_subnet.public_sub2.id]
  security_groups = ["${data.aws_security_group.security_group.id}"]
}
resource "aws_lb_target_group" "instance_tg" {
  name = "instance-tg"
  port = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = data.aws_vpc.vpc.id
  stickiness {
    type = "lb_cookie"
    cookie_duration = 60
  }
  health_check {
    enabled = true
    path = "/index.html"
    protocol = "HTTP"
  }
}
resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.instance_tg.arn
    type = "forward"
  }
}

resource "aws_lb_target_group_attachment" "tg_att" {
  target_group_arn = aws_lb_target_group.instance_tg.arn
  target_id = aws_instance.whiskey_web.id
}
resource "aws_lb_target_group_attachment" "tg_att2" {
  target_group_arn = aws_lb_target_group.instance_tg.arn
  target_id = aws_instance.whiskey_web2.id
}