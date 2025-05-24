# ACM Certificate for HTTPS support
# This creates a certificate in AWS Certificate Manager for the ALB

# Variable for domain name (optional)
variable "domain_name" {
  description = "Domain name for the application (e.g., pricing-agent.example.com). Leave empty to use HTTP only."
  type        = string
  default     = ""
}

# Variable to control HTTPS usage
variable "enable_https" {
  description = "Enable HTTPS for the ALB. If true and domain_name is empty, a self-signed certificate will be used."
  type        = bool
  default     = true
}

# Create a certificate only if HTTPS is enabled and a domain name is provided
resource "aws_acm_certificate" "main" {
  count = var.enable_https && var.domain_name != "" ? 1 : 0
  
  domain_name       = var.domain_name
  validation_method = "DNS"
  
  # Add wildcard as subject alternative name
  subject_alternative_names = ["*.${var.domain_name}"]
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = local.common_tags
}

# Local variable for certificate ARN
locals {
  certificate_arn = var.enable_https && var.domain_name != "" ? aws_acm_certificate.main[0].arn : null
}

# Output the certificate ARN for reference
output "certificate_arn" {
  description = "ARN of the ACM certificate (if created)"
  value       = local.certificate_arn
}
