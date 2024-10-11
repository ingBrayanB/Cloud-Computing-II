# Provider de AWS en Norte de Virgina
provider "aws" {
  region = "us-east-1"
}

# Creamos la VPC en el rango establecido
resource "aws_vpc" "vpc_cloud_2" {
  cidr_block           = "30.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "VPC_Cloud2"
  }
}

# Creamos nuestro Internet Gateway para la salida a internet de las redes publicas
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_cloud_2.id
  tags = {
    Name = "Cloud2_internet_gateway"
  }
}

# Creamos Primera SubRed Pública en una Zona Diferente
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc_cloud_2.id
  cidr_block              = "30.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet1"
  }
}

# Creamos Segunda SubRed Pública en una Zona Diferente
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc_cloud_2.id
  cidr_block              = "30.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet2"
  }
}

# Creamos Primera SubRed Privada en la misma Zona de la primera instancia publica
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc_cloud_2.id
  cidr_block        = "30.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "PrivateSubnet1"
  }
}

# Creamos Segunda SubRed Privada en la misma Zona de la primera instancia publica
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc_cloud_2.id
  cidr_block        = "30.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "PrivateSubnet2"
  }
}

# Creamos la tabla de rutas para las Subredes Públicas
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_cloud_2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Asociamos tabla de rutas públicas con la Primera Subred Pública para su conexion a internet
resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Asociamos tabla de rutas públicas con la Segunda Subred Pública para su conexion a internet
resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Creamos tabla de rutas para Subredes Privadas 
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc_cloud_2.id
  tags = {
    Name = "PrivateRouteTable"
  }
}

# Asociamos tabla de rutas Privadas con la primera Subred Privada
resource "aws_route_table_association" "private_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

# Asociamos tabla de rutas Privadas con la Segunda Subred Privada
resource "aws_route_table_association" "private_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Creamos el grupo de seguridad para las instancias EC2
resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.vpc_cloud_2.id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
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
    Name = "MySecurityGroup"
  }
}

# Creamos instancia de EC2 en la Subred Pública 1
resource "aws_instance" "public_ec2_1" {
  ami                    = "ami-0fff1b9a61dec8a5f" # Amazon Linux 2 AMI ID
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  key_name               = "cloud2"
  user_data              = file("commands.sh")
  vpc_security_group_ids = [aws_security_group.my_security_group.id]

  tags = {
    Name = "PublicEC2-1"
  }
}

# Creamos la otra instancia de EC2 en la Subred Pública 2
resource "aws_instance" "public_ec2_2" {
  ami                    = "ami-0fff1b9a61dec8a5f" # Amazon Linux 2 AMI ID
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  key_name               = "cloud2"
  user_data              = file("commands2.sh")
  vpc_security_group_ids = [aws_security_group.my_security_group.id]

  tags = {
    Name = "PublicEC2-2"
  }
}
# Creamos el Load Balancer
resource "aws_lb" "my_load_balancer" {
  name               = "balanceadorCloud" # Cambia el nombre aquí
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.my_security_group.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
  ]

  enable_deletion_protection = false

  tags = {
    Name = "MyLoadBalancer"
  }
}

# Creamos un target group para las instancias
resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_cloud_2.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "MyTargetGroup"
  }
}

# Registramos las instancias en el target group
resource "aws_lb_target_group_attachment" "ec2_attachment_1" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.public_ec2_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_attachment_2" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.public_ec2_2.id
  port             = 80
}

# Creamos un listener para el Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Creamos un grupo de subred publica para RDS
resource "aws_db_subnet_group" "rdspostgres" {
  name       = "rdspostgres"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags = {
    Name = "Rds_PostgreSQL"
  }
}

# Creamos la instancia RDS PostgreSQL en la subred publica
resource "aws_db_instance" "rdspostgres" {
  identifier             = "rdspostgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.9"
  username               = "edu"
  password               = "Edu12345!"
  db_subnet_group_name   = aws_db_subnet_group.rdspostgres.name
  vpc_security_group_ids = [aws_security_group.my_security_group.id]
  parameter_group_name   = aws_db_parameter_group.rdspostgres.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

# Grupo de parametros para nuestra RDS
resource "aws_db_parameter_group" "rdspostgres" {
  name   = "rdspostgres"
  family = "postgres14"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

# Salidas de variables
output "rds_hostname" {
  description = "RDS instance hostname"
  value       = aws_db_instance.rdspostgres.address
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.rdspostgres.port
  sensitive   = true
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.rdspostgres.username
  sensitive   = true
}

