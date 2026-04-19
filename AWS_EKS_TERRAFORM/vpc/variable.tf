variable "name_prefix" {
  description = "prefix for resource name"
  type= string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type = string
}

variable "azs" {
  description = "Availability zones for the VPC"
  type = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets"
  type = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets"
  type = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT gateway for private subnets"
  type = bool
  default = true
}

variable "single_nat_gateway" {
  description = "Whether to create a single NAT gateway for all private subnets"
  type = bool
  default = true
}

variable "public_subnet_tags" {
  description = "Tags to apply to public subnets"
  type = map(string)
  default = {}
}

variable "private_subnet_tags" {
  description = "tagsto apply to private subnets"
    type = map(string)
    default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type = map(string)
  default = {}
}
