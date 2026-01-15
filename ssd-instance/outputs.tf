output "namespace" {
  value = kubernetes_namespace_v1.ssd_ns.metadata[0].name
}

output "helm_release_status" {
  value = helm_release.ssd_terraform.status
}
