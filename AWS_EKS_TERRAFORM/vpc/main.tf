#vpc
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true     

  tags = merge(
    var.tags,
    {
      "Name" = "${var.name_prefix}-vpc"
    }   
  )
}

#internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      "Name" = "${var.name_prefix}-igw"
    }
  )
}

#public subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    {
      "Name" = "${var.name_prefix}-public-subnet-${var.azs[count.index]}"
      type = "public"
    }
  )
}

#private subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    {
      "Name" = "${var.name_prefix}-private-subnet-${var.azs[count.index]}"
      type = "private"
    }
  )
}

#nat gateway
resource "aws_nat_gateway" "main" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    allocation_id = aws_eip.nat[count.index].id
    subnet_id = aws_subnet.public[count.index].id

    depends_on = [ aws_internet_gateway.main ]
    tags = merge(
        var.tags,
        {
            "Name" = "${var.name_prefix}-nat-gateway-${count.index + 1}"
        }
    )
}

#elastic ip for nat gateway
resource "aws_eip" "nat" {
    count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
    domain = "vpc"

    tags = merge(
        var.tags,
        {
            "Name" = "${var.name_prefix}-nat-eip-${count.index + 1}"
        }
    )
}

#route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

    tags = merge(
        var.tags,
        {
            "Name" = "${var.name_prefix}-public-rt"
        }
    )
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}     

#route tabel association for public subnets
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#route table for private subnets
resource "aws_route_table" "private" {
  # CRITICAL: This count makes count.index available
  count  = length(var.private_subnets) 
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.enable_nat_gateway ? (var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id) : null
  }

  tags = merge(
    var.tags,
    {
      "Name" = "${var.name_prefix}-private-rt-${count.index + 1}"
    }
  )
}

#route table association for private subnets
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id

}