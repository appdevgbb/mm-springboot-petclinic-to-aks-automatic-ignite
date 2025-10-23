---
title: Migrate to AKS Automatic with GitHub Copilot for App Modernization
---

import Prerequisites from "../../src/components/SharedMarkdown/_prerequisites.mdx";
import ProvisionResourceGroup from "../../src/components/SharedMarkdown/_provision_resource_group.mdx";
import Cleanup from "../../src/components/SharedMarkdown/_cleanup.mdx";

This workshop demonstrates how to migrate and modernize the iconic **Spring Boot PetClinic** application from local execution to **Azure AKS Automatic**. You'll experience the complete modernization journey using AI-powered tools such as **GitHub Copilot app modernization** and **Containerization Assist MCP Server**.

## Objectives

By the end of this workshop, you will be able to:

- Run [Spring Boot PetClinic](https://github.com/spring-projects/spring-petclinic) locally with PostgreSQL and basic authentication.
- Modernize the codebase using [GitHub Copilot app modernization](https://marketplace.visualstudio.com/items?itemName=vscjava.migrate-java-to-azure).
- Migrate the database to [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/) integrated with [Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/).
- Containerize the app using [Containerization Assist MCP Server](https://github.com/Azure/containerization-assiste).
- Deploy to [AKS Automatic](https://learn.microsoft.com/azure/aks/automatic/) using [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) and [Service Connector](https://learn.microsoft.com/en-us/azure/service-connector/).

<Prerequisites
  tools={[
    {
      name: "Azure CLI",
      url: "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli",
    },
    {
      name: "Java 17 or 21 (Microsoft OpenJDK)",
      url: "https://learn.microsoft.com/en-us/java/openjdk/download",
    },
    {
      name: "Maven 3.8+",
      url: "https://maven.apache.org/install.html",
    },
    {
      name: "Docker Desktop",
      url: "https://www.docker.com/",
    },
    {
      name: "Visual Studio Code with Java Extension Pack",
      url: "https://code.visualstudio.com/",
    },
    {
      name: "kubectl",
      url: "https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#install-the-azure-cli-and-kubernetes-cli",
    },
    {
      name: "Git",
      url: "https://git-scm.com/downloads",
    },
  ]}
/>

This workshop will need some Azure preview features enabled and resources to be pre-provisioned. You can use the Azure CLI commands below to register the preview features.

Register preview features.

```bash
az feature register --namespace Microsoft.ContainerService --name AutomaticSKUPreview
az feature register --namespace Microsoft.ContainerService --name AzureMonitorAppMonitoringPreview
```

Register resource providers.

```bash
az provider register --namespace Microsoft.DevHub
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.ServiceLinker
```

Check the status of the feature registration.

```bash
az feature show --namespace Microsoft.ContainerService --name AutomaticSKUPreview --query properties.state
```

Once the feature is registered, run the following command to re-register the Microsoft.ContainerService provider.

```bash
az provider register --namespace Microsoft.ContainerService
```

:::warning

As noted in the AKS Automatic [documentation](https://learn.microsoft.com/azure/aks/automatic/quick-automatic-managed-network?pivots=azure-portal), AKS Automatic tries to dynamically select a virtual machine size for the system node pool based on the capacity available in the subscription. Make sure your subscription has quota for 16 vCPUs of any of the following sizes in the region you're deploying the cluster to: [Standard_D4pds_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dpsv5-series), [Standard_D4lds_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dldsv5-series), [Standard_D4ads_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dadsv5-series), [Standard_D4ds_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddsv5-series), [Standard_D4d_v5](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddv5-series), [Standard_D4d_v4](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/ddv4-series), [Standard_DS3_v2](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/dsv3-series), [Standard_DS12_v2](https://learn.microsoft.com/azure/virtual-machines/sizes/memory-optimized/dv2-dsv2-series-memory). You can [view quotas for specific VM-families and submit quota increase requests](https://learn.microsoft.com/azure/quotas/per-vm-quota-requests) through the Azure portal.

:::

<ProvisionResourceGroup />

### Install the Service Connector

In a terminal, run the following command to install the service-connector:

```bash
az extension add --name serviceconnector-passwordless --upgrade

az aks connection create postgres-flexible \
--source-id ${AKS_CLUSTER_ID} \
--target-id ${POSTGRES_DATABASE_ID} \
--workload-identity ${USER_ASSIGNED_IDENTITY_ID} \
--client-type none \
--kube-namespace default
```

:::note

This command will take about 8 minutes to run. To make the most of your time on this lab, you can leave it running on this terminal until it finishes.
:::

### Configure Azure RBAC Authentication for kubectl

Before deploying to AKS, you need to configure kubectl to use Azure RBAC authentication.

In your terminal window, run the following commands:

```bash
# Add Admin role to your user
az role assignment create \
--assignee ${USER_EMAIL} \
--role "Azure Kubernetes Service RBAC Cluster Admin" \
--scope ${AKS_CLUSTER_ID}

# Get AKS credentials (this downloads the kubeconfig)
az aks get-credentials \
--resource-group ${RESOURCE_GROUP_NAME} \
--name ${AKS_CLUSTER_NAME}

# Configure kubectl to use Azure RBAC authentication
kubelogin convert-kubeconfig --login azurecli

# Test AKS access
kubectl get pods
```

:::note

The `kubelogin convert-kubeconfig --login azurecli` command configures kubectl to use Entra (Azure AD) authentication with the Azure RBAC roles assigned to your user account. This is required for AKS Automatic clusters with Azure RBAC enabled.

:::

### Authenticate GitHub Copilot

To use GitHub Copilot, sign in with the GitHub account provided in your lab environment.

1. In Edge, open the GitHub SSO URL.

2. Click on **Continue**.

   ![GitHub Continue Button](assets/migrate-to-aks-automatic/github-continue-button.png)

3. Log in with the credentials listed in the **Resources** tab.

### Sign In to VS Code with GitHub

After signing in to GitHub, open VS Code and complete the Copilot setup:

In your terminal, run the following command to launch a new VS Code instance into the `spring-petclinic` source directory:

```bash
cd ~/spring-petclinic
code .
```

2. Click the **account icon** (bottom right) → **Sign in to use Copilot.**

   ![VS Code Sign Out State](assets/migrate-to-aks-automatic/vscode-signed-out.png)

3. Select **Continue with GitHub**.

   ![VS Code Continue with GitHub](assets/migrate-to-aks-automatic/vscode-continue-with-github.png)

4. Authorize VS Code to access your GitHub account.

   ![GitHub Authorization](assets/migrate-to-aks-automatic/github-authorize-vscode.png)

5. Click **Connect**, then **Authorize Visual-Studio-Code**.

   ![GitHub Authorization Complete](assets/migrate-to-aks-automatic/github-authorization-complete.png)

6. When prompted, choose to always allow **vscode.dev** to open links.

   ![Allow VS Code Links](assets/migrate-to-aks-automatic/vscode-allow-links.png)

7. Back in VS Code, open the **GitHub Copilot Chat** window and switch the model to **Claude Sonnet 4.5**.

   ![GitHub Copilot Claude Model](assets/migrate-to-aks-automatic/github-copilot-claude-model.png)

#### You're Ready to Begin

Your environment is now configured. Next, you'll verify the local PetClinic application and begin the migration and modernization journey.

## Verify and Explore PetClinic Locally

In this section, you'll confirm that the locally deployed PetClinic application is running with PostgreSQL, and explore its main features.

### Verify the Application

In VS Code, open a new terminal by pressing `` Ctrl+` `` (backtick) or go to **Terminal** → **New Terminal** in the menu.

In the new terminal, run the petclinic:

```bash
mvn clean compile && mvn spring-boot:run \
-Dspring-boot.run.arguments="--spring.messages.basename=messages/messages \
--spring.datasource.url=jdbc:postgresql://localhost/petclinic \
--spring.sql.init.mode=always \
--spring.sql.init.schema-locations=classpath:db/postgres/schema.sql \
--spring.sql.init.data-locations=classpath:db/postgres/data.sql \
--spring.jpa.hibernate.ddl-auto=none"
```

Open your browser and go to http://localhost:8080 to confirm the PetClinic application is running.

   ![PetClinic Application Running](assets/migrate-to-aks-automatic/petclinic-app-running.png)

### Explore the PetClinic Application

Once it's running, try out the key features:

- **Find Owners:** Select **"FIND OWNERS"**, leave the Last Name field blank, and click "Find Owner" to list all 10 owners.

- **View Owner Details:** Click an owner (e.g., Betty Davis) to see their information and pets.

- **Edit Pet Information:** From an owner's page, click **"Edit Pet"** to view or modify pet details.

- **Review Veterinarians:** Go to **"VETERINARIANS"** to see the 6 vets and their specialties (radiology, surgery, dentistry).

After exploring the PetClinic application, you can stop it by pressing `CTRL+C`.

## Application Modernization

In this section, you'll use GitHub Copilot app modernization to assess, remediate, and modernize the Spring Boot application in preparation to migrate the workload to AKS Automatic.

Next let's begin our modernization work.

1. Select `GitHub Copilot app modernization` extension.

   ![GitHub Copilot App Modernization Extension](assets/migrate-to-aks-automatic/copilot-appmod-extension.png)

### Execute the Assessment

Now that you have GitHub Copilot setup, you can use the assessment tool to analyze your Spring Boot PetClinic application using the configured analysis parameters.

1. Navigate the Extension Interface and click **Migrate to Azure** to begin the modernization process.

   ![App Modernization Extension Interface](assets/migrate-to-aks-automatic/appmod-extension-interface.png)

2. Allow the GitHub Copilot app modernization to sign in to GitHub.

   ![Allow GitHub Sign In](assets/migrate-to-aks-automatic/copilot-allow-github-signin.png)

3. Authorize your user to sign in.

   ![GitHub User Authorization](assets/migrate-to-aks-automatic/github-user-authorization.png)

4. And finally, authorize it again on this screen.

   ![GitHub Authorization Screen](assets/migrate-to-aks-automatic/github-authorization-screen.png)

5. The assessment will start now. Notice that GitHub will install the AppCAT CLI for Java. This might take a few minutes.

   ![AppCAT CLI Installation](assets/migrate-to-aks-automatic/appcat-cli-installation.png)

:::info

You can follow the progress of the upgrade by looking at the Terminal in VS Code.

![Assessment Rules Terminal](assets/migrate-to-aks-automatic/assessment-rules-terminal.png)

Also note that you might be prompted to allow access to the language models provided by GitHub Copilot Chat. Click on **Allow**.

![Allow Copilot LLM Access](assets/migrate-to-aks-automatic/copilot-allow-llm-access.png)

:::

### Overview of the Assessment

Assessment results are consumed by GitHub Copilot App Modernization (AppCAT). AppCAT examines the scan findings and produces targeted modernization recommendations to prepare the application for containerization and migration to Azure.

- **target**: the desired runtime or Azure compute service you plan to move the app to.
- **mode**: the analysis depth AppCAT should use.

#### Analysis Targets

Target values select the rule sets and guidance AppCAT will apply.

| Target | Description |
|--------|---------|
| azure-aks | Guidance and best practices for deploying to Azure Kubernetes Service (AKS). |
| azure-appservice | Guidance and best practices for deploying to Azure App Service. |
| azure-container-apps | Guidance and best practices for deploying to Azure Container Apps. |
| cloud-readiness | General recommendations to make the app "cloud-ready" for Azure. |
| linux | Recommendations to make the app Linux-ready (packaging, file paths, runtime details). |
| openjdk11 | Compatibility and runtime recommendations for running Java 8 apps on Java 11. |
| openjdk17 | Compatibility and runtime recommendations for running Java 11 apps on Java 17. |
| openjdk21 | Compatibility and runtime recommendations for running Java 17 apps on Java 21. |

#### Analysis Modes

Choose how deep AppCAT should inspect the project.

| Mode | Description |
|--------|---------|
| source-only | Fast analysis that examines source code only. |
| full | Full analysis: inspects source code and scans dependencies (slower, more thorough). |

#### Where to Change These Options

Edit the file at `.github/appmod-java/appcat/assessment-config.yaml` to change targets and modes.

For this lab, AppCAT runs with the following configuration:

```yaml
appcat:
  - target:
      - azure-aks
      - azure-appservice
      - azure-container-apps
      - cloud-readiness
    mode: source-only
```

If you want a broader scan (including dependency checks) change `mode` to `full`, or add/remove entries under `target` to focus recommendations on a specific runtime or Azure compute service.

### Review the Assessment Results

After the assessment completes, you'll see a success message in the GitHub Copilot chat summarizing what was accomplished:

![Assessment Report Overview](assets/migrate-to-aks-automatic/assessment-report-overview.png)

The assessment analyzed the Spring Boot Petclinic application for cloud migration readiness and identified the following:

**Key Findings:**

- 8 cloud readiness issues requiring attention
- 1 Java upgrade opportunity for modernization

**Resolution Approach:** More than 50% of the identified issues can be automatically resolved through code and configuration updates using GitHub Copilot's built-in app modernization capabilities.

**Issue Prioritization:** Issues are categorized by urgency level to guide remediation efforts:

- **Mandatory (Purple)** - Critical issues that must be addressed before migration.
- **Potential (Blue)** - Performance and optimization opportunities.
- **Optional (Gray)** - Nice-to-have improvements that can be addressed later.

This prioritization framework ensures teams focus on blocking issues first while identifying opportunities for optimization and future enhancements.

### Review Specific Findings

Click on individual issues in the report to see detailed recommendations. In practice, you would review all recommendations and determine the set that aligns with your migration and modernization goals for the application.

:::note

For this lab, we will spend our time focusing on one modernization recommendation: updating the code to use modern authentication via Azure Database for PostgreSQL Flexible Server with Entra ID authentication.

:::

| Aspect | Details |
|--------|---------|
| **Modernization Lab Focus** | Database Migration to Azure PostgreSQL Flexible Server |
| **What was found** | PostgreSQL database configuration using basic authentication detected in Java source code files |
| **Why this matters** | External dependencies like on-premises databases with legacy authentication must be resolved before migrating to Azure |
| **Recommended solution** | Migrate to Azure Database for PostgreSQL Flexible Server |
| **Benefits** | Fully managed service with automatic backups, scaling, and high availability |

### Take Action on Findings

Based on the assessment findings, GitHub Copilot app modernization provides two types of migration actions to assist with modernization opportunities:

1. Using the **guided migrations** ("Run Task" button), which offer fully guided, step-by-step remediation flows for common migration patterns that the tool has been trained to handle.

2. Using the **unguided migrations** ("Ask Copilot" button), which provide AI assistance with context aware guidance and code suggestions for more complex or custom scenarios.

![Guided vs Unguided Migration Options](assets/migrate-to-aks-automatic/migration-options-guided-vs-unguided.png)

For this workshop, we'll focus on one modernization area that demonstrates how to externalize dependencies in the workload to Azure PaaS before deploying to AKS Automatic. We'll migrate from self-hosted PostgreSQL with basic authentication to Azure PostgreSQL Flexible Server using Entra ID authentication with AKS Workload Identity.

### Select PostgreSQL Migration Task

Begin the modernization by selecting the desired migration task. For our Spring Boot application, we will migrate to Azure PostgreSQL Flexible Server using the Spring option. The other options shown are for generic JDBC usage.

![Select PostgreSQL Migration Task](assets/migrate-to-aks-automatic/select-postgres-migration-task.png)

:::note

Choose the "Spring" option for Spring Boot applications, as it provides Spring-specific optimizations and configurations. The generic JDBC options are for non-Spring applications.

:::

### Execute Postgres Migration Task

Click the **Run Task** button described in the previous section to kick off the modernization changes needed in the PetClinic app. This will update the Java code to work with PostgreSQL Flexible Server using Entra ID authentication.

![Run PostgreSQL Migration Task](assets/migrate-to-aks-automatic/run-postgres-migration-task.png)

The tool will execute the `appmod-run-task` command for `managed-identity-spring/mi-postgresql-spring`, which will examine the workspace structure and initiate the migration task to modernize your Spring Boot application for Azure PostgreSQL with managed identity authentication. If prompted to run shell commands, please review and allow each command as the Agent may require additional context before execution.

### Review Migration Plan and Begin Code Migration

The App Modernization tool has analyzed your Spring Boot application and generated a comprehensive migration plan in its chat window and in the `plan.md` file. This plan outlines the specific changes needed to implement Azure Managed Identity authentication for PostgreSQL connectivity.

![Migration Plan Review](assets/migrate-to-aks-automatic/migration-plan-review.png)

To Begin Migration type **"Continue"** in the GitHub Agent Chat to start the code refactoring.

### Review Migration Process and Progress Tracking

Once you confirm with **"Continue"**, the migration tool begins implementing changes using a structured, two-phase approach designed to ensure traceability and commit changes to a new dedicated code branch for changes to enable rollback if needed.

#### Two-Phase Migration Process

**Phase 1: Update Dependencies**

- **Purpose**: Add the necessary Azure libraries to your project.
- **Changes made**:
  - Updates `pom.xml` with Spring Cloud Azure BOM and PostgreSQL starter dependency
  - Updates `build.gradle` with corresponding Gradle dependencies
  - Adds Spring Cloud Azure version properties.

**Phase 2: Configure Application Properties**

- **Purpose**: Update configuration files to use managed identity authentication.
- **Changes made**:
  - Updates `application.properties` to configure PostgreSQL with managed identity (9 lines added, 2 removed)
  - Updates `application-postgres.properties` with Entra ID authentication settings (5 lines added, 4 removed)
  - Replaces username/password authentication with managed identity configuration.

#### Progress Tracking

The `progress.md` file provides real-time visibility into the migration process:

- **Change documentation**: Detailed log of what changes are being made and why.
- **File modifications**: Clear tracking of which files are being updated.
- **Rationale**: Explanation of the reasoning behind each modification.
- **Status updates**: Real-time progress of the migration work.

:::info

**How to Monitor Progress:**

- Watch the GitHub Copilot chat for real-time status updates
- Check the `progress.md` file in the migration directory for detailed change logs
- Review the `plan.md` file to understand the complete migration strategy
- Monitor the terminal output for any build or dependency resolution messages

:::

### Review Migration Completion Summary

Upon successful completion of the validation process, the App Modernization tool presents a comprehensive migration summary report confirming the successful implementation of Azure Managed Identity authentication for PostgreSQL in your Spring Boot application.

![Migration Success Summary](assets/migrate-to-aks-automatic/migration-success-summary.png)

The migration has successfully transformed your application from **password-based** Postgres authentication to **Azure Managed Identity** for PostgreSQL, removing the need for credentials in code while maintaining application functionality. The process integrated Spring Cloud Azure dependencies, updated configuration properties for managed identity authentication, and ensured all validation stages passed including: **CVE scanning, build validation, consistency checks, and test execution**.

:::info

Because the workload is based on Java Spring Boot, an advantage of this migration is that no Java code changes were required. Spring Boot's configuration-driven architecture automatically handles database connection details based on the configuration files.

When switching from password authentication to managed identity, Spring reads the updated configuration and automatically uses the appropriate authentication method. Your existing Java code for database operations (such as saving pet records or retrieving owner information) continues to function as before, but now connects to the database using the more secure managed identity approach.

:::

**Files Modified:**

The migration process updated the following configuration files:

- `pom.xml` and `build.gradle` - Added Spring Cloud Azure dependencies.
- `application.properties` and `application-postgres.properties` - Configured managed identity authentication.
- Test configurations - Updated to work with the new authentication method.

:::info

Throughout this lab, the GitHub Copilot App Modernization extension will create, edit and change various files. The Agent will give you an option to _Keep_ or _Undo_ these changes which will be saved into a new Branch, preserving your original files in case you need to rollback any changes.

![Keep or Undo Changes](assets/migrate-to-aks-automatic/keep-or-undo-changes.png)

:::

### Validation and Fix Iteration Loop

After implementing the migration changes, the App Modernization tool automatically validates the results through a comprehensive testing process to ensure the migration changes are secure, functional, and consistent.

![Validation Iteration Loop](assets/migrate-to-aks-automatic/validation-iteration-loop.png)

**Validation Stages:**

| Stage | Validation | Details |
|--------|---------|---------|
| 1 | **CVE Validation** | Scans newly added dependencies for known security vulnerabilities. |
| 2 | **Build Validation** | Verifies the application compiles and builds successfully after migration changes. |
| 3 | **Consistency Validation** | Ensures all configuration files are properly updated and consistent. |
| 4 | **Test Validation** | Executes application tests to verify functionality remains intact. |

During these stages, you might be prompted to allow the **GitHub Copilot app modernization** extension to access GitHub. Allow it and select your user account when asked.

![Allow GitHub Access for CVE Check](assets/migrate-to-aks-automatic/allow-github-cve-access.png)

**Automated Error Detection and Resolution:**

The tool includes intelligent error detection capabilities that automatically identify and resolve common issues:

- Parses build output to detect compilation errors.
- Identifies root causes of test failures.
- Applies automated fixes for common migration issues.
- Continues through validation iterations (up to 10 iterations) until the build succeeds.

:::info

**User Control:**

At any point during this validation process, you may interrupt the automated fixes and manually resolve issues if you prefer to handle specific problems yourself. The tool provides clear feedback on what it's attempting to fix and allows you to take control when needed at any time.

This systematic approach ensures your Spring Boot application is successfully modernized for Azure PostgreSQL with Entra ID authentication while maintaining full functionality.

:::

## Generate Containerization Assets with AI

In this section, you'll use AI-powered tools to generate Docker and Kubernetes manifests for your modernized Spring Boot application.

### Retrieve PostgreSQL Configuration from AKS Service Connector

Before you can use **Containerization Assist**, you must first retrieve the PostgreSQL Service Connector configuration from your AKS cluster.

This information ensures that your generated Kubernetes manifests are correctly wired to the database using managed identity and secret references.

### Access AKS Service Connector and Retrieve PostgreSQL Configuration

1. Open a new tab in the Edge browser and navigate to the Azure Portal.

2. Sign in to Azure using your lab provided credentials available in the **Resources** tab.

3. In the top search bar, type **aks-petclinic** and select the AKS Automatic cluster.

   ![Select AKS Cluster](assets/migrate-to-aks-automatic/select-aks-cluster.png)

4. In the left-hand menu under **Settings**, select **Service Connector**.

   ![Select Service Connector](assets/migrate-to-aks-automatic/select-service-connector.png)

5. You'll see the service connection that was automatically created **PostgreSQL connection** with a name that starts with **postgresflexible_** connecting to your PostgreSQL flexible server.

6. Select the **DB for PostgreSQL flexible server** and click the **YAML snippet** button in the action bar.

   ![YAML Snippet Button](assets/migrate-to-aks-automatic/service-connector-yaml-snippet.png)

7. Expand this connection to see the variables that were created by the secret in the cluster.

   ![Service Connector Variables](assets/migrate-to-aks-automatic/service-connector-variables.png)

### Retrieve PostgreSQL YAML Configuration

The Azure Portal will display a YAML snippet showing how to use the Service Connector secrets for PostgreSQL connectivity.

![PostgreSQL YAML Configuration Sample](assets/migrate-to-aks-automatic/postgres-yaml-config-sample.png)

:::note

1. The portal shows a sample deployment with workload identity configuration.
2. Key Elements:
   - Service account: Example format `sc-account-d4157fc8-73b5-4a68-acf4-39c8f22db792`
   - Secret reference: Example format `sc-postgresflexiblebft3u-secret`
   - Workload identity label: `azure.workload.identity/use: "true"`

The Service Connector secret contains the following variables:

- AZURE_POSTGRESQL_HOST
- AZURE_POSTGRESQL_PORT
- AZURE_POSTGRESQL_DATABASE
- AZURE_POSTGRESQL_CLIENTID (map to both AZURE_CLIENT_ID and AZURE_MANAGED_IDENTITY_NAME)
- AZURE_POSTGRESQL_USERNAME

:::

### Using Containerization Assist

In the GitHub Copilot agent chat, use the following prompt to generate production-ready Docker and Kubernetes manifests:

```
Help me containerize the application at ./src and generate Kubernetes deployment artifacts using Containerization Assist. Put all of the kubernetes files in a directory called k8s. PostgreSQL Configuration via Azure Service Connector.
```

:::note

To expedite your lab experience, you can allow the Containerization Assist MCP server to run on this Workspace. Select **Allow in this Workspace** or **Always Allow**.

![Allow Containerization Assist MCP](assets/migrate-to-aks-automatic/containerization-assist-mcp-allow.png)

You will also need to allow the MCP server to make LLM requests. Select **Always**.

![Allow MCP LLM Requests](assets/migrate-to-aks-automatic/containerization-assist-mcp-llm.png)

:::

The Containerization Assist MCP Server will analyze your repository and generate:

- **Dockerfile**: Multi-stage build with optimized base image
- **Kubernetes Deployment**: With Azure workload identity, PostgreSQL secrets, health checks, and resource limits
- **Kubernetes Service**: LoadBalancer configuration for external access

**Expected Result**: Kubernetes manifests in the `k8s/` directory.

### Build and Push Container Image to ACR

Build the containerized application and push it to your Azure Container Registry.

Login to ACR using Azure CLI:

```bash
az acr login --name ${ACR_NAME}
```

Build the Docker image in Azure Container Registry:

```bash
az acr build -t petclinic:0.0.1 . -r ${ACR_NAME}
```

## Deploy to AKS

In this section, you'll deploy the modernized application to AKS Automatic using Service Connector secrets for passwordless authentication with PostgreSQL.

:::info

**About AKS Automatic:** AKS Automatic is a new mode for Azure Kubernetes Service that provides an optimized and simplified Kubernetes experience. It offers automated cluster management, built-in security best practices, intelligent scaling, and pre-configured monitoring - making it ideal for teams who want to focus on applications rather than infrastructure management.

:::

### Deploy the Application to AKS Automatic

Apply the Kubernetes manifests to deploy the application.

Update the image name in your deployment manifest with your ACR login server. You can retrieve the name of your Azure Container Registry with this command:

```bash
echo "${ACR_LOGIN_SERVER}/petclinic:0.0.1"
```

Apply the deployment manifest:

```bash
kubectl apply -f k8s/petclinic.yaml
```

Monitor deployment status:

```bash
kubectl get pods,services,deployments
```

:::note

It might take a minute for the AKS Automatic cluster to provision new nodes for the workload so it is normal to see your pods in a `Pending` state until the new nodes are available. You can verify if there are nodes available with the `kubectl get nodes` command.

```bash
NAME                                    READY   STATUS              RESTARTS   AGE
petclinic-deployment-5f9db48c65-qpb8l   0/1     Pending             0          2m2s
petclinic-deployment-5f9db48c65-vqb8x   0/1     Pending             0          2m2s
```

:::

### Verify Deployment and Connectivity

Test the deployed application and verify Entra ID authentication.

Port forward to access the application:

```bash
kubectl port-forward svc/petclinic-service 8080:80
```

Test the application (in another terminal):

```bash
curl http://localhost:8080
```

Check pod logs for successful database connections:

```bash
kubectl logs -l app=petclinic
```

Verify health endpoints:

```bash
curl http://localhost:8080/actuator/health
```

### Validate Entra ID Authentication

Verify that the application is using passwordless authentication.

Check environment variables in the pod (get first pod with label):

```bash
POD_NAME=$(kubectl get pods -l app=petclinic -o jsonpath='{.items[0].metadata.name}')
kubectl exec ${POD_NAME} -- env | grep POSTGRES
```

Verify no password environment variables are present:

```bash
kubectl exec ${POD_NAME} -- env | grep -i pass
```

Check application logs for successful authentication:

```bash
kubectl logs -l app=petclinic --tail=100 | grep -i "connected\|authenticated"
```

**Expected Outcome:** The application is successfully deployed to AKS with passwordless authentication to PostgreSQL using Entra ID and workload identity.

## Workshop Recap & What's Next

**Congratulations!** You've successfully completed a comprehensive application modernization journey, transforming a legacy Spring Boot application into a cloud-native, secure, and scalable solution on Azure.

![PetClinic on Azure](assets/migrate-to-aks-automatic/petclinic-deployed-on-azure.png)

### What You Accomplished

**Local Environment Setup**

- Set up Spring Boot PetClinic with PostgreSQL in Docker
- Validated local application functionality and database connectivity

**Application Modernization**

- Used GitHub Copilot App Modernization to assess code for cloud readiness
- Migrated from basic PostgreSQL authentication to Azure PostgreSQL Flexible Server
- Implemented Microsoft Entra ID authentication with managed identity
- Applied automated code transformations for cloud-native patterns

**Containerization**

- Generated Docker containers using AI-powered tools
- Created optimized Kubernetes manifests with health checks and security best practices
- Built and pushed container images to Azure Container Registry

**Cloud Deployment**

- Deployed to AKS Automatic with enterprise-grade security
- Configured passwordless authentication using workload identity
- Integrated Azure Service Connector for seamless database connectivity
- Validated production deployment with secure authentication

### Next Steps & Learning Paths

**Immediate Next Steps:**

- Explore the deployed application's monitoring and logging capabilities
- Practice scaling the deployment using `kubectl scale`
- Experiment with different environment configurations

**Continue Your Azure Journey:**

- [AKS Automatic Documentation](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic) - Deep dive into automatic cluster management
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/) - Learn enterprise architecture best practices
- [AKS Engineering Blog](https://blog.aks.azure.com/) - Stay updated with latest AKS features and patterns

**Hands-On Labs:**

- [AKS Labs](https://azure-samples.github.io/aks-labs/) - Interactive learning experiences
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/) - Reference architectures and patterns
- [Microsoft Learn - AKS Learning Path](https://learn.microsoft.com/training/paths/intro-to-kubernetes-on-azure/) - Structured learning modules

### Key Takeaways

This workshop demonstrated how AI-powered tools can dramatically accelerate application modernization while maintaining code quality and security standards. The combination of GitHub Copilot App Modernization and Azure's managed services enables teams to focus on business value rather than infrastructure complexity.

## Troubleshooting

### Troubleshooting the Local Deployment

**If the application fails to start:**

1. Check Docker is running: `docker ps`
2. Verify PostgreSQL container is healthy: `docker logs petclinic-postgres`
3. Check application logs: `tail -f ~/app.log`
4. Ensure port 8080 is not in use: `lsof -i :8080`

**If the database connection fails:**

1. Verify PostgreSQL container is running on port 5432: `docker port petclinic-postgres`
2. Test database connectivity: `docker exec -it petclinic-postgres psql -U petclinic -d petclinic -c "SELECT 1;"`

### Troubleshooting the Application in AKS

If for some reason you've made it here and your deployment did not work, your deployment file should resemble this example.

:::info

Key areas to pay close attention to are:

- `azure.workload.identity/use: "true"`
- `serviceAccountName: sc-account-XXXX` this needs to reflect the service account created earlier during the PostgreSQL Service Connector
- `image: <acr-login-server>/petclinic:0.0.1` this should point to your ACR and image created earlier.

:::

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-petclinic
  labels:
    app: spring-petclinic
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spring-petclinic
  template:
    metadata:
      labels:
        app: spring-petclinic
        version: v1
        azure.workload.identity/use: "true"  # Enable Azure Workload Identity
    spec:
      serviceAccountName: sc-account-71b8f72b-9bed-472a-8954-9b946feee95c # change this
      containers:
      - name: spring-petclinic
        image: acrpetclinic556325.azurecr.io/petclinic:0.0.1 # change this value
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        
        # Environment variables from Azure Service Connector secret
        env:
        # Azure Workload Identity - automatically injected by webhook
        # AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_FEDERATED_TOKEN_FILE are set by workload identity
        
        # Map PostgreSQL host from secret - with Azure AD authentication parameters
        - name: POSTGRES_URL
          value: "jdbc:postgresql://$(AZURE_POSTGRESQL_HOST):$(AZURE_POSTGRESQL_PORT)/$(AZURE_POSTGRESQL_DATABASE)?sslmode=require&authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_USERNAME
        # Client ID is also needed for Spring Cloud Azure
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_CLIENTID
              optional: true
        - name: AZURE_MANAGED_IDENTITY_NAME
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_CLIENTID
        - name: AZURE_POSTGRESQL_HOST
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_HOST
        - name: AZURE_POSTGRESQL_PORT
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_PORT
        - name: AZURE_POSTGRESQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: sc-postgresflexible4q7w6-secret # change this value
              key: AZURE_POSTGRESQL_DATABASE
        - name: SPRING_PROFILES_ACTIVE
          value: "postgres"
        # Spring Cloud Azure configuration for workload identity
        - name: SPRING_CLOUD_AZURE_CREDENTIAL_MANAGED_IDENTITY_ENABLED
          value: "true"
        - name: SPRING_DATASOURCE_AZURE_PASSWORDLESS_ENABLED
          value: "true"        
        # Make all secret keys available in the pod
        envFrom:
        - secretRef:
            name: sc-postgresflexible4q7w6-secret # change this value
        # Health check probes
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3
        # Resource limits and requests
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        # Security context
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
            - ALL
      # Pod security context
      securityContext:
        fsGroup: 1000
      # Restart policy
      restartPolicy: Always
```
