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
  region = "eu-west-1"
}


  
# 1. Create A Custom VPC

resource "aws_vpc" "prod-vpc" {
   cidr_block = "10.0.0.0/16"
   tags = {
       Name = "production"
   }
}
  
# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
   vpc_id = aws_vpc.prod-vpc.id
  
}

# 3. Custom Route Table
resource "aws_route_table" "prod-route-table" {
   vpc_id = aws_vpc.prod-vpc.id

   route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
   }
   tags = {
     Name = "Prod"
   }
}

# 4. Create A Subnet

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-1a"

    tags = {
      Name = "prod-subnet"
   }
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-1b"

    tags = {
      Name = "int-prod-subnet"
   }
}


# 5. Assosciate Subnet With Route Table

resource "aws_route_table_association" "srta" {
     subnet_id        = aws_subnet.subnet-1.id
     route_table_id   = aws_route_table.prod-route-table.id

}

# 6. Create Security Group to allow port 22, 80, And 443

resource "aws_security_group" "allow_web" {
   name          = "allow_web_traffic"
   description   = "Allow Web inbound traffic"
   vpc_id = aws_vpc.prod-vpc.id

ingress {

    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
 
ingress {

    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
   
ingress {

    description = "HTTPS from VPC"
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

   tags = {
     Name = "allow_web"
   }
}


# 7. Create A Network Interface With An Ip In The Subnet That Was Created In Step 4

resource "aws_network_interface" "web-server-nic" {
    subnet_id		= aws_subnet.subnet-1.id
    private_ips		= ["10.0.1.50"]
    security_groups	= [aws_security_group.allow_web.id]

    
}


# 8. Assign An Elastic IP To The Network Interface Created In Step 7

resource "aws_eip" "one" {
    vpc				= true
    network_interface		= aws_network_interface.web-server-nic.id
    associate_with_private_ip  = "10.0.1.50"
    depends_on			= [aws_internet_gateway.gw]	
}

# 9. Create Ubuntu Server And Install/Enable Apache2

resource "aws_instance" "prod-srv-1" {
  ami           = "ami-00aa9d3df94c6c354"
  instance_type = "t2.micro"
  availability_zone = "eu-west-1a"
  tenancy       = "default"
  key_name      = "new"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              echo "Welcome To Production INC" | sudo tee /var/www/html/index.html > /dev/null
              EOF

  tags = {
    Name = "web-server"
  }
}
 

