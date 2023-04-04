data "aws_availability_zones" "AZs" {
  state = "available"
}


locals {
  AZs_count = length(data.aws_availability_zones.AZs.names)
}


variable "DeploymentName" {}
variable "VPC_CIDR" {}
variable "IPv6_ENABLED" {}
variable "PubPrivPairCount" {}
variable "AUTHTAGS" {}


resource "aws_vpc" "RadLabVPC" {
  cidr_block                       = var.VPC_CIDR
  instance_tenancy                 = "default"
  enable_dns_hostnames             = "true"
  assign_generated_ipv6_cidr_block = var.IPv6_ENABLED ? true : false
  tags = {
    Name = var.DeploymentName
  }
}


resource "aws_subnet" "Pub-Subnet" {
  count                           = var.PubPrivPairCount
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index)
  ipv6_cidr_block                 = var.IPv6_ENABLED ? cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index) : null
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % local.AZs_count]
  assign_ipv6_address_on_creation = var.IPv6_ENABLED ? true : false
  map_public_ip_on_launch         = true
  tags = {
    Name = join("", [var.DeploymentName, "-Pub-", substr(data.aws_availability_zones.AZs.names[count.index % local.AZs_count], -2, -1)])
  }
}


resource "aws_subnet" "Priv-Subnet" {
  count                           = var.PubPrivPairCount
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index + var.PubPrivPairCount)
  ipv6_cidr_block                 = var.IPv6_ENABLED ? cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index + 4) : null
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % local.AZs_count]
  assign_ipv6_address_on_creation = var.IPv6_ENABLED ? true : false
  map_public_ip_on_launch         = false
  tags = {
    Name = join("", [var.DeploymentName, "-Priv-", substr(data.aws_availability_zones.AZs.names[count.index % local.AZs_count], -2, -1)])
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.RadLabVPC.id
  tags   = merge(var.AUTHTAGS, { Name = join("", [var.DeploymentName, "IGW"]) })
}


resource "aws_eip" "natgw_ip" {
  count      = var.PubPrivPairCount
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW-IP-", count.index])
  }
}


resource "aws_nat_gateway" "natgw" {
  count         = var.PubPrivPairCount
  allocation_id = aws_eip.natgw_ip[count.index].id
  subnet_id     = aws_subnet.Pub-Subnet[count.index].id
  depends_on    = [aws_internet_gateway.igw, aws_eip.natgw_ip]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW-", count.index])
  }
}


resource "aws_egress_only_internet_gateway" "egw" {
  count  = var.IPv6_ENABLED ? 1 : 0
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-EIGW"])
  }
}


resource "aws_route_table" "Pub-Route" {
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Pub"])
  }
}


resource "aws_route_table" "Priv-Route" {
  count      = var.PubPrivPairCount
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Priv-", count.index])
  }
}


resource "aws_route" "Pub" {
  depends_on             = [aws_route_table.Pub-Route]
  route_table_id         = aws_route_table.Pub-Route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


resource "aws_route" "Pub-v6" {
  depends_on                  = [aws_route_table.Pub-Route]
  count                       = var.IPv6_ENABLED ? 1 : 0
  route_table_id              = aws_route_table.Pub-Route.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}


resource "aws_route" "Priv" {
  count = var.PubPrivPairCount
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_route_table.Priv-Route, aws_nat_gateway.natgw]
  route_table_id         = aws_route_table.Priv-Route[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw[count.index].id
}


resource "aws_route_table_association" "PubAssociation" {
  count          = var.PubPrivPairCount
  subnet_id      = aws_subnet.Pub-Subnet[count.index].id
  route_table_id = aws_route_table.Pub-Route.id
}


resource "aws_route_table_association" "PrivAssociation" {
  count          = var.PubPrivPairCount
  subnet_id      = aws_subnet.Priv-Subnet[count.index].id
  route_table_id = aws_route_table.Priv-Route[count.index].id
}


output "VPCID" {
  value = aws_vpc.RadLabVPC.id
}
