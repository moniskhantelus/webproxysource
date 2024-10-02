terraform {
  required_version = ">= 1.9.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.37.0, < 6.0.0" 
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.37.0, < 6.0.0" 
    }
  }
}
