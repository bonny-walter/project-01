resource "aws_vpc" "bastion_vpc" {
  cidr_block = "172.16.0.0/16"  # Use a valid private IP range
  tags = {
    Name = "bastion-vpc"
  }
}

resource "aws_subnet" "bastion_public_subnet" {
  vpc_id                  = aws_vpc.bastion_vpc.id
  cidr_block              = "172.16.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "bastion-public-subnet" }
}

resource "aws_internet_gateway" "bastion_igw" {
  vpc_id = aws_vpc.bastion_vpc.id
}

resource "aws_route_table" "bastion_public_rt" {
  vpc_id = aws_vpc.bastion_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion_igw.id
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "bastion_public_rt_association" {
  subnet_id      = aws_subnet.bastion_public_subnet.id
  route_table_id = aws_route_table.bastion_public_rt.id
}

resource "aws_security_group" "bastion_sg" {
  vpc_id      = aws_vpc.bastion_vpc.id
  description = "Allows SSH (port 22) access to the bastion host from anywhere and allows all outbound traffic."

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

  tags = { Name = "bastion-sg" }
}

resource "aws_instance" "bastion_host" {
  ami                    = "ami-00eb69d236edcfaf8"  # Replace with a valid AMI ID for your region
  instance_type          = "t2.micro"
  key_name               = "project1"
  subnet_id              = aws_subnet.bastion_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y awscli apache2 git

    systemctl start apache2
    systemctl enable apache2

    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i amazon-cloudwatch-agent.deb
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent

    apt install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Configure CloudWatch Agent for custom memory metrics
    cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
    {
      "metrics": {
        "namespace": "CustomEC2",
        "metrics_collected": {
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          }
        }
      }
    }  
  EOF

  tags = {
    Name = "bastion-host"
  }
}
