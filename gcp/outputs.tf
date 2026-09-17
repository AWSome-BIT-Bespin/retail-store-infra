output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "network_id" {
  value = module.network.network_id
}

output "node_service_account" {
  value = module.iam.node_service_account
}

output "ingress_ip_name" {
  value = google_compute_global_address.ingress.name
}

output "ingress_ip" {
  value = google_compute_global_address.ingress.address
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}${var.private_endpoint_only ? " --internal-ip" : ""}"
}

output "get_credentials_private_command" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id} --internal-ip"
}

output "bastion_ssh_command" {
  value = var.create_bastion ? "gcloud compute ssh ${module.bastion[0].name} --zone ${var.node_zones[0]} --project ${var.project_id} --tunnel-through-iap" : null
}

output "bastion_service_account" {
  value = var.create_bastion ? module.bastion[0].service_account : null
}