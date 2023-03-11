variable "location" {
 type = string
 default = "East US"
}
variable "sku" {
  default = {
    westus2 = "16.04-LTS"
    "East US"  = "18.04-LTS"
  }
}

variable "admin_username" {
 type    = string
 default = "username"
}

variable "admin_password" {
 type = string
 default = "Pa$$w0rd"
}
