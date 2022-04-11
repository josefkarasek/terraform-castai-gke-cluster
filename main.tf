resource "castai_gke_cluster" "castai_cluster" {
  project_id                 = var.project_id
  region                     = var.gke_cluster_region
  name                       = var.gke_cluster_name
  ssh_public_key             = var.ssh_public_key
  delete_nodes_on_disconnect = var.delete_nodes_on_disconnect
  credentials_json           = var.gke_credentials
}

resource "helm_release" "castai_agent" {
  name            = "castai-agent"
  repository      = "https://castai.github.io/helm-charts"
  chart           = "castai-agent"
  namespace       = "castai-agent"
  create_namespace = true
  cleanup_on_fail = true

  set {
    name  = "provider"
    value = "gke"
  }

  set {
    name = "createNamespace"
    value = "false"
  }

  dynamic "set" {
    for_each = var.api_url != "" ? [var.api_url] : []
    content {
      name  = "apiURL"
      value = var.api_url
    }
  }

  set_sensitive {
    name  = "apiKey"
    value = castai_gke_cluster.castai_cluster.cluster_token
  }
}

resource "helm_release" "castai_cluster_controller" {
  name            = "cluster-controller"
  repository      = "https://castai.github.io/helm-charts"
  chart           = "castai-cluster-controller"
  namespace       = "castai-agent"
  create_namespace = true
  cleanup_on_fail = true

  set {
    name  = "castai.clusterID"
    value = castai_gke_cluster.castai_cluster.id
  }

  dynamic "set" {
    for_each = var.api_url != "" ? [var.api_url] : []
    content {
      name  = "castai.apiURL"
      value = var.api_url
    }
  }

  set_sensitive {
    name  = "castai.apiKey"
    value = castai_gke_cluster.castai_cluster.cluster_token
  }

  depends_on = [helm_release.castai_agent]
}

resource "castai_autoscaler" "castai_autoscaler_policies" {
  autoscaler_policies_json = var.autoscaler_policies_json
  cluster_id               = castai_gke_cluster.castai_cluster.id

  depends_on = [helm_release.castai_agent]
}