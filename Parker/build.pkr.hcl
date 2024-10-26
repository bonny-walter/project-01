# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

data "amazon-ami" "ubuntu-jammy-amd64" {
  filters = {
    name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["099720109477"]
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "basic-example" {
  ami_name      = "packer-example-${local.timestamp}"
  communicator  = "ssh"
  instance_type = "t2.micro"
  source_ami    = data.amazon-ami.ubuntu-jammy-amd64.id
  ssh_username  = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.basic-example"]

  provisioner "shell" {
    inline = [
      "sudo apt clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt install -y unzip curl apache2 git",
      "sudo systemctl enable apache2",
      "sudo systemctl start apache2",
      # Install AWS CLI using the official installer
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      
      # Install CloudWatch Agent
      "wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb",
      "sudo dpkg -i amazon-cloudwatch-agent.deb || true",
      "sudo systemctl enable amazon-cloudwatch-agent",
      "sudo systemctl start amazon-cloudwatch-agent",
      
      # Configure CloudWatch Agent for custom memory metrics
      "sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc",
      "cat <<EOT | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json",
      "{",
      "  \"metrics\": {",
      "    \"namespace\": \"CustomEC2\",",
      "    \"metrics_collected\": {",
      "      \"mem\": {",
      "        \"measurement\": [\"mem_used_percent\"],",
      "        \"metrics_collection_interval\": 60",
      "      }",
      "    }",
      "  }",
      "}",
      "EOT",
      "sudo systemctl restart amazon-cloudwatch-agent",
      
      # Install AWS SSM Agent using Snap
      "sudo snap install amazon-ssm-agent --classic",

      # Start SSM Agent without assuming service file exists
      "sudo snap start amazon-ssm-agent"
    ]
  }
}
