output "name" { value = google_compute_instance.this.name }
output "service_account" { value = google_service_account.this.email }output "cluster_name" { value = google_container_cluster.this.name }
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "node_zones" { type = list(string) }
variable "network_id" { type = string }
variable "subnetwork_id" { type = string }
variable "pod_range_name" { type = string }
variable "service_range_name" { type = string }
variable "node_service_account" { type = string }
variable "node_machine_type" { type = string }
variable "admin_cidrs" { type = map(string) }
variable "private_endpoint_only" { type = bool }
variable "node_limits" {
  type = object({ min = number, max = number })
}
variable "cidrs" {
  type = object({
    nodes    = string
    pods     = string
    services = string
    master   = string
  })
}