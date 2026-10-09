resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-igw" }
}

# 1. Public Subnets (ALB, NAT GW)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-subnet-${var.availability_zones[count.index]}"
    Tier = "Public"
  }
}

# 2. Private App Subnets (EC2 ASG)
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-private-app-subnet-${var.availability_zones[count.index]}"
    Tier = "Private-App"
  }
}

# 3. Isolated DB Subnets (RDS Multi-AZ)
resource "aws_subnet" "isolated_db" {
  count             = length(var.isolated_db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.isolated_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.environment}-isolated-db-subnet-${var.availability_zones[count.index]}"
    Tier = "Isolated-DB"
  }
}

# NAT Gateway (FinOps: 1 NAT dùng chung hoặc Multi-AZ)
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
  domain = "vpc"
  tags   = { Name = "${var.environment}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "nat" {
  count         = var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.environment}-nat-gw-${count.index + 1}" }
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = length(var.private_app_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
  }
  tags = { Name = "${var.environment}-private-app-rt-${var.availability_zones[count.index]}" }
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "isolated_db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-isolated-db-rt" }
}

resource "aws_route_table_association" "isolated_db" {
  count          = length(aws_subnet.isolated_db)
  subnet_id      = aws_subnet.isolated_db[count.index].id
  route_table_id = aws_route_table.isolated_db.id
}