variable "cloud_provider" {
    type = map
}
variable "user_info" {
    type = map
}
variable "vm_param" {
    type = map
}
variable "web_param" {
    type = map
}
variable "aws_access_token" {
  type = string
  sensitive = true
}
variable "aws_secret_key" {
  type = string
  sensitive = true
}
variable "rebrain_dns_zone" {
  type = string
  sensitive = true
}
variable "dns_name" {
  type = string
  sensitive = false
}
variable "enable_ssl" {
  type = bool
  sensitive = false
}