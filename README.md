# terraform-automation-ssd

This guide provides the complete code for each file in your `terraform-ssd/` folder structure, followed by a step-by-step process to automate this using **Spinnaker**.

---

## Part 1: Complete Terraform Code

This setup ensures that the **Kubernetes Namespace** is created first, and then the **Helm Release** uses that namespace to deploy the SSD instance.

### 1. Root Directory Files

**`terraform-ssd/providers.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config" # Change this for CI/CD environments
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

```

**`terraform-ssd/variables.tf`**

```hcl
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

```

**`terraform-ssd/main.tf`**

```hcl
module "ssd_instance" {
  source        = "./ssd-instance"
  ssd_namespace = var.target_namespace
  release_name  = var.ssd_release_name
  # Points to the values file inside the cloned repo
  values_file   = "${path.cwd}/enterprise-ssd/charts/ssd/ssd-minimal-values.yaml"
}

```

---

### 2. SSD Module Directory (`ssd-instance/`)

**`ssd-instance/variables.tf`**

```hcl
variable "ssd_namespace" { type = string }
variable "release_name"  { type = string }
variable "values_file"   { type = string }

```

**`ssd-instance/locals.tf`**

```hcl
locals {
  # Dynamically finds the chart path relative to this module
  ssd_chart_path = abspath("${path.module}/../enterprise-ssd/charts/ssd")
}

```

**`ssd-instance/main.tf`**

```hcl
resource "kubernetes_namespace_v1" "ssd_ns" {
  metadata {
    name = var.ssd_namespace
  }
}

```

**`ssd-instance/deploy.tf`**

```hcl
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

```

**`ssd-instance/outputs.tf`**

```hcl
output "namespace" {
  value = kubernetes_namespace_v1.ssd_ns.metadata[0].name
}

output "helm_release_status" {
  value = helm_release.ssd_terraform.status
}

```

---

## Part 2: Automating with Spinnaker

To automate this, Spinnaker acts as the "orchestrator" that pulls your code from Git and executes the Terraform commands.

### Step-by-Step Spinnaker Process

#### 1. Pre-requisites in Spinnaker

* **Artifact Account:** Configure a GitHub artifact account so Spinnaker can download your `terraform-ssd` repository.
* **Terraform Plugin:** Ensure your Spinnaker (or Armory) instance has the **Terraform Integration** enabled.

#### 2. Create the Pipeline

1. **Stage 1: Configuration (Trigger)**
* Set a **Git Trigger** to your repository.
* Add an **Expected Artifact** for the source code (the `.zip` or directory of your repo).


2. **Stage 2: Terraform Plan**
* **Type:** `Terraform`
* **Action:** `Plan`
* **Main Artifact:** Select your Git repo artifact.
* **Directory:** `terraform-ssd`
* **Produces Artifact:** Name it `planfile`.


3. **Stage 3: Manual Judgment (Safety)**
* **Type:** `Manual Judgment`
* This stops the pipeline and allows you to read the Terraform Plan output. You must click "Continue" to proceed.


4. **Stage 4: Terraform Apply**
* **Type:** `Terraform`
* **Action:** `Apply`
* **Main Artifact:** Your Git repo artifact.
* **Terraform Artifacts:** Select the `planfile` artifact produced in Stage 2.

