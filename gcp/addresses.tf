# Used by a GKE external Ingress; the Ingress controller creates the load balancer.
resource "google_compute_global_address" "ingress" {
  project      = var.project_id
  name         = "${var.name}-ingress-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  depends_on = [google_project_service.required]
}