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




Step 5: Add Terraform Stage

This stage will run your Terraform automation (SSD namespace + Helm deployment).

Click Add Stage → Terraform (or Run Script if Terraform plugin not available)

Fill details:

Stage Name: Terraform Apply SSD

Module Source: Git URL of your repo (https://gitlab.com/<org>/terraform-demo.git)

Directory: / (root module)

Terraform Version: 1.5.0

Apply Variables:

ssd_namespace = "ssd-terraform"
release_name  = "opsmx-ssd-terraform"
values_file   = "/path/to/enterprise-ssd/charts/ssd/ssd-minimal-values.yaml"


Auto-Approve: true

This stage will create the namespace and deploy the SSD Helm release automatically.

Step 6: Add Artifact Stage (Optional Frontend)

If you want to deploy your frontend app:

Click Add Stage → Deploy (Manifest)

Configure Expected Artifact:

Account: opsmx_gitlab_artifact

File Path: manifests/frontend.yaml

Display Name: Frontend Manifest

If Missing: Use default artifact

Set Namespace: ssd-terraform

This stage deploys the frontend app after the SSD stage is done.

Step 7: (Optional) Add Manual Judgment / Policy Stage

If you want a review/approval step:

Add stage → Manual Judgment

Instructions: Review Terraform plan and SSD deployment

Assign approvers: team emails

Useful for production pipelines.

Step 8: Save and Run Pipeline

Click Save Pipeline

Trigger manually or push a change to Git to see it run automatically.

Step 9: Verify Deployment

After the pipeline completes:

kubectl get ns
kubectl get pods -n ssd-terraform
helm list -n ssd-terraform
kubectl get svc -n ssd-terraform


✅ You should see:

ssd-terraform namespace exists

OpsMx SSD Helm release deployed

Frontend service running

Step 10: Next Optional Enhancements

Add Rollback Stage if Terraform fails

Add Notifications (Slack, Email)

Add Automated Verification using kubectl or Helm commands as a Spinnaker stage

4. **Stage 4: Terraform Apply**
* **Type:** `Terraform`
* **Action:** `Apply`
* **Main Artifact:** Your Git repo artifact.
* **Terraform Artifacts:** Select the `planfile` artifact produced in Stage 2.

tep 2: Create the Pipeline

    Configuration Stage:

        Set up an Artifact Trigger: The pipeline starts whenever a new tag is pushed to the enterprise-ssd repo.

        Define two Expected Artifacts:

            The Helm Chart (Git Repo).

            The values.yaml file.

    Bake (Manifest) Stage:

        Render Engine: Select Helm3.

        Name: opsmx-ssd-deployment.

        Namespace: ssd-terraform.

        Input Artifact: Select your cloned Git repo.

        Overrides: Point to your ssd-minimal-values.yaml.

        This stage "renders" the Helm chart into a standard Kubernetes YAML manifest.

    Deploy (Manifest) Stage:

        Account: Select your K8s cluster.

        Manifest Source: Select the output from the "Bake" stage.

        Namespace: ssd-terraform (Spinnaker will create this if configured, or use a "Produce Output" stage).

Step 3: Execution

    When you push code to GitHub, Spinnaker detects it.

    It downloads the Helm chart.

    It injects the values.yaml.

    It runs kubectl apply logic and monitors the rollout.
