# Create VPC
resource "aws_vpc" "my-network" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    enable_classiclink = "false"
    tags = {
        Name = "my-network"
    }
}

# Create Subnets
resource "aws_subnet" "my-network-public-1" {
    vpc_id = "${aws_vpc.my-network.id}"
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-2a"

    tags = {
        Name = "my-network-public-1"
    }
}

resource "aws_subnet" "my-network-public-2" {
    vpc_id = "${aws_vpc.my-network.id}"
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "us-east-2b"

    tags = {
        Name = "my-network-public-2"
    }
}

resource "aws_subnet" "my-network-private-1" {
    vpc_id = "${aws_vpc.my-network.id}"
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "us-east-2a"

    tags = {
        Name = "my-network-private-1"
    }
}

resource "aws_subnet" "my-network-private-2" {
    vpc_id = "${aws_vpc.my-network.id}"
    cidr_block = "10.0.4.0/24"
    map_public_ip_on_launch = "false"
    availability_zone = "us-east-2b"

    tags = {
        Name = "my-network-private-2"
    }
}

# Create GW
resource "aws_internet_gateway" "my-network-gw" {
    vpc_id = "${aws_vpc.my-network.id}"

    tags = {
        Name = "my-network-gw"
    }
}

# Create RT
resource "aws_route_table" "my-network-public" {
    vpc_id = "${aws_vpc.my-network.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.my-network-gw.id}"
    }

    tags = {
        Name = "my-network-public-1"
    }
}

# Create RTA for Public
resource "aws_route_table_association" "my-network-public-1-a" {
    subnet_id = "${aws_subnet.my-network-public-1.id}"
    route_table_id = "${aws_route_table.my-network-public.id}"
}
resource "aws_route_table_association" "my-network-public-2-a" {
    subnet_id = "${aws_subnet.my-network-public-2.id}"
    route_table_id = "${aws_route_table.my-network-public.id}"
}

# Create RTA for Private
resource "aws_route_table_association" "my-network-private-1-a" {
    subnet_id = "${aws_subnet.my-network-private-1.id}"
    route_table_id = "${aws_route_table.my-network-private.id}"
}
resource "aws_route_table_association" "my-network-private-2-a" {
   subnet_id = "${aws_subnet.my-network-private-2.id}"
   route_table_id = "${aws_route_table.my-network-private.id}"
}

# Create NG
resource "aws_eip" "my-network-nat" {
vpc      = true

tags = {
        Name = "my-network-nat"
    }

}
resource "aws_nat_gateway" "my-network-nat-gw" {
allocation_id = "${aws_eip.my-network-nat.id}"
subnet_id = "${aws_subnet.my-network-public-1.id}"
#depends_on = ["aws_internet_gateway.my-network-gw"]
}

# Create VPC for NAT
resource "aws_route_table" "my-network-private" {
    vpc_id = "${aws_vpc.my-network.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.my-network-nat-gw.id}"
    }

    tags = {
        Name = "my-network-private-1"
    }
}
# Create private routes
#resource "aws_route_table_association" "my-network-private-1-a" {
#    subnet_id = "${aws_subnet.my-network-private-1.id}"
#    route_table_id = "${aws_route_table.my-network-private.id}"
#}
#resource "aws_route_table_association" "my-network-private-2-a" {
#    subnet_id = "${aws_subnet.my-network-private-2.id}"
#    route_table_id = "${aws_route_table.my-network-private.id}"
#}

# ASG
resource "aws_placement_group" "ASG" {
  name     = "ASG"
  strategy = "cluster"
}

resource "aws_autoscaling_group" "ASG" {
    desired_capacity          = 1
    health_check_grace_period = 300
    health_check_type         = "EC2"
    launch_configuration      = "${aws_launch_configuration.ASLC.id}"
    max_size                  = 2
    min_size                  = 1
    name                      = "ASG"
    vpc_zone_identifier       = ["${aws_subnet.my-network-private-1.id}", "${aws_subnet.my-network-private-2.id}"]

    tag {
        key   = "Name"
        value = "Bastion-ASG"
        propagate_at_launch = true
    }
	
timeouts {
    delete = "1m"
 }
}

