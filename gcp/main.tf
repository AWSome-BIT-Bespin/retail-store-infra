locals {
  services = toset(concat([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ], var.create_bastion ? ["iap.googleapis.com", "oslogin.googleapis.com"] : []))
}

resource "google_project_service" "required" {
  for_each = local.services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "./modules/network"

  project_id = var.project_id
  region     = var.region
  name       = var.name
  cidrs      = var.network_cidrs

  depends_on = [google_project_service.required]
}

module "iam" {
  source = "./modules/iam"

  project_id = var.project_id
  name       = var.name

  depends_on = [google_project_service.required]
}

module "gke" {
  source = "./modules/gke"

  project_id            = var.project_id
  region                = var.region
  name                  = var.name
  node_zones            = var.node_zones
  network_id            = module.network.network_id
  subnetwork_id         = module.network.subnetwork_id
  pod_range_name        = module.network.pod_range_name
  service_range_name    = module.network.service_range_name
  cidrs                 = var.network_cidrs
  admin_cidrs           = var.admin_cidrs
  private_endpoint_only = var.private_endpoint_only
  node_service_account  = module.iam.node_service_account
  node_machine_type     = var.node_machine_type
  node_limits           = var.node_limits

  depends_on = [module.iam, module.network]
}

module "bastion" {
  count  = var.create_bastion ? 1 : 0
  source = "./modules/bastion"

  project_id    = var.project_id
  name          = var.name
  zone          = var.node_zones[0]
  network_id    = module.network.network_id
  subnetwork_id = module.network.subnetwork_id
  project_roles = var.bastion_project_roles

  depends_on = [module.network, google_project_service.required]
}