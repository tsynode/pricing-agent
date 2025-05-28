# ACM Certificate for HTTPS support
# This creates a certificate in AWS Certificate Manager for the ALB

# Variable for domain name (optional)
variable "domain_name" {
  description = "Domain name for the application (e.g., pricing-agent.example.com). Leave empty to use a self-signed certificate."
  type        = string
  default     = ""
}

# Variable to control HTTPS usage
variable "enable_https" {
  description = "Enable HTTPS for the ALB. If true and domain_name is empty, a self-signed certificate will be used."
  type        = bool
  default     = true
}

# Create a public certificate if HTTPS is enabled and a domain name is provided
resource "aws_acm_certificate" "public" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  # Add wildcard as subject alternative name
  subject_alternative_names = ["*.${var.domain_name}"]
  
  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
  }
  
  tags = local.common_tags
}

# Output validation records for DNS configuration (when using a domain name)
output "certificate_validation_records" {
  description = "DNS validation records for the ACM certificate (if created with domain name)"
  value = var.enable_https && var.domain_name != "" ? {
    for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  } : null
}

# Create a self-signed certificate if HTTPS is enabled but no domain name is provided
resource "aws_acm_certificate" "self_signed" {
  count = var.enable_https && var.domain_name == "" ? 1 : 0
  
  private_key = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem
  
  lifecycle {
    prevent_destroy = false
    create_before_destroy = true
  }
  
  tags = local.common_tags
}

# Generate a private key for the self-signed certificate
resource "tls_private_key" "self_signed" {
  count = var.enable_https && var.domain_name == "" ? 1 : 0
  
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate a self-signed certificate
resource "tls_self_signed_cert" "self_signed" {
  count = var.enable_https && var.domain_name == "" ? 1 : 0
  
  private_key_pem = tls_private_key.self_signed[0].private_key_pem
  
  subject {
    common_name  = "pricing-agent.internal"
    organization = "Pricing Agent"
  }
  
  validity_period_hours = 8760 # 1 year
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

# Local variable for certificate ARN
locals {
  certificate_arn = var.enable_https ? (
    var.domain_name != "" ? aws_acm_certificate.public[0].arn : aws_acm_certificate.self_signed[0].arn
  ) : null
}

# Output the certificate ARN for reference
output "certificate_arn" {
  description = "ARN of the ACM certificate (if created)"
  value       = local.certificate_arn
}
