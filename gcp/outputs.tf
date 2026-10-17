output "cluster_name" {
  value = google_container_cluster.retail.name
}

output "bastion_internal_ip" {
  value = google_compute_instance.bastion.network_interface[0].network_ip
}

output "bastion_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.bastion.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
}

output "gke_credentials_from_bastion" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.retail.name} --project=${var.project_id} --zone=${var.zone} --internal-ip"
}
