#Este es el q va manejar toda la tabla de dynamodb
#users
resource "aws_dynamodb_table" "usuarios" {
  name         = "${var.project_name}-usuarios"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "usuario_id"

  attribute {
    name = "usuario_id"
    type = "S"
  }
}
#stores
resource "aws_dynamodb_table" "tiendas" {
  name         = "${var.project_name}-tiendas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tienda_id"

  attribute {
    name = "tienda_id"
    type = "S"
  }
}
#products
resource "aws_dynamodb_table" "productos" {
  name         = "${var.project_name}-productos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "producto_id"

  attribute {
    name = "producto_id"
    type = "S"
  }
}

# Orders
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project_name}-pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }
}

# audit is a req
resource "aws_dynamodb_table" "auditoria" {
  name         = "${var.project_name}-auditoria"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "auditoria_id"

  attribute {
    name = "auditoria_id"
    type = "S"
  }
}