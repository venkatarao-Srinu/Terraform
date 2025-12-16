resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "dev_web_sg" {
  name        = "dev-web-sg"
  description = "Dev Web Server SG"
  vpc_id      = aws_vpc.this.id   # ✅ dev-vpc

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

  tags = {
    Name = "dev-web-sg"
  }
}

resource "aws_security_group" "dev_db_sg" {
  name        = "dev-db-sg"
  description = "Dev Database SG"
  vpc_id      = aws_vpc.this.id   # ✅ dev-vpc

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.dev_web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-db-sg"
  }
}

resource "aws_instance" "dev_web_1" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id   # public-subnet-1
  vpc_security_group_ids      = [aws_security_group.dev_web_sg.id]
  associate_public_ip_address = true
  key_name                    = "dynatrace-test"

  user_data = <<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Dev Web Server 1 Running" > /var/www/html/index.html
EOF

  tags = {
    Name = "dev-web-server-1"
  }
}

resource "aws_instance" "dev_web_2" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[1].id   # public-subnet-2
  vpc_security_group_ids      = [aws_security_group.dev_web_sg.id]
  associate_public_ip_address = true
  key_name                    = "dynatrace-test"

  user_data = <<EOF
#!/bin/bash
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Dev Web Server 2 Running" > /var/www/html/index.html
EOF

  tags = {
    Name = "dev-web-server-2"
  }
}

resource "aws_db_subnet_group" "dev_db_subnet_group" {
  name = "dev-db-subnet-group"

  subnet_ids = [
    aws_subnet.private[0].id,
    aws_subnet.private[1].id
  ]

  tags = {
    Name = "dev-db-subnet-group"
  }
}

resource "aws_db_instance" "dev_mysql" {
  identifier              = "dev-mysql-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20

  username                = "admin"
  password                = "test984916"

  db_subnet_group_name    = aws_db_subnet_group.dev_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.dev_db_sg.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "dev-mysql-db"
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = var.ami_owner

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }
}

resource "aws_security_group" "dev_alb_sg" {
  name        = "dev-alb-sg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.this.id

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

  tags = {
    Name = "dev-alb-sg"
  }
}

resource "aws_lb" "dev_alb" {
  name               = "dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dev_alb_sg.id]
  subnets            = [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id
  ]

  tags = {
    Name = "dev-alb"
  }
}

resource "aws_lb_target_group" "dev_tg" {
  name     = "dev-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id  = aws_vpc.this.id

  health_check {
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "dev-tg"
  }
}

resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.dev_tg.arn
  target_id        = aws_instance.dev_web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.dev_tg.arn
  target_id        = aws_instance.dev_web_2.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.dev_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev_tg.arn
  }
}

data "aws_route53_zone" "srinuapps" {
  name         = "srinuapps.shop"
  private_zone = false
}

resource "aws_route53_record" "test2" {
  zone_id = data.aws_route53_zone.srinuapps.zone_id
  name    = "test2.srinuapps.shop"
  type    = "A"

  alias {
    name                   = aws_lb.dev_alb.dns_name
    zone_id                = aws_lb.dev_alb.zone_id
    evaluate_target_health = true
  }
}