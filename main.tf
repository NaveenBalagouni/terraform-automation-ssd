module "ssd_instance" {
  source        = "./ssd-instance"
  ssd_namespace = var.target_namespace
  release_name  = var.ssd_release_name
  # Points to the values file inside the cloned repo
  values_file   = "${path.cwd}/enterprise-ssd/charts/ssd/ssd-minimal-values.yaml"
}
