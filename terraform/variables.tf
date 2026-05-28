variable "aws_region" {
  default = "us-east-1"
}

variable "trading_mode" {
  default = "paper"
}

variable "alpaca_api_key" {
  sensitive = true
}

variable "alpaca_secret_key" {
  sensitive = true
}

variable "alpaca_base_url" {
  default = "https://paper-api.alpaca.markets"
}

variable "ssh_public_key" {}
