# 2026-09-18 GCP console snapshot. Import the existing resources first.
resource "google_compute_network" "retail" {
  name                    = "retail-dr-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_subnetwork" "gke" {
  name                     = "retail-dr-gke-subnet"
  region                   = var.region
  network                  = google_compute_network.retail.id
  ip_cidr_range            = var.gke_subnet_cidr
  stack_type               = "IPV4_ONLY"
  private_ip_google_access = true

  # Existing GKE-created range. This is the range the current cluster uses.
  secondary_ip_range {
    range_name              = var.gke_pod_range_name
    ip_cidr_range           = var.gke_pod_cidr
    reserved_internal_range = "networkconnectivity.googleapis.com/projects/${var.project_id}/locations/global/internalRanges/${var.gke_pod_range_name}"
  }



  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_router" "nat" {
  name    = "retail-dr-router-real"
  region  = var.region
  network = google_compute_network.retail.id
}

resource "google_compute_router_nat" "retail" {
  name                                = "retail-dr-nat"
  region                              = var.region
  router                              = google_compute_router.nat.name
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "LIST_OF_SUBNETWORKS"
  enable_dynamic_port_allocation      = false
  enable_endpoint_independent_mapping = false

  subnetwork {
    name = google_compute_subnetwork.gke.id

    source_ip_ranges_to_nat = [
      "PRIMARY_IP_RANGE",
      "LIST_OF_SECONDARY_IP_RANGES",
    ]

    secondary_ip_range_names = [
      var.gke_pod_range_name,
    ]
  }

  log_config {
    enable = false
    filter = "ALL"
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.retail.id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.235.240.0/20"]

  # Current rule applies to every VM in this VPC.
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "bastion_ssh_existing" {
  name      = "allow-iap-ssh-bastion"
  network   = google_compute_network.retail.id
  direction = "INGRESS"
  priority  = 1000

  # Exact existing configuration; this is NOT limited to IAP despite its name.
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["retail-dr-bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
