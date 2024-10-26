resource "aws_vpc" "app-vpc" {
  cidr_block = "172.32.0.0/16"

  tags = {
    Name = "app-vpc"
  }
}


resource "aws_subnet" "app_public_subnet" {
  vpc_id            = aws_vpc.app-vpc.id
  cidr_block        = "172.32.0.0/24"
  availability_zone = "us-east-2c"
  tags              = { Name = "app-public-subnet" }
}


resource "aws_subnet" "app_private_subnet1" {
  vpc_id            = aws_vpc.app-vpc.id
  cidr_block        = "172.32.1.0/24"
  availability_zone = "us-east-2a"
  tags              = { Name = "app-private-subnet2" }
}

resource "aws_subnet" "app_private_subnet2" {
  vpc_id            = aws_vpc.app-vpc.id
  cidr_block        = "172.32.2.0/24"
  availability_zone = "us-east-2b"
  tags              = { Name = "app-private-subnet2" }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app-vpc.id
}


resource "aws_ec2_transit_gateway" "example" {
  description = "Transit gateway for connecting bastion and app VPCs"
  tags        = { Name = "bastion-app-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "bastion_attachment" {
  subnet_ids         = [aws_subnet.bastion_public_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.bastion_vpc.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app_attachment" {
  subnet_ids         = [aws_subnet.app_private_subnet1.id]
  transit_gateway_id = aws_ec2_transit_gateway.example.id
  vpc_id             = aws_vpc.app-vpc.id
}



resource "aws_route_table" "app_private_rt" {
  vpc_id = aws_vpc.app-vpc.id

  route {
    cidr_block         = aws_vpc.bastion_vpc.cidr_block
    transit_gateway_id = aws_ec2_transit_gateway.example.id
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.app_public_subnet.id
  tags          = { Name = "nat-gateway" }
}

resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.app-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.bastion_vpc.cidr_block] # Allow SSH only from Bastion VPC
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-sg" }
}

