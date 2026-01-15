module "ssd_instance" {
  source        = "./ssd-instance"
  ssd_namespace = "ssd-terraform"
  release_name  = "opsmx-ssd-terraform"

  values_file = "${path.cwd}/enterprise-ssd/charts/ssd/ssd-minimal-values.yaml"
}
