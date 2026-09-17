resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "${var.name} GKE nodes"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}