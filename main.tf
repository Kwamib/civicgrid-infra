# Main infrastructure resources.

# ---------------------------------------------------------------------------
# DigitalOcean Kubernetes cluster
# ---------------------------------------------------------------------------

resource "digitalocean_kubernetes_cluster" "civicgrid" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version

  auto_upgrade  = false
  surge_upgrade = true

  node_pool {
    name       = "default"
    size       = var.node_size
    node_count = var.node_count

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

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = var.api_subdomain
  type    = "A"
  content = "1.2.3.4"
  proxied = true
  ttl     = 1
  comment = "civicgrid-api — managed by Terraform"
}

# ---------------------------------------------------------------------------
# Pre-create civicgrid namespace and database Secret BEFORE ArgoCD reconciles.
# This eliminates the race condition where civicgrid-api tries to deploy
# before the Secret exists, causing CrashLoopBackOff and "Missing" status.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "civicgrid" {
  metadata {
    name = "civicgrid"
  }

  depends_on = [digitalocean_kubernetes_cluster.civicgrid]
}

resource "kubernetes_secret" "civicgrid_database" {
  metadata {
    name      = "civicgrid-database"
    namespace = kubernetes_namespace.civicgrid.metadata[0].name
  }

  type = "Opaque"

  data = {
    DATABASE_URL = var.database_url
  }
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
  version    = "7.7.5"

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      dex = {
        enabled = false
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
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
# ArgoCD root Application — bootstraps the gitops repo
#
# argocd-apps chart at v2.0.2 expects 'applications' as a map keyed by name,
# not a list of objects with a 'name' field.
# ---------------------------------------------------------------------------

resource "helm_release" "civicgrid_root_app" {
  name       = "civicgrid-root"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.2"

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      applications = {
        "civicgrid-root" = {
          namespace = "argocd"
          project   = "default"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
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
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.civicgrid_database
  ]
}
