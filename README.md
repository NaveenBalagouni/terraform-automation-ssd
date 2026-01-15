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



    Absolutely! Let’s go **step by step** and break down exactly how to create a **Spinnaker pipeline** for your use case (Terraform SSD instance setup → SaaS profile configuration → cluster onboarding → demo validation). I’ll make it clear and structured.

---

## **Step-by-Step: Creating a Spinnaker Pipeline**

### **Step 0: Prerequisites**

Before creating the pipeline:

1. Ensure **Spinnaker is installed** and accessible (DemoSpinnaker environment in your case).
2. Make sure **Terraform is installed** and accessible from wherever Spinnaker can call it (either via a script stage or a Terraform provider).
3. Have **cloud credentials** configured (AWS, GCP, or Azure) in Spinnaker.
4. Have a **SaaS profile configuration script** ready.

---

### **Step 1: Create a New Pipeline**

1. Open Spinnaker UI → Navigate to your application → **Pipelines → + Create**.
2. Give the pipeline a **name** (e.g., `SSD_Cluster_Onboard_Pipeline`).
3. Optional: Add **description** for the demo.

---

### **Step 2: Add Trigger (Optional but Recommended)**

* Trigger can be:

  * **Manual trigger** → start pipeline manually.
  * **Git trigger** → if Terraform code is stored in Git, pipeline auto-triggers on commit.
  * **Webhook trigger** → trigger from external CI/CD tool.
* Example: Set manual trigger for demo first.

---

### **Step 3: Stage 1 — Terraform Init & Apply**

* **Stage Type:** Run Job / Script / Terraform Bake (if Terraform provider enabled)

* **Purpose:** Provision SSD instance(s)

* **Steps:**

  1. **Script Stage** (simplest):

     ```bash
     cd /path/to/terraform/code
     terraform init
     terraform plan -out=tfplan
     terraform apply -auto-approve tfplan
     ```
  2. **Terraform Bake Stage** (if provider enabled):

     * Point to your Terraform module or script.
     * Bake produces artifacts to deploy in next stage.

* **Output Handling:** Capture Terraform outputs (instance IDs, IPs) to use in the next stage.

* **Wait for Completion:** Spinnaker waits for this stage to finish before moving on.

---

### **Step 4: Stage 2 — Wait / Verification (Optional)**

* **Stage Type:** Manual Judgment or Wait
* **Purpose:** Ensure instance is ready before onboarding cluster.
* Set wait time (e.g., 30–60 seconds) or verify via script:

  ```bash
  aws ec2 describe-instances --instance-ids <ID> --query 'Reservations[*].Instances[*].State.Name'
  ```
* Only proceed if instance status is `running`.

---

### **Step 5: Stage 3 — SaaS Profile Configuration**

* **Stage Type:** Script / Run Job
* **Purpose:** Configure SaaS profile on SSD instance(s)
* Example script:

  ```bash
  ssh -i key.pem ec2-user@<instance-ip> "bash -s" < configure_saas.sh
  ```
* **Optional:** Use Ansible or cloud-init scripts for automated configuration.

---

### **Step 6: Stage 4 — Cluster Onboarding**

* **Stage Type:** Script / Kubernetes (if cluster) / Webhook
* **Purpose:** Register new instance/cluster in Spinnaker Demo environment
* Examples:

  * Kubernetes cluster:

    ```bash
    kubectl config set-context new-cluster --cluster=<cluster> --user=<user>
    ```

    Add account in Spinnaker `kubernetes` provider config.
  * VM/ECS:

    * Add instance as server group via API call or Spinnaker CLI (`hal` command for configuration).

---

### **Step 7: Stage 5 — Validation / Smoke Test**

* **Stage Type:** Script / Manual Judgment
* **Purpose:** Ensure deployment works in demo cluster
* Examples:

  * Run a test deployment (sample app).
  * Check instance health via script:

    ```bash
    curl http://<instance-ip>:8080/health
    ```
* Optional: Add **notifications** to Slack/Email on success/failure.

---

### **Step 8: Notifications (Optional but Recommended)**

* Configure **Notifications stage**:

  * Slack, Email, or webhook to notify team about pipeline status.
* Good for demo so you can track success of SSD instance setup and cluster onboarding.

---

### **Step 9: Save and Execute Pipeline**

1. Click **Save Changes**.
2. Trigger pipeline manually to test the automation.
3. Observe each stage:

   * Terraform provisioning
   * SaaS profile setup
   * Cluster onboarding
   * Smoke test / validation

---

### **Step 10: Iterate and Refine**

* Add **error handling**:

  * Retry stages on failure.
  * Conditional execution (only proceed if previous stage succeeded).
* Parameterize pipeline:

  * Allow region, instance size, or SaaS profile as runtime parameters.
* Once stable, integrate with Git/webhook for full CI/CD automation.

---

✅ **Result:**
You now have a **Spinnaker pipeline** that:

1. Provisions SSD instances using Terraform.
2. Configures SaaS profiles.
3. Onboards the cluster to DemoSpinnaker.
4. Validates the setup with optional smoke tests.



Perfect! Here’s a **complete, clear naming scheme for all stages** in your Spinnaker pipeline, aligned with the flow we discussed:

| **Stage #** | **Stage Name**                   | **Purpose / Notes**                                       | **Spinnaker Stage Type**              |
| ----------- | -------------------------------- | --------------------------------------------------------- | ------------------------------------- |
| 1           | **Terraform SSD Provisioning**   | Provision SSD instance(s) using Terraform                 | Run Job / Script / Terraform Bake     |
| 2           | **Wait / Instance Verification** | Ensure SSD instance is running before onboarding          | Wait / Manual Judgment / Script       |
| 3           | **SaaS Profile Configuration**   | Configure SaaS profile on the provisioned instance(s)     | Run Job / Script                      |
| 4           | **Cluster Onboarding**           | Register instance/cluster in DemoSpinnaker environment    | Script / Kubernetes / Webhook         |
| 5           | **Validation / Smoke Test**      | Confirm deployment works; run health checks or sample app | Script / Manual Judgment              |
| 6           | **Notifications**                | Alert team on pipeline success or failure                 | Notifications (Slack, Email, Webhook) |

✅ Notes:

* These names are **descriptive and demo-friendly**, so anyone looking at the pipeline immediately knows what each stage does.
* You can also **add parameters** in stage names, like `<Region>` or `<Instance Name>`, if you want it dynamic in runtime.

If you like, I can now **draw a full visual diagram** using these exact stage names with arrows showing the flow—it’ll look like a polished pipeline chart ready for presentation.

Do you want me to make that diagram next?


---

I can also **draw a visual diagram of this pipeline** with all stages and flow arrows — makes it much easier to present in a demo.

Do you want me to create that visual pipeline diagram?

