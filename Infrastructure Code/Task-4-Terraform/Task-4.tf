# cloud provider

provider "aws" {
  region     = "ap-south-1"
  profile    ="venkatesh"
  version    = "~> 2.70"
}

# vpc

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "Task3-VPC"
  }
}
output "vpc_id" {
  value = aws_vpc.myvpc.id
}


# internet gateway to connect public world

resource "aws_internet_gateway" "gw" {

  depends_on = [ aws_vpc.myvpc ]

  vpc_id = aws_vpc.myvpc.id


  tags = {
    Name = "my-internet-gateway"
  }
}
output "internet_gateway_id" {
  value = aws_internet_gateway.gw.id
}
resource "aws_eip" "eip"{

  depends_on = [aws_vpc.myvpc,aws_internet_gateway.gw]

  vpc = true
}

# NAT gateway

resource "aws_nat_gateway" "natgw"{

  depends_on = [aws_vpc.myvpc,aws_eip.eip,aws_subnet.public]

  allocation_id = aws_eip.eip.id
  subnet_id= aws_subnet.public.id

  tags = {
    Name = "NAT gateway"
  }
}


# route table for internet gateway

resource "aws_route_table" "route-table" {

  depends_on = [ aws_internet_gateway.gw ]

  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
    
  }

  tags = {
    Name = "route-table"
  }
}
output "route_table_id" {
  value = aws_route_table.route-table.id
}

# route table for NAT gateway

resource "aws_route_table" "route-table-2" {

  depends_on = [ aws_internet_gateway.gw,aws_nat_gateway.natgw ]

  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
    
  }

  tags = {
    Name = "route-table-2"
  }
}
output "route_table_id-2" {
  value = aws_route_table.route-table-2.id
}

# route table association for public subnet

resource "aws_route_table_association" "a" {

  depends_on = [ aws_subnet.public ]

  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route-table.id
}
output "route_table_association_id" {
  value = aws_route_table_association.a.id
}

# route table association for public subnet Nat gateway association

resource "aws_route_table_association" "nat_route_association" {

  depends_on = [aws_route_table.route-table-2]

  subnet_id = aws_subnet.private.id

  route_table_id = aws_route_table.route-table-2.id
} 

# aws subnets of our vpc

resource "aws_subnet" "public" {

  depends_on = [ aws_vpc.myvpc ]

  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  

  tags = {
    Name = "subnet-1"
  }
}
output "aws_subnet_public" {
  value = aws_subnet.public.id
}

# aws subnets of our vpc 

resource "aws_subnet" "private" {

  depends_on = [ aws_vpc.myvpc ]

  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "subnet-2"
  }
}
output "aws_subnet_private" {
    value = aws_subnet.private.id
}

# WordPress security group for our instance

resource "aws_security_group" "wordpress-sg" {

  depends_on = [ aws_vpc.myvpc ]

  name        = "wordpress-sg"
  description = "security group for myvpc(wordpress)"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.myvpc.cidr_block]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-sg"
  }
}
output "aws_security_group_wordpress-sg" {
  value = aws_security_group.wordpress-sg.id
}

# MYSQL security group for our instance

resource "aws_security_group" "mysql-sg" {
  
  depends_on = [ aws_vpc.myvpc ]

  name        = "mysql-sg"
  description = "security group for myvpc(mysql)"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-sg"
  }
}
output "aws_security_group_mysql-sg" {
    value = aws_security_group.mysql-sg.id
}

#  Security group for bashion host

resource "aws_security_group" "bashion_host" {
  depends_on = [aws_vpc.myvpc]

  name = "bashion-host"
  description = "allow ssh login to bashion host"
  vpc_id  = aws_vpc.myvpc.id

  ingress {
    description = "allow ssh"
    from_port = 22
    to_port  = 22
    protocol = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }
   egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks =  ["0.0.0.0/0"]
  }
}

# creating security rules for ssh to my sql via basion host server

resource "aws_security_group" "sg" {

  depends_on = [aws_vpc.myvpc,aws_security_group.bashion_host]

  name = "allowing_bashion_host_to-ssh"
  description = "bashion_host_allow_ssh"
  vpc_id = aws_vpc.myvpc.id 

  ingress {
    description = "allow ssh"
    from_port = 22
    to_port =  22
    protocol = "tcp"
    security_groups =[ aws_security_group.bashion_host.id ]
  }
   ingress {
    description = "ping"
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.bashion_host.id]
  }

  egress {
    from_port= 0
    to_port= 0
    protocol = "-1"
    cidr_blocks= ["0.0.0.0/0"]
  }

}


#  EC2 Wordpress instance
 
resource "aws_instance" "wordpress" {

  depends_on = [ aws_internet_gateway.gw ]

  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  key_name      = "newKey"
  subnet_id     = aws_subnet.public.id
  security_groups = [ aws_security_group.wordpress-sg.id ]
  tags = {
    Name = "Wordpress"
  }
}
output "aws_instance_wordpress" {
    value = aws_instance.wordpress.id
}

#  EC2 MYSQL instance

resource "aws_instance" "mysql" {
  

  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "newKey"
  subnet_id     = aws_subnet.private.id
  vpc_security_group_ids = [ aws_security_group.mysql-sg.id,aws_security_group.sg.id ]
  tags = {
    Name = "MYSQL"
  }
}
output "aws_instance_mysql" {
    value = aws_instance.mysql.id
}


#  EC2 WordPress bashion host

resource "aws_instance" "bashion_host" {

  depends_on = [aws_vpc.myvpc,aws_security_group.wordpress-sg,aws_internet_gateway.gw,
      aws_route_table.route-table,aws_route_table.route-table-2]

  ami = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  key_name = "newKey"
  security_groups = [ aws_security_group.bashion_host.id ]
  subnet_id = aws_subnet.public.id
  associate_public_ip_address = "true"

  tags = {
    Name = "Bashion Host-Server"
  }
}