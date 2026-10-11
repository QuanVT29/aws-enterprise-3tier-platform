# ALB SG: Recive 80/443 from Internet
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Inbound internet traffic to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-alb-sg"
  }
}



# App EC2 SG: Zero trust, only allow traffic from ALB SG
resource "aws_security_group" "app" {
  name        = "${var.environment}-app-sg"
  description = "Inbound traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow traffic from ALB SG"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb.id]
  }

  ingress {
    description = "Insecure SSH access from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-app-sg"
  }
}


# RDS SG: Zero trust, only allow traffic from App EC2 SG
resource "aws_security_group" "rds" {
    name        = "${var.environment}-rds-sg"
    description = "Database SG - Isolated Access"
    vpc_id      = var.vpc_id
    
    ingress {
        description      = "Allow traffic from App EC2 SG"
        from_port        = var.db_port
        to_port          = var.db_port
        protocol         = "tcp"
        security_groups  = [aws_security_group.app.id]
    }
    
    egress {
        description = "Allow all outbound traffic"
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["10.0.0.0/16"] # Allow outbound traffic to the VPC CIDR
    }

    tags = {
        Name = "${var.environment}-rds-sg"
    }
}

