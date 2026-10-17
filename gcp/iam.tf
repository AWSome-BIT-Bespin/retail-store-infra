resource "google_service_account" "gke_node" {
  account_id   = "retail-dr-gke-node"
  display_name = "retail-dr-gke-node"
}

resource "google_project_iam_member" "gke_node" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_service_account" "ops" {
  account_id   = "retail-dr-ops"
  display_name = "retail-dr-ops"
}

resource "google_project_iam_member" "ops" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.ops.email}"
}
