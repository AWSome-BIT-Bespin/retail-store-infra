
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = "${var.name}-ops"
  display_name = "${var.name} management VM"
}

resource "google_project_iam_member" "this" {
  for_each = var.project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_compute_firewall" "iap_ssh" {
  project       = var.project_id
  name          = "${var.name}-iap-ssh"
  network       = var.network_id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.name}-ops"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "this" {
  project      = var.project_id
  name         = "${var.name}-ops"
  zone         = var.zone
  machine_type = "e2-small"
  tags         = ["${var.name}-ops"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      type  = "pd-balanced"
      size  = 20
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id
    # No access_config: the VM has no external IP.
  }

  service_account {
    email = google_service_account.this.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/userinfo.email",
    ]
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  shielded_instance_config {
    enable_secure_boot          = true
    enable_integrity_monitoring = true
  }

  depends_on = [google_project_iam_member.this, google_compute_firewall.iap_ssh]
}