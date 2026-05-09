# Provider configurations.
# Credentials come from variables (set via Terraform Cloud workspace variables).
# Never commit actual token values — they're sensitive.

provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Kubernetes and Helm providers configured AFTER the cluster exists.
# We use the kubeconfig output from the digitalocean_kubernetes_cluster resource
# to populate these provider configs at apply time.

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.civicgrid.endpoint
  token                  = digitalocean_kubernetes_cluster.civicgrid.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.civicgrid.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.civicgrid.endpoint
    token                  = digitalocean_kubernetes_cluster.civicgrid.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.civicgrid.kube_config[0].cluster_ca_certificate)
  }
}
