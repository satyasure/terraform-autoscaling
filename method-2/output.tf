output "instance_ids" {
    value = ["${aws_instance.web-server.*.public_ip}"]
}
output "elb_dns_name" {
    value = "${aws_elb.asg_elb.dns_name}"
}