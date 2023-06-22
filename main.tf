provider "aws"{
region = "us-east-2"
access_key= "AKIARQ22MT2V4ZTRAS7Y"
secret_key= "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"
}

# 1. Create a vpc
resource "aws_vpc" "edu-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
  Name = "main"
}
}

# 2. Create Internet gateway
resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.edu-vpc.id
 }

 # 3. Create custome route table

 resource "aws_route_table" "edu-route-table" {
vpc_id = aws_vpc.edu-vpc.id
route {
cidr_block = "0.0.0.0/0"
# this means all traffic is allowed
     gateway_id = aws_internet_gateway.gw.id
   }
   route {
     ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
}
 tags = {
     Name = "main"
   }
 }

 # 4. Create subnet where our webserver is going to reside on_failure
 resource "aws_subnet" "subnet-1" {
   vpc_id            = aws_vpc.edu-vpc.id
   cidr_block        = "10.0.1.0/24"
   availability_zone = "us-east-2a"

   tags = {
     Name = "main-subnet"
   }
 }
# 5. Associate route table to subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.edu-route-table.id
}
# 6. Create a security group
resource "aws_security_group" "allow_web" {
   name        = "allow_web_traffic"
   description = "Allow Web inbound traffic"
     vpc_id      = aws_vpc.edu-vpc.id
ingress {
     description = "HTTPS"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
}
ingress {
     description = "HTTP"
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "SSH"
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

   tags = {
     Name = "allow_web"
   }
 }

 # 7. Create a network_interface

 resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
   security_groups = [aws_security_group.allow_web.id]
}

# 8. Create elastic_ip
resource "aws_eip" "one" {
   domain                    = "vpc"
   network_interface         = aws_network_interface.web-server-nic.id
   associate_with_private_ip = "10.0.1.50"
   depends_on                = [aws_internet_gateway.gw]
 }

# 9. Create aws_instance

resource "aws_instance" "web-server-instance1" {
   ami               = "ami-0e820afa569e84cc1"
   instance_type     = "t2.micro"
   availability_zone = "us-east-2a"
   key_name          = "santhosh"
depends_on                = [aws_eip.one]
   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic.id
   }

   user_data = <<-EOF
                 #!/bin/bash
       sudo yum update -y
       sudo amazon-linux-extras install java-openjdk11 -y
       sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
       sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
       sudo yum install jenkins -y
       sudo systemctl start jenkins
                 EOF
   tags = {
     Name = "web-server"
   }
 }
