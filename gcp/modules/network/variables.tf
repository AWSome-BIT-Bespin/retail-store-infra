variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "cidrs" {
  type = object({
    nodes    = string
    pods     = string
    services = string
    master   = string
  })
}