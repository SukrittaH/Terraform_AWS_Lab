terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-1"
  access_key = "YOUR ACCESS KEY"
  secret_key = "YOUR SECRET KEY"
}

#Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "Prod-VPC"
  }
}

#Create internet gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
  
}
#Create custom route table
resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }
  tags = {
    Name = "Route-table-Prod"
  }
  
}

#Create a Subnet
resource "aws_subnet" "Subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "Subnet1-Prod"
  }
}

# Associate subnet to route table
resource "aws_route_table_association" "subnet-route-as" {
  subnet_id      = aws_subnet.Subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#Create Security group to allow 22, 80, 443 ports
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Create Network interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.Subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#Assign an elastic IP to network interface we created
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]

}

# Create an Ubuntu Server
resource "aws_instance" "web-server-instance" {
   ami = "ami-0590f3a1742b17914"
   instance_type = "t2.micro"
   availability_zone = "ap-northeast-1a"
   key_name = "test-key"

   network_interface {
     network_interface_id = aws_network_interface.web-server-nic.id
     device_index = 0
   }

   user_data = <<-EOF
              #! /bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
    
    tags =  {
        Name = "web-server"
    }

}

