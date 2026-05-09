# civicgrid-infra runbook

Common operational tasks for the CivicGrid infrastructure.

## First-time setup

1. Sign in to Terraform Cloud at app.terraform.io
2. Workspace kwamib/civicgrid-prod will be created on first terraform init
3. Set workspace variables (Variables tab in Terraform Cloud):
   - do_token: DigitalOcean Personal Access Token (mark as sensitive)
   - cloudflare_api_token: Cloudflare API token with Zone DNS edit (sensitive)
   - cloudflare_zone_id: Cloudflare Zone ID for your domain
   - domain: root domain (e.g. civicgrid.dev)

## Running terraform locally

  terraform login    (one-time, authenticates to Terraform Cloud)
  terraform init     (download providers, link to remote state)
  terraform plan     (preview changes)
  terraform apply    (apply changes)

State is stored in Terraform Cloud, not locally. Multiple operators or
workstations can run terraform safely (state locking is automatic).

## Updating the cluster's Kubernetes version

1. Find current options:
     doctl kubernetes options versions
2. Update kubernetes_version in Terraform Cloud workspace variables
3. terraform plan and terraform apply

DigitalOcean handles the rolling upgrade. With surge_upgrade = true,
no downtime expected for stateless workloads.

## Updating the ArgoCD bootstrap Application

If you change the gitops repo URL or branch:

1. Update gitops_repo_url or gitops_target_revision in workspace variables
2. terraform apply

## After first apply: pointing DNS at the load balancer

The Cloudflare A record is initialized with placeholder IP 1.2.3.4 because
the actual LoadBalancer IP doesn't exist until ArgoCD installs Envoy Gateway.
After first apply, get the actual LB IP and update the Cloudflare record:

  kubectl get svc -n envoy-gateway-system | grep envoy-civicgrid

Future improvement: refactor to use data "kubernetes_service" to auto-discover
the LB IP after Envoy Gateway is provisioned, then re-apply.

## Disaster recovery: rebuilding from scratch

  terraform destroy
  (wait ~5 minutes for DigitalOcean to fully deprovision)
  terraform apply

Total time to fully restored: ~15-20 minutes. The Supabase database is
outside this scope, so application data persists across rebuilds.

## Troubleshooting

terraform init fails with 401 Unauthorized
  Run: terraform login (refreshes Terraform Cloud token)

Provider fails with 401 on DigitalOcean
  The do_token value is invalid or expired. Generate a new one in
  DigitalOcean console: Account -> API -> Generate New Token.

ArgoCD root Application stays OutOfSync
  Most common cause: the directory.include glob doesn't match the gitops
  repo layout. Verify with:
    kubectl describe application civicgrid-root -n argocd

Cluster apply takes longer than 10 minutes
  DigitalOcean provisioning is occasionally slow. Watch progress with:
    doctl kubernetes cluster get civicgrid-prod
  If stuck >20 minutes, contact DigitalOcean support.
