terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.3.0"
    }
  }
}

provider "google" {
  project = "kdt4-3"
  region  = "asia-northeast3"
  zone    = "asia-northeast3-a"

  # Import existing resources without introducing a Terraform attribution label.
  add_terraform_attribution_label = false
}
