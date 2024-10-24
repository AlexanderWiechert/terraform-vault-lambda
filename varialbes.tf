variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "key_name" {
  description = "Name des SSH-Schlüsselpaares"
  type        = string
}
