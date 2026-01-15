resource "helm_release" "ssd_terraform" {
  name       = var.release_name
  namespace  = kubernetes_namespace_v1.ssd_ns.metadata[0].name
  chart      = local.ssd_chart_path
  
  wait       = true
  timeout    = 1800
  atomic     = true # Rollback on failure

  values = [
    file(var.values_file)
  ]

  depends_on = [kubernetes_namespace_v1.ssd_ns]
}
