variable "bastion_role_name" {
  type = string
}

variable "vpc_id" {
  type = string
}



variable "bastion_key_name" {
  type = string
}

variable "bastion_admin_cidr" {
  type = string
}

variable "private_app_subnet_ids"{
  type = list(string)
}
