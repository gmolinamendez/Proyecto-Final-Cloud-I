resource "aws_dynamodb_table" "usuarios" {
  name = "${var.project_name}-usuarios"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "usuario_id"

  attribute {
    name = "usuario_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name = "email-index"
    hash_key = "email"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "tiendas" {
  name = "${var.project_name}-tiendas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "tienda_id"

  attribute {
    name = "tienda_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "productos" {
  name = "${var.project_name}-productos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "producto_id"

  attribute {
    name = "producto_id"
    type = "S"
  }

  attribute {
    name = "tienda_id"
    type = "S"
  }

  global_secondary_index {
    name = "tienda-index"
    hash_key = "tienda_id"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "pedidos" {
  name = "${var.project_name}-pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  attribute {
    name = "usuario_id"
    type = "S"
  }

  attribute {
    name = "estado"
    type = "S"
  }

  global_secondary_index {
    name = "usuario-index"
    hash_key = "usuario_id"
    projection_type = "ALL"
  }

  global_secondary_index {
    name = "estado-index"
    hash_key = "estado"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "auditoria" {
  name = "${var.project_name}-auditoria"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "auditoria_id"

  attribute {
    name = "auditoria_id"
    type = "S"
  }

  attribute {
    name = "fecha"
    type = "S"
  }

  global_secondary_index {
    name = "fecha-index"
    hash_key = "fecha"
    projection_type = "ALL"
  }
}
