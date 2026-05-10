# Input variables.
# Sensitive values (tokens) are set in Terraform Cloud workspace variables.
# Non-sensitive values can be set via terraform.tfvars or env vars.

# ---------------------------------------------------------------------------
# Credentials (sensitive)
# ---------------------------------------------------------------------------

variable "do_token" {
  description = "DigitalOcean Personal Access Token with read+write scope"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permission for the domain zone"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain (find in Cloudflare dashboard, right sidebar)"
  type        = string
}

# ---------------------------------------------------------------------------
# Cluster configuration
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name for the DigitalOcean Kubernetes cluster"
  type        = string
  default     = "civicgrid-prod"
}

variable "region" {
  description = "DigitalOcean region for cluster and resources"
  type        = string
  default     = "nyc3"
}

variable "kubernetes_version" {
  description = "Kubernetes version. Use a slug like '1.31.1-do.0'. Find current options with: doctl kubernetes options versions"
  type        = string
  default     = "1.31.1-do.0"
}

variable "node_size" {
  description = "DigitalOcean droplet size for cluster nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# DNS configuration
# ---------------------------------------------------------------------------

variable "domain" {
  description = "Root domain (e.g. civicgrid.dev). Subdomains will be created under this."
  type        = string
}

variable "api_subdomain" {
  description = "Subdomain for the API. Final hostname will be {api_subdomain}.{domain}"
  type        = string
  default     = "api"
}

# ---------------------------------------------------------------------------
# GitOps configuration
# ---------------------------------------------------------------------------

variable "gitops_repo_url" {
  description = "URL of the gitops repository ArgoCD watches"
  type        = string
  default     = "https://github.com/Kwamib/civicgrid-gitops.git"
}

variable "gitops_target_revision" {
  description = "Git revision (branch, tag, or commit) for ArgoCD to track"
  type        = string
  default     = "main"
}

# ---------------------------------------------------------------------------
# Application secrets
# ---------------------------------------------------------------------------

variable "database_url" {
  description = "Postgres connection string for the civicgrid-api app. Set in Terraform Cloud workspace as sensitive."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Load Balancer IP
# ---------------------------------------------------------------------------

variable "lb_ip" {
  description = "DigitalOcean LoadBalancer IP for the Envoy Gateway. After first apply, get this from: kubectl get svc -n envoy-gateway-system. Set in Terraform Cloud workspace."
  type        = string
  default     = "1.2.3.4"
}
