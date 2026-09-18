resource "google_compute_global_address" "private_services" {
  name          = "google-managed-services-retail-dr-vpc"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  address       = "10.40.0.0"
  prefix_length = 16
  network       = google_compute_network.retail.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.retail.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_network_peering_routes_config" "private_services" {
  network                             = google_compute_network.retail.name
  peering                             = google_service_networking_connection.private_services.peering
  import_custom_routes                = true
  export_custom_routes                = true
  import_subnet_routes_with_public_ip = false
  export_subnet_routes_with_public_ip = false
}
