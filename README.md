# civicgrid-infra

Terraform module that provisions production infrastructure for [CivicGrid](https://github.com/Kwamib/civicgrid-api), a SaaS API for US municipal data.

## What this provisions

- DigitalOcean Kubernetes cluster (DOKS, NYC3 region, configurable node sizing)
- Cloudflare DNS records for the API subdomain
- ArgoCD installed inside the cluster via Helm
- Bootstrap Application pointing ArgoCD at the civicgrid-gitops repo

After terraform apply completes, ArgoCD takes over and reconciles all subsequent state from the gitops repo: Envoy Gateway, cert-manager, the FastAPI service, observability stack, etc.

## Architecture

  terraform apply
    -> Provisions DOKS cluster (DigitalOcean)
    -> Creates DNS records (Cloudflare)
    -> Installs ArgoCD (Helm)
    -> Applies root Application manifest
         -> ArgoCD watches gitops repo
              -> Cluster reconciles to desired state
                 (Envoy Gateway, cert-manager, civicgrid-api,
                  kube-prometheus-stack, HTTPRoute, Gateway, ClusterIssuer)

## Prerequisites

- Terraform >= 1.5
- A DigitalOcean account with a Personal Access Token
- A Cloudflare account with a domain zone you control
- A Terraform Cloud account (free) for state storage

## Usage

  # 1. Authenticate to Terraform Cloud
  terraform login

  # 2. Initialize (downloads providers, configures backend)
  terraform init

  # 3. Set sensitive variables in Terraform Cloud workspace UI
  #    do_token, cloudflare_api_token, cloudflare_zone_id, domain

  # 4. Plan the changes
  terraform plan

  # 5. Apply
  terraform apply

After successful apply, ~10-15 minutes total:
- DOKS cluster: ~5-7 minutes
- ArgoCD install + bootstrap: ~2-3 minutes
- ArgoCD reconciliation of all gitops manifests: ~3-5 minutes

## Outputs

After apply:

  terraform output kubeconfig_command
  terraform output argocd_ui_command
  terraform output api_url

## Destroying

  terraform destroy

This removes the DOKS cluster, DNS records, and ArgoCD install. Application data in Supabase is unaffected (database lives outside this Terraform-managed scope).

## Documentation

See docs/runbook.md for common operational tasks.

## License

MIT
