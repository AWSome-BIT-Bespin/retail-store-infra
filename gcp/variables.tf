variable "project_id" { type = string }
variable "name" { type = string }
variable "region" { type = string }
variable "node_zones" { type = list(string) }

variable "network_cidrs" {
  type = object({
    nodes    = string
    pods     = string
    services = string
    master   = string
  })
}

variable "admin_cidrs" { type = map(string) }
variable "private_endpoint_only" { type = bool }
variable "node_machine_type" { type = string }

variable "node_limits" {
  type = object({
    min = number
    max = number
  })
}

variable "create_bastion" { type = bool }
variable "bastion_project_roles" { type = set(string) }