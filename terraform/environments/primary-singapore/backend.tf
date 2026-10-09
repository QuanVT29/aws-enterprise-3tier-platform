terraform {
  backend "s3" {
    bucket         = "enterprise-tf-state-222634368199-ap-southeast-1"
    key            = "primary-singapore/terraform.tfstate"
    region         = "ap-southeast-1"
    use_lockfile   = true
    encrypt        = true
  }
}