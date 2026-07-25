resource "aws_ses_email_identity" "admin" {
  email = var.admin_email
}

resource "aws_ses_email_identity" "notification" {
  email = var.notification_email
}
