variable "target_namespace" {
  type        = string
  default     = "ssd-terraform"
  description = "Namespace where SSD will be deployed"
}

variable "ssd_release_name" {
  type        = string
  default     = "opsmx-ssd"
  description = "Helm release name"
}
