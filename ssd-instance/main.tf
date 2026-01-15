resource "kubernetes_namespace_v1" "ssd_ns" {
  metadata {
    name = var.ssd_namespace
  }
}
