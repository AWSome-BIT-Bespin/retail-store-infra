# 2026-09-18 GCP console snapshot. Import the existing resources first.
resource "google_compute_network" "retail" {
  name                    = "retail-dr-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_subnetwork" "gke" {
  name                     = "retail-dr-gke-subnet"
  region                   = "asia-northeast3"
  network                  = google_compute_network.retail.id
  ip_cidr_range            = "10.20.0.0/20"
  stack_type               = "IPV4_ONLY"
  private_ip_google_access = true

  # Existing GKE-created range. This is the range the current cluster uses.
  secondary_ip_range {
    range_name              = "gke-retail-dr-gke-pods-89de90ed"
    ip_cidr_range           = "10.90.0.0/17"
    reserved_internal_range = "networkconnectivity.googleapis.com/projects/kdt4-3/locations/global/internalRanges/gke-retail-dr-gke-pods-89de90ed"
  }

  # These two ranges exist but are not used by the current cluster.
  secondary_ip_range {
    range_name    = "retail-dr-pods"
    ip_cidr_range = "10.24.0.0/16"
  }

  secondary_ip_range {
    range_name    = "retail-dr-services"
    ip_cidr_range = "10.25.0.0/20"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_router" "nat" {
  name    = "retail-dr-router-real"
  region  = "asia-northeast3"
  network = google_compute_network.retail.id
}

resource "google_compute_router_nat" "retail" {
  name                                = "retail-dr-nat"
  region                              = "asia-northeast3"
  router                              = google_compute_router.nat.name
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "LIST_OF_SUBNETWORKS"
  enable_dynamic_port_allocation      = false
  enable_endpoint_independent_mapping = false

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
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
