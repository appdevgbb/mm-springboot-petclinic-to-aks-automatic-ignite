## Deploying the solution to Azure

In this module, you will create all required Azure resources using Bicep templates and learn about Azure resource management, PostgreSQL Flexible Server, AKS Automatic, and workload identity concepts.

**What You'll Do:** Deploy Azure infrastructure using Bicep templates to support the Petclinic application.

**What You'll Learn:** Azure Bicep deployment, AKS Automatic, PostgreSQL Flexible Server with Entra ID, and Service Linkers.

AKS Automatic is a great landing zone to migrate and modernize legacy workloads because it simplifies by default: AKS manages node provisioning and scaling, applies hardened security baselines, enables Azure RBAC and workload identity, and integrates application routing (managed NGINX) and observability out of the box letting teams focus on the app, not managing the cluster.

Modernizing legacy workloads pairs naturally with Azure PaaS: replace the simulated on‑prem PostgreSQL with Azure Database for PostgreSQL Flexible Server using Microsoft Entra authentication for passwordless access from AKS, and use AKS Service Connector to generate the Kubernetes wiring and secrets that connect and authenticate the app to Postgres automatically.

See the AKS Automatic overview and engineering deep dive for details, and service docs for Entra-enabled Postgres and Service Connector: [AKS Automatic intro](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic), [AKS Automatic engineering blog](https://blog.aks.azure.com/2024/05/22/aks-automatic).

**Detailed Steps:**

### Step 1: Open Terminal in VS Code

If you haven't already, open a new terminal in VS Code:
- Press ``Ctrl+` `` (backtick) on Windows/Linux or ``Cmd+` `` on macOS.
- Or go to **Terminal** → **New Terminal** in the menu.
- Or use the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and search for "Terminal: Create New Terminal".

### Step 2: Navigate to Infrastructure Directory
```bash
cd infra
```

### Step 3: Verify Prerequisites

```bash
# Check Azure CLI is installed and you're logged in
az account show

# If not logged in, run:
az login
```

### Step 4: Review Bicep Configuration

```bash
# View the main Bicep template
cat main.bicep

# View the parameters file
cat parameters.json

# View the resources template
cat resources.bicep
```

### Step 5: Deploy Azure Infrastructure

```bash
# Make the deployment script executable
chmod +x setup-azure-infra.sh

# Run the deployment in the background (this will take 30 minutes)
./setup-azure-infra.sh > deployment.log 2>&1 &
```

To deploy the Azure infrastructure using the provided ARM template:

```bash
# Configuration variables
RESOURCE_GROUP_NAME="petclinic-workshop-rg"
LOCATION="westus3"
DEPLOYMENT_NAME="aks-arm-deployment-$(date +%Y%m%d-%H%M%S)"
PARAMETERS_FILE="parameters.json"

# Get current user info
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
CURRENT_USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")

# Deploy using variables
az deployment sub create \
  --location "$LOCATION" \
  --name "$DEPLOYMENT_NAME" \
  --template-file main.json \
  --parameters @$PARAMETERS_FILE \
  --parameters resourceGroupName="$RESOURCE_GROUP_NAME" \
  --parameters location="$LOCATION" \
  --parameters azureADObjectId="$CURRENT_USER_ID" \
  --parameters azureADUserPrincipalName="$CURRENT_USER_UPN" \
  --parameters userAssignedIdentityName="petclinic-app-uami" \
  --parameters acrName="petclinicacr" \
  --output table > deployment.log 2>&1 &
```

> **Note:** The Azure infrastructure deployment is now running in the background and will take approximately 30 minutes to complete. You can follow the deployment progress by looking at the `deployment.log` file (e.g.: `tail deployment.log`).
>
> While it's deploying, you will continue with Module 2 to set up the PetClinic application locally and begin the modernization work.

**What this script creates in Azure:**

- Resource group: `petclinic-workshop-rg`.
- AKS Automatic cluster with system-assigned managed identity.
- Azure PostgreSQL Flexible Server with Entra ID authentication.
- Log Analytics Workspace for AKS monitoring.
- Service Connectors for secure AKS to Postgres connection and authentication using AKS workload identity.
- User Assigned Managed Identity for application authentication.

