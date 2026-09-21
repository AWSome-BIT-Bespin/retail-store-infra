terraform {
  backend "s3" {
    bucket       = "retail-terraform-state-350606136784-ap-northeast-2-an"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}