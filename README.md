# Terraform Autoscaling and ELB.

Autoscaling Groups and Elastic Load Balancing (ASG and ELB)

# Auto Scaling Group

1. Auto scaling ensure that EC2 instances are sufficient to run your application.
2. When the number of requests increases the load on the VM instance increase AWS will identify and auto scale the resources as per the defined configuration

## Auto scaling group

> An Auto Scaling group contains a collection of EC2 instances that are treated as a logical grouping for the purposes of automatic scaling and management. 

> An Auto Scaling group also enables you to use Amazon EC2 Auto Scaling features such as health check replacements and scaling policies

![Auto Scaling](./images/AWS-ELB-tutorial-architecture-diagram.png)


## Elastic Load Balancing

> Elastic Load Balancing automatically distributes your incoming application traffic across all the EC2 instances that you are running.

> Elastic Load Balancing helps to manage incoming requests by optimally routing traffic so that no one instance is overwhelmed.

> To use Elastic Load Balancing with your Auto Scaling group, attach the load balancer to your Auto Scaling group. 

> This registers the group with the load balancer, which acts as a single point of contact for all incoming web traffic to your Auto Scaling group.

> Elastic Load Balancing provides four types of load balancers that can be used with your Auto Scaling group: 

1. Application Load Balancers

2. Network Load Balancers

3. Gateway Load Balancers

4. Classic Load Balancers.

There is a key difference in how the load balancer types are configured. With Application Load Balancers, Network Load Balancers, and Gateway Load Balancers, instances are registered as targets with a target group, and you route traffic to the target group. With Classic Load Balancers, instances are registered directly with the load balancer.

### Application Load Balancer

Routes and load balances at the application layer (HTTP/HTTPS), and supports path-based routing. 

An Application Load Balancer can route requests to ports on one or more registered targets, such as EC2 instances, in your virtual private cloud (VPC).

![Application Load Balancer](./images/ALB-Component_Architecture.png)

### Network Load Balancer

Routes and load balances at the transport layer (TCP/UDP Layer-4), based on address information extracted from the Layer-4 header. 

Network Load Balancers can handle traffic bursts, retain the source IP of the client, and use a fixed IP for the life of the load balancer.

### Gateway Load Balancer

Distributes traffic to a fleet of appliance instances. 

Provides scale, availability, and simplicity for third-party virtual appliances, such as firewalls, intrusion detection and prevention systems, and other appliances. 

Gateway Load Balancers work with virtual appliances that support the GENEVE protocol. 

Additional technical integration is required, so make sure to consult the user guide before choosing a Gateway Load Balancer.

### Classic Load Balancer

Routes and load balances either at the transport layer (TCP/SSL), or at the application layer (HTTP/HTTPS).

# Build a AWS ELB with Terraform.

Terraform template includes:

Create 2 EC2 instance as the backe-end member servers.  We will run basic web service (HTTP on TCP 80) on these 2 EC2 instances;
Create a AWS Elastic LB who is listening on TCP 80 and perform health check to verify the status of backend web servers;
Create a security group for ELB, which allows incoming HTTP session to ASW ELB and health check to back-end web servers;
Create a security group on for back-end web server, which allows management SSH connection SSH (TCP22) and ELB health check;

```hcl

provider "aws" {
region = "ap-southeast-2"
shared_credentials_file = "${pathexpand("~/.aws/credentials")}"
#shared_credentials_file = "/home/dzhang/.aws/credentials"
}
resource "aws_instance" "web1" {
ami = "ami-4ba3a328"
instance_type = "t2.micro"
vpc_security_group_ids = ["${aws_security_group.websg.id}"]
user_data = <<-EOF
#!/bin/bash
echo "hello, I am web1" >index.html
nohup busybox httpd -f -p 80 &
EOF

lifecycle {
create_before_destroy = true
}

tags {
Name = "terraform-web1"
}
}

resource "aws_instance" "web2" {
ami = "ami-4ba3a328"
instance_type = "t2.micro"
vpc_security_group_ids = ["${aws_security_group.websg.id}"]
key_name = "${aws_key_pair.myawskeypair.key_name}"
user_data = <<-EOF
#!/bin/bash
echo "hello, I am Web2" >index.html
nohup busybox httpd -f -p 80 &
EOF

lifecycle {
create_before_destroy = true
}

tags {
Name = "terraform-web2"
}
}

resource "aws_key_pair" "myawskeypair" {
key_name = "myawskeypair"
public_key = "${file("awskey.pub")}"
}

resource "aws_security_group" "websg" {
name = "security_group_for_web_server"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

lifecycle {
create_before_destroy = true
}
}

resource "aws_security_group_rule" "ssh" {
security_group_id = "${aws_security_group.websg.id}"
type = "ingress"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["60.242.xxx.xxx/32"]
}

data "aws_availability_zones" "allzones" {}
resource "aws_security_group" "elbsg" {
name = "security_group_for_elb"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}

lifecycle {
create_before_destroy = true
}
}

resource "aws_elb" "elb1" {
name = "terraform-elb"
availability_zones = ["${data.aws_availability_zones.allzones.names}"]
security_groups = ["${aws_security_group.elbsg.id}"]

listener {
instance_port = 80
instance_protocol = "http"
lb_port = 80
lb_protocol = "http"
}
health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 3
target = "HTTP:80/"
interval = 30
}

instances = ["${aws_instance.web1.id}","${aws_instance.web2.id}"]
cross_zone_load_balancing = true
idle_timeout = 400
connection_draining = true
connection_draining_timeout = 400

tags {
Name = "terraform-elb"
}
}

output "availabilityzones" {
value = ["${data.aws_availability_zones.allzones.names}"]
}

output "elb-dns" {
value = "${aws_elb.elb1.dns_name}"
}
```hcl