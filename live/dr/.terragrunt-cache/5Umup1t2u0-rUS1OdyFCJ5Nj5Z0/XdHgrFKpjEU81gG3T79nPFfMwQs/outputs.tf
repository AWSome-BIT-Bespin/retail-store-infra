output "cluster_name" {
  value = google_container_cluster.retail.name
}

output "bastion_internal_ip" {
  value = google_compute_instance.bastion.network_interface[0].network_ip
}

output "bastion_ssh_command" {
  value = "gcloud compute ssh retail-dr-bastion --project=kdt4-3 --zone=asia-northeast3-a --tunnel-through-iap"
}

output "gke_credentials_from_bastion" {
  value = "gcloud container clusters get-credentials retail-dr-gke --project=kdt4-3 --zone=asia-northeast3-a --internal-ip"
}
