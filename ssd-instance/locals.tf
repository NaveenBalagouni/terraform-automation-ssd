locals {
  # Dynamically finds the chart path relative to this module
  ssd_chart_path = abspath("${path.module}/../enterprise-ssd/charts/ssd")
}
