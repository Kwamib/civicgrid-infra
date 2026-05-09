# Outputs after a successful apply.

output "cluster_id" {
  description = "DigitalOcean cluster ID"
  value       = digitalocean_kubernetes_cluster.civicgrid.id
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = digitalocean_kubernetes_cluster.civicgrid.endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "Cluster name (use with doctl to fetch kubeconfig)"
  value       = digitalocean_kubernetes_cluster.civicgrid.name
}

output "kubeconfig_command" {
  description = "Command to add cluster to local kubeconfig"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.civicgrid.name}"
}

output "argocd_admin_password_command" {
  description = "Command to retrieve initial ArgoCD admin password from cluster"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_ui_command" {
  description = "Command to access ArgoCD UI via local port-forward"
  value       = "kubectl port-forward -n argocd svc/argocd-server 8080:443"
}

output "api_url" {
  description = "Public URL where the CivicGrid API will be reachable (after DNS + Gateway are up)"
  value       = "https://${var.api_subdomain}.${var.domain}"
}
