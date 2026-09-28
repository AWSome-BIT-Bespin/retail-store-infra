variable "cluster_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "role_name" {
  type = string
}

variable "alb_controller_namespace" {
  type = string
}

variable "alb_controller_service_account" {
  type = string
}

variable "alb_controller_policy_arn" {
  type = string
}

variable "autoscaler_namespace" {
  type = string
}

variable "autoscaler_service_account" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "eso_namespace" {
  type = string
}

variable "eso_service_account" {
  type = string
}

variable "eso_secret_arns" {
  type = list(string)
}

variable "eso_parameter_arns" {
  type = list(string)
}

variable "eso_role" {
    type = string
}

variable "eso_policy_name" {
    type = string
}


variable "cart_dynamo_role" {
    type = string
}

variable "cart_dynamo_policy_name" {
    type = string
}



variable "alb_role" {
    type = string
}


variable "autoscaler_role" {
    type = string
}

variable "autoscaler_policy_name" {
    type = string
}
