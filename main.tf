resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames


  tags = merge(
    var.common_tags,
    var.vpc_tags,
    {
      Name = local.resource_name
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags,
    {
      Name = local.resource_name
    }
  )
}


#public subnet

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    var.common_tags,
    var.public_subnet_tags,
    {
        Name = "${local.resource_name}-public-${local.az_names[count.index]}"
    }
  )
}

# private subnet

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  #map_public_ip_on_launch = true
  tags = merge(
    var.common_tags,
    var.private_subnet_tags,
    {
        Name = "${local.resource_name}-private-${local.az_names[count.index]}"
    }
  )
}

# database subnet 

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)
  vpc_id = aws_vpc.main.id 
  cidr_block = var.database_subnet_cidrs[count.index]
  availability_zone = local.az_names[count.index]
  #map_public_ip_on_launch = true
  tags = merge(
    var.common_tags,
    var.database_subnet_tags,
    {
        Name = "${local.resource_name}-database-${local.az_names[count.index]}"
    }
  )
}

# DB subnet group for rds 
resource "aws_db_subnet_group" "default" {
  name = local.resource_name
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.common_tags,
    var.subnet_database_tags,
    {
      Name = local.resource_name
    }
  )
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = local.resource_name
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.database[0].id

  tags = merge(
    var.common_tags,
    var.nat_gateway_tags,
    {
      Name = local.resource_name
    }
  )
  # without igw , nat gatway will not work
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main]
}

#public route table
resource "aws_route_table" "public"{
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
     Name = "${local.resource_name}-public"  #expense-dev-public
    }
 )
}

#private route table 

resource "aws_route_table" "private"{
  vpc_id = aws_vpc.main.id
  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
    {
      Name = "${local.resource_name}-private"   #expense-dev-public
    }
  )
}

# database route table 

resource "aws_route_table" "database"{
  vpc_id = aws_vpc.main.id
  tags= merge(
    var.common_tags,
    var.database_route_table_tags,
    {
      Name = "${local.resource_name}-database"  #expense-dev-database
    }
  )
}

#routes 

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"  #destination is internet
  gateway_id = aws_internet_gateway.main.id  # using this it will go outside
  
}

resource "aws_route" "private_nat"{
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.main.id
}

resource "aws_route" "database_nat" {
  route_table_id = aws_route_table.database.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.main.id
}

# associating public-route-table to public subnets(1a, 1b)
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id  
}

# associating private-route-table to private subnets(1a, 1b)
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# associating database-route-table to database subnets(1a, 1b)
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)
  subnet_id = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
  
}



