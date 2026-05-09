# Main infrastructure resources.

# ---------------------------------------------------------------------------
# DigitalOcean Kubernetes cluster
# ---------------------------------------------------------------------------

resource "digitalocean_kubernetes_cluster" "civicgrid" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version

  # Disable auto-upgrade — we want explicit control over upgrades for stability
  auto_upgrade = false

  # Surge upgrade allows rolling node replacement without downtime when we DO upgrade
  surge_upgrade = true

  node_pool {
    name       = "default"
    size       = var.node_size
    node_count = var.node_count

    # Labels useful for node selection / monitoring later
    labels = {
      environment = "prod"
      project     = "civicgrid"
    }
  }

  tags = ["civicgrid", "prod"]
}

# ---------------------------------------------------------------------------
# Cloudflare DNS records
# ---------------------------------------------------------------------------

# Resolve api.{domain} to the LoadBalancer IP that Envoy Gateway will provision
# inside the cluster. We use a CNAME placeholder initially because the LB IP
# doesn't exist until ArgoCD has installed Envoy Gateway and the Gateway resource.
#
# After first apply, you'll need to:
# 1. Wait for Envoy Gateway + Gateway resource to come up
# 2. Get the LB IP: kubectl get svc -n envoy-gateway-system | grep envoy
# 3. Update this resource to point at that IP, or use a script to automate

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = var.api_subdomain
  type    = "A"
  # Placeholder — will be updated after first apply with real LB IP.
  # Cloudflare proxy enabled (orange cloud) for DDoS protection + caching.
  content = "1.2.3.4"
  proxied = true
  ttl     = 1 # 1 = automatic when proxied
  comment = "civicgrid-api — managed by Terraform"
}

# ---------------------------------------------------------------------------
# ArgoCD installation via Helm
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [digitalocean_kubernetes_cluster.civicgrid]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.5" # pin for reproducibility

  # Wait until ArgoCD is fully ready before considering this resource done
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      # Disable Dex (we're not using SSO yet)
      dex = {
        enabled = false
      }

      # Server config: keep insecure mode off, ArgoCD UI accessed via port-forward initially
      server = {
        # No public ingress for the ArgoCD UI yet — access via kubectl port-forward.
        # Future: add Gateway/HTTPRoute managed via gitops once we have proper auth set up.
        service = {
          type = "ClusterIP"
        }
      }

      # Reduce resource requests for cost-conscious cluster
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }
      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ---------------------------------------------------------------------------
# Bootstrap: tell ArgoCD to watch the gitops repo
# ---------------------------------------------------------------------------

# This is the "root" Application that points ArgoCD at the gitops repo.
# Once applied, ArgoCD discovers and reconciles all the other Applications
# defined under apps/ and infra/ in the gitops repo.

resource "kubernetes_manifest" "civicgrid_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "civicgrid-root"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"

      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = "."
        directory = {
          recurse = true
          include = "{apps,infra}/**/application.yaml"
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ServerSideApply=true"
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
