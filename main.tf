provider "aws" {
  region = "us-east-1"
}

# create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main_vpc_nk"
    owner = "meitaveini"
  }
}

# create Private Subnet 1 new
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet1"
    owner = "meitaveini"
  }
}

# create Private Subnet 2 new
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1e"
  map_public_ip_on_launch = false

  tags = {
    Name = "PrivateSubnet2"
    owner = "meitaveini"
  }
}

# create Public Subnet 1 new
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet1"
    owner = "meitaveini"
  }
}

# create Public Subnet 2 new
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1e"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet2"
    owner = "meitaveini"
  }
}

# create Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainInternetGateway"
    owner = "meitaveini"
  }
}
# attached Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# create NAT Gateway in-Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id 

  tags = {
    Name = "NAT-Gateway"
    owner = "meitaveini"
  }
}

# connect Internet Gateway to-Route Table ofPublic Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-RT"
    owner = "meitaveini"
  }
}

# IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# route_table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Private-RT"
    owner = "meitaveini"
  }
}

# create NAT Gateway
resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group for-Bastion
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
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

# create Bastion Host
resource "aws_instance" "bastion_host" {
  ami                         = "ami-084568db4383264d4" # Ubuntu 24.04
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  security_groups             = [aws_security_group.bastion_sg.id]
  key_name                    = "noakirel-keypair"
  associate_public_ip_address = true

  tags = {
    Name  = "BastionHost"
    owner = "meitaveini"
  }
}

# Security Group for private instances
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # SSH only from-Bastion
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # connect only from-LB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# Load Balancer with 2 subnets
resource "aws_lb" "web_lb" {
  name               = "web-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]

  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
}

# create Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "instance"
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

#resource "aws_lb_listener" "web_listener_https" {
#  load_balancer_arn = aws_lb.web_lb.arn
#  port              = 443
#  protocol          = "HTTPS"
#  ssl_policy        = "ELBSecurityPolicy-2016-08" # במידה ויש תעודת SSL
#  certificate_arn   = "arn:aws:acm:...."           # במידה ויש תעודת SSL

#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.web_tg.arn
#  }
#}

# AWS Auto Scaling Group with User Data and Tag Filtering

resource "aws_launch_template" "statuspage_lt" {
  name_prefix   = "statuspage-lt-"
  image_id      = "ami-084568db4383264d4"
  instance_type = "t2.medium"
  key_name      = "noakirel-keypair"
  update_default_version = true

  user_data = filebase64("${path.module}/docs/user-data.sh") 

  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "statuspage-prod"
      owner = "meitaveini"
      role  = "statuspage"
    }
  }
}


resource "aws_autoscaling_group" "statuspage_asg" {
  name                      = "statuspage-asg"
  desired_capacity          = 2
  min_size                  = 2
  max_size                  = 2
  vpc_zone_identifier       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  health_check_type         = "EC2"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.statuspage_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "statuspage-prod"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "owner"
    value               = "meitaveini"
    propagate_at_launch = true
  }

  tag {
    key                 = "role"
    value               = "statuspage"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
