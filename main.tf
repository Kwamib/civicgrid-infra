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
# Uses the argocd-apps Helm chart, which is purpose-built for installing
# Application/AppProject manifests. This avoids the kubernetes_manifest
# resource's planning limitation (it requires a live cluster to plan against).
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
      applications = [
        {
          name      = "civicgrid-root"
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
      ]
    })
  ]

  depends_on = [helm_release.argocd]
}
