# Values are supplied only by live/gcp/dr/terragrunt.hcl.
# No defaults here: do not silently fall back to obsolete examples.

variable "project_id" {
  description = "GCP project used by this DR environment."
  type        = string
  nullable    = false
}

variable "region" {
  description = "Region for the DR subnet, NAT and shared snapshot policy."
  type        = string
  nullable    = false
}

variable "zone" {
  description = "Zone for the DR GKE cluster, node pool and Bastion."
  type        = string
  nullable    = false
}

variable "gke_subnet_cidr" {
  description = "Primary IPv4 CIDR of the existing GKE subnet."
  type        = string
  nullable    = false
}

variable "gke_pod_cidr" {
  description = "IPv4 CIDR of the existing GKE Pod secondary range."
  type        = string
  nullable    = false
}

variable "gke_pod_range_name" {
  description = "Existing GKE-created secondary/internal range name; this configuration does not create the internal range."
  type        = string
  nullable    = false
}

variable "private_services_address" {
  description = "Base address of the existing Private Service Access reserved range."
  type        = string
  nullable    = false
}

variable "private_services_prefix_length" {
  description = "Prefix length of the existing Private Service Access reserved range."
  type        = number
  nullable    = false
}

variable "gke_node_count" {
  description = "Desired size of the DR node pool; changing this value does not implement automatic failover."
  type        = number
  nullable    = false
}

variable "gke_node_machine_type" {
  description = "Machine type of the DR GKE nodes."
  type        = string
  nullable    = false
}

variable "gke_node_disk_size_gb" {
  description = "Boot disk size of each GKE node in GiB."
  type        = number
  nullable    = false
}

variable "bastion_machine_type" {
  description = "Machine type of the DR Bastion."
  type        = string
  nullable    = false
}
