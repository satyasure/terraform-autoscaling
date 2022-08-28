variable "count" {
    default = 1
  }
variable "instance_type" {
    type = string
    default = "t2.micro"
}
variable "region" {
  description = "AWS region for hosting our your network"
  default = "ap-south-1"
}

variable "profile" {
    type = string
    default = "default"
  
}