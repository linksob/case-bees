
variable "tags" {
    description = "Tags"
    type        = map(string)
    default     = {}
}

variable "sns_email_endpoint" {
    description = "E-mail"
    type        = string
}
variable "aws_region" { 
    default = "sa-east-1" 
    type   = string
}
variable "bronze_bucket" { 
    default = "data-bronze" 
    type   = string
}
variable "silver_bucket" { 
    default = "data-silver" 
    type   = string
}
variable "gold_bucket" { 
    default = "data-gold" 
    type   = string
}
variable "scripts_bucket" { 
    default = "scripts" 
    type   = string
}

variable "athena_bucket" {
    default = "athena"
    type    = string
}

