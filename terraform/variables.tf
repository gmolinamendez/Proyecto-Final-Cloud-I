variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nombre base del proyecto"
  default     = "cloudshop-enterprise"
}

variable "admin_email" {
  type        = string
  description = "Correo administrador/remitente verificado para SES"
}

variable "notification_email" {
  type        = string
  description = "Correo destino verificado para recibir notificaciones de pedidos"
}
