data "aws_availability_zones" "all" {}

# Step 1: Creating EC2 instance
resource "aws_instance" "web-server" {
  ami                    = "${lookup(var.amis,var.region)}"
  count                  = "${var.count}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
  source_dest_check      = false
  instance_type          = "${var.instance_type}"
tags {
    Name = "${format("web-server%03d", count.index + 1)}"
  }
}
# Step 2: Creating Security Group for EC2
resource "aws_security_group" "instance" {
  name = "terraform-asg_elb-instance"
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Step3: Creating Launch Configuration
resource "aws_launch_configuration" "asg_elb" {
  image_id               = "${lookup(var.amis,var.region)}"
  instance_type          = "t2.micro"
  security_groups        = ["${aws_security_group.instance.id}"]
  key_name               = "${var.key_name}"
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  lifecycle {
    create_before_destroy = true
  }
}
# Step 4: Creating AutoScaling Group

resource "aws_autoscaling_group" "asg_elb" {
  launch_configuration = "${aws_launch_configuration.asg_elb.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size = 2
  max_size = 4
  load_balancers = ["${aws_elb.asg_elb.name}"]
  health_check_type = "ELB"
  tag {
    key = "Name"
    value = "terraform-asg-asg_elb"
    propagate_at_launch = true
  }
}
# Step 5: Security Group for ELB

resource "aws_security_group" "elb" {
  name = "terraform-asg_elb-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Step 6: Creating ELB
resource "aws_elb" "asg_elb" {
  name = "terraform-asg-asg_elb"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:8080/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }
}