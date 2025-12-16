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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["MY_IP/32"]
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
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[0].id   # public-subnet-1
  vpc_security_group_ids      = [aws_security_group.dev_web_sg.id]
  associate_public_ip_address = true
  key_name                    = "YOUR_KEYPAIR"

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
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public[1].id   # public-subnet-2
  vpc_security_group_ids      = [aws_security_group.dev_web_sg.id]
  associate_public_ip_address = true
  key_name                    = "YOUR_KEYPAIR"

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
  password                = "SET_PASSWORD"

  db_subnet_group_name    = aws_db_subnet_group.dev_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.dev_db_sg.id]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "dev-mysql-db"
  }
}
