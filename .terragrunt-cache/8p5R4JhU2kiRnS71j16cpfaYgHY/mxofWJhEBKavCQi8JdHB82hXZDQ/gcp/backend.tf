terraform {
  backend "gcs" {
    bucket = "kdt4-3-retail-dr-tfstate"
    prefix = "retail-store/gcp/dr"
  }
}