# Create Auto Scaling Launch configuration
resource "aws_launch_configuration" "ASLC" {
  name            = "Launch configuration for Auto Scaling"
  image_id = "${data.aws_ami.centos.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.ASG-Security-Group.id}"]
  key_name = "centos_aws_ssh"
  lifecycle {
    create_before_destroy = true
  }
  root_block_device {
    delete_on_termination = true
  }
}

# Create ASG 
resource "aws_security_group" "ASG-Security-Group" {
  name = "ASG Security Group"
  vpc_id = "${aws_vpc.my-network.id}"
  
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
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
    Name = "ASG Security Group"
  }
}

#output "bastion_public_ip" {
#  value = "${aws_instance.bastion.public_ip}"
#}

# Creating RDS
resource "aws_db_instance" "RDS" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "rds"
  username             = "admin"
  password             = "adminadmin"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name   = "${aws_db_subnet_group.sg-rds.name}"
  vpc_security_group_ids = ["${aws_security_group.RDS-SG.id}"]
  skip_final_snapshot  = true
}

# Subnets Group for RDS
resource "aws_db_subnet_group" "sg-rds" {
  name        = "subnet-group-rds"
  subnet_ids  = ["${aws_subnet.my-network-private-1.id}", "${aws_subnet.my-network-private-2.id}"]
  
  tags = {
    Name = "My DB subnet group"
  }
}

# Security group for RDS
resource "aws_security_group" "RDS-SG" {
  name   = "RDS Security Group"
  vpc_id = "${aws_vpc.my-network.id}"
   
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "ALB" {
name               = "ALB-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.my-network-private-1.id}", "${aws_subnet.my-network-private-2.id}"]

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

# Security group for Aplication Load Balancer
resource "aws_security_group" "lb_sg" {
  name   = "lb_sg-security-group"
  vpc_id = "${aws_vpc.my-network.id}"

ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create aws_lb_target_group
resource "aws_lb_target_group" "TG" {
  name     = "lb-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.my-network.id}"
  health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200-299"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
 }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}




# Create LB listener
resource "aws_lb_listener" "lb-listener" {
    load_balancer_arn = "${aws_lb.ALB.arn}"
    port = "80"
    protocol = "HTTP"
#	depen_on = "${aws_lb_target_group.TG}"

   default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.TG.arn}"
  }
}

#Create AMI
data "aws_ami" "centos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS *"]
  }
	filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["679593333241"]
}

# Create Bastion
resource "aws_instance" "Bastion" {
  ami           = "${data.aws_ami.centos.id}"
  instance_type = "t2.micro"
  key_name = "centos_aws_ssh"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.bastion-sg.id}"]
  subnet_id = "${aws_subnet.my-network-public-1.id}"
  
  root_block_device {
  delete_on_termination = true
  }
  
  tags = {
    Name = "Bastion"
 }
}

# Security group for Bastion
resource "aws_security_group" "bastion-sg" {
  name   = "bastion-security-group"
  vpc_id = "${aws_vpc.my-network.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Modify index.php_template with database instance IP address for MySQL  connection. 
#        provisioner "local-exec" {
#               command ="cp /terraform/project2/roles/app/files/index.php_template /terraform/project2/roles/app/files/index.php && sed -i 's/db_server/\"${aws_instance.db_wm.public_ip}\"/g' /terraform/project2/roles/app/files/index.php"
#        }
#DB instance related playbook
    resource "null_resource" "run-ansible" {
     provisioner "local-exec" {
     command = <<EOT
     cd /home/ansible
     sleep 300
     ansible-playbook -i ec2.py wordpress.yml
     EOT
  }
}
