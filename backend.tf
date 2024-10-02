terraform {
  backend "gcs" {
    bucket  = "cloudbuildbucket"
    prefix  = "terraform/state"
  }
}
