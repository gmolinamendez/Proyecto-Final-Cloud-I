resource "aws_cognito_user_pool" "users" {
  name             = "${var.project_name}-users"
  alias_attributes = ["email"]

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name            = "${var.project_name}-web"
  user_pool_id    = aws_cognito_user_pool.users.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

resource "aws_cognito_user_group" "administrador" {
  name         = "Administrador"
  user_pool_id = aws_cognito_user_pool.users.id
  description  = "Gestiona usuarios, tiendas, productos y reportes"
  precedence   = 1
}

resource "aws_cognito_user_group" "operador" {
  name         = "Operador"
  user_pool_id = aws_cognito_user_pool.users.id
  description  = "Gestiona inventario y pedidos"
  precedence   = 2
}

resource "aws_cognito_user_group" "cliente" {
  name         = "Cliente"
  user_pool_id = aws_cognito_user_pool.users.id
  description  = "Compra productos y consulta pedidos propios"
  precedence   = 3
}
