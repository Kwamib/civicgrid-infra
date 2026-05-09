# Terraform and provider version constraints.
# Pinning prevents "works today, breaks tomorrow" provider behavior changes.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }

  # Remote state backend: Terraform Cloud
  # State stored encrypted, locked, and shared across workstations.
  cloud {
    organization = "kwamib"

    workspaces {
      name = "civicgrid-prod"
    }
  }
}
