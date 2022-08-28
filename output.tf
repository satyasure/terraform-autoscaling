output "subnet_ids" {
  value = [for s in data.aws_subnet.vpc_subnets : s.aws_subnet_ids]
}