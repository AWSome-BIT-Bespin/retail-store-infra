resource "google_compute_instance" "bastion" {
  name                = "retail-dr-bastion"
  zone                = "asia-northeast3-a"
  machine_type        = "e2-medium"
  deletion_protection = false
  key_revocation_action_type = "NONE"

  # Exact current spelling. See README before correcting this tag.
  tags = ["retail-dr-basion"]
  labels = {
    "goog-ops-agent-policy" = "v2-template-1-7-0"
  }

  boot_disk {
    auto_delete = true
    device_name = "retail-dr-bastion"
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-13-trixie-v20260908"
      type  = "pd-balanced"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gke.id
    stack_type = "IPV4_ONLY"
    # No access_config: no external IP.
  }

  service_account {
    email  = google_service_account.ops.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    "enable-osconfig" = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    provisioning_model  = "STANDARD"
    preemptible         = false
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  depends_on = [google_project_iam_member.ops]

  lifecycle {
    prevent_destroy = true
    # Console browser-SSH writes short-lived public keys to this single key.
    ignore_changes = [metadata["ssh-keys"]]
  }
}

# This policy is shared with code-server. Read it without taking ownership.
data "google_compute_resource_policy" "shared_snapshot" {
  name   = "default-schedule-1"
  region = "asia-northeast3"
}

resource "google_compute_disk_resource_policy_attachment" "bastion" {
  name = data.google_compute_resource_policy.shared_snapshot.name
  disk = google_compute_instance.bastion.name
  zone = "asia-northeast3-a"
}
