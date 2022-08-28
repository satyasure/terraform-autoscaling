data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["amazon"]
    filter {
      name = "name"
      values = "[ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*]"
    }
}
data "aws_availability_zones" "available" { 
}

data "aws_subnet_ids" "vpc_subnets" {
  vpc_id = var.vpc_id
}

data "aws_subnet" "vpc_subnets" {
  for_each = data.aws_subnet_ids.vpc_subnets.ids
  id       = each.value
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Private"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Public"
  }
}