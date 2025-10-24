@lab.Title

This workshop demonstrates how to migrate and modernize the iconic **Spring Boot PetClinic** application from local execution to **Azure AKS Automatic**. You'll experience the complete modernization journey using AI-powered tools such as **GitHub Copilot app modernization** and **Containerization Assist MCP Server**.

---

## Workshop Overview

### Learning Objectives

By the end of this workshop, you will be able to:

- Run [Spring Boot PetClinic](https://github.com/spring-projects/spring-petclinic) locally with PostgreSQL and basic authentication.  
- Modernize the codebase using [GitHub Copilot app modernization](https://marketplace.visualstudio.com/items?itemName=vscjava.migrate-java-to-azure).  
- Migrate the database to [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/) integrated with [Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/).  
- Containerize the app using [Containerization Assist MCP Server](https://github.com/Azure/containerization-assist).  
- Deploy to [AKS Automatic](https://learn.microsoft.com/azure/aks/automatic/) using [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) and [Service Connector](https://learn.microsoft.com/en-us/azure/service-connector/).

---

### Prerequisites Check

Your virtual machine already includes all the required tools:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)  
- [Java 17 or 21](https://learn.microsoft.com/en-us/java/openjdk/download) (Microsoft OpenJDK)  
- [Maven 3.8+](https://maven.apache.org/install.html)  
- [Docker Desktop](https://www.docker.com/)  
- [Visual Studio Code](https://code.visualstudio.com/) with:  
  - Java Extension Pack  
  - GitHub Copilot App Modernization Extension Pack  
- [kubectl](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#install-the-azure-cli-and-kubernetes-cli)  
- Windows Terminal with Bash (WSL)  
- Git  

===

## Welcome to Your Lab Environment

To begin, log into the virtual machine using the following credentials: +++@lab.VirtualMachine(Win11-Pro-Base).Password+++

---

### Setting Up the Lab

#### Sign In to Azure

1. Open Microsoft Edge and log into Azure with the credentials in the **Resources** tab: +++https://portal.azure.com/+++

	!IMAGE[resources.png](instructions310381/resources.png)

1. Next, in a terminal window, sign in to uze azure cli:

	```bash
	az login
	```
1. Press the `CTRL` key and then click on the URL in the terminal. This will open a new tab in Edge.
	!IMAGE[az-cli-click-url.png](instructions310381/az-cli-click-url.png)

1. Pick your user account to finish logging in.

	!IMAGE[az-cli-login2.png](instructions310381/az-cli-login2.png)

1. Back in the terminal window, press **Enter** to select the current subscription

---

### Install the Service Connector

1. In a terminal, run the following command to install the service-connector:

```bash
az extension add --name serviceconnector-passwordless --upgrade

nohup bash -c 'az aks connection create postgres-flexible --connection pg --source-id @lab.CloudResourceTemplate(LAB502).Outputs[aksClusterId] --target-id @lab.CloudResourceTemplate(LAB502).Outputs[postgresDatabaseId] --workload-identity @lab.CloudResourceTemplate(LAB502).Outputs[userAssignedIdentityId] --client-type none --kube-namespace default | tee ~/spring-petclinic/k8s/sc.json' > ~/spring-petclinic/k8s/sc.log 2>&1 &
```

> [!note] This script will log its output into the **~/spring-petclinic/k8s/sc.log** file. You can check for its progress opening that file.

<!-- 
> [!note] This command will take about 8 minutes to run. To make most of your time on this lab, you can leave it running on this terminal until it finishes. You can open a new tab in the Windows Terminal by clicking on the plus sign and proceed to the next step on this lab.
> !IMAGE[new-tab.png](instructions310381/new-tab.png) -->

---

### Configure Azure RBAC Authentication for kubectl

Before deploying to AKS, you need to configure kubectl to use Azure RBAC authentication.

1. In your terminal window, run the following commands:

```bash
# add Admin to your user
az role assignment create --assignee @lab.CloudPortalCredential(User1).Username --role "Azure Kubernetes Service RBAC Cluster Admin" --scope  @lab.CloudResourceTemplate(LAB502).Outputs[aksClusterId]

# Get AKS credentials (this downloads the kubeconfig)
az aks get-credentials --resource-group  @lab.CloudResourceGroup(myResourceGroup).Name --name @lab.CloudResourceTemplate(LAB502).Outputs[aksClusterName]

# Configure kubectl to use Azure RBAC authentication
kubelogin convert-kubeconfig --login azurecli

# Test AKS access
kubectl get nodes
```

> [!note] The `kubelogin convert-kubeconfig --login azurecli` command configures kubectl to use Entra (Azure AD) authentication with the Azure RBAC roles assigned to your user account. This is required for AKS Automatic clusters with Azure RBAC enabled.

---

#### Authenticate GitHub Copilot

To use GitHub Copilot, sign in with the GitHub account provided in your lab environment.

1. In Edge, open +++https://github.com/enterprises/skillable-events/sso+++

1. Click on **Continue**

	!IMAGE[continue-with-github.png](instructions310381/continue-with-github.png)

1. Log in with the credentials listed in the **Resources** tab.

### Sign In to VS Code with GitHub

After signing in to GitHub, open VS Code and complete the Copilot setup:

1. In your terminal, run the following command to launch a new VS Code instance into the `spring-petclinic` source directory:
   
	```bash
	cd ~/spring-petclinic
	code .
	```

1. Click the **account icon** (bottom right) → **Sign in to use Copilot.**

	!IMAGE[signed-out.png](instructions310381/signed-out.png)

1. Select **Continue with GitHub**

	!IMAGE[continue-to-github.png](instructions310381/continue-to-github.png)

1. Authorize VS Code to access your GitHub account.

	!IMAGE[authorize-github.png](instructions310381/authorize-github.png)

1. Click **Connect**, then **Authorize Visual-Studio-Code**.

	!IMAGE[authorized-github.png](instructions310381/authorized-github.png)

1. When prompted, choose to always allow **vscode.dev** to open links.

	!IMAGE[allow-vs-code.png](instructions310381/allow-vs-code.png)

1. Back in VS Code, open the **GitHub Copilot Chat** window and switch the model to **Claude Sonnet 4.5**.

	!IMAGE[github-claude.png](instructions310381/github-claude.png)
 
#### You're Ready to Begin

Your environment is now configured. Next, you'll verify the local PetClinic application and begin the migration and modernization journey.

===

## Verify and Explore PetClinic Locally

**What You'll Do:** Confirm that the locally deployed PetClinic application is running with PostgreSQL, and explore its main features.

**What You'll Learn:** How to verify a local Spring Boot application connected to a Docker-based PostgreSQL database and navigate its core functionality.

---

### Verify the Application

1. In VS Code, open a new terminal by pressing ``Ctrl+` `` (backstick) or go to **Terminal** → **New Terminal** in the menu.

1. In the new terminal, run the petclinic

	```bash
	 mvn clean compile && mvn spring-boot:run \
    -Dspring-boot.run.arguments="--spring.messages.basename=messages/messages --spring.datasource.url=jdbc:postgresql://localhost/petclinic --spring.sql.init.mode=always --spring.sql.init.schema-locations=classpath:db/postgres/schema.sql --spring.sql.init.data-locations=classpath:db/postgres/data.sql --spring.jpa.hibernate.ddl-auto=none"
	```

1. Open your browser and go to `http://localhost:8080` to confirm the PetClinic application is running.

!IMAGE[peclinic.png](instructions310381/peclinic.png)

**Explore the PetClinic Application:**

Once it's running, try out the key features:

* **Find Owners:** Select **"FIND OWNERS"**, leave the Last Name field blank, and click "Find Owner" to list all 10 owners.

* **View Owner Details:** Click an owner (e.g., Betty Davis) to see their information and pets.

* **Edit Pet Information:** From an owner's page, click **"Edit Pet"** to view or modify pet details.

* **Review Veterinarians:** Go to **"VETERINARIANS"** to see the 6 vets and their specialties (radiology, surgery, dentistry).

After exploring the PetClinic application, you can stop it by pressing `CTRL+C`

===

## Application Modernization

**What You'll Do:** Use GitHub Copilot app modernization to assess, remediate, and modernize the Spring Boot application in preparation to migrate the workload to AKS Automatic.

**What You'll Learn:** How GitHub Copilot app modernization works, demonstration of modernizing elements of legacy applications, and the modernization workflow

---

Next let's begin our modernization work. 

1. Select  `GitHub Copilot app modernization` extension
	
	!IMAGE[github-copilot-appmod-ext.png](instructions310381/github-copilot-appmod-ext.png)

### Execute the Assessment

Now that you have GitHub Copilot setup, you can use the assessment tool to analyze your Spring Boot PetClinic application using the configured analysis parameters.

1. Navigate the Extension Interface and click **Migrate to Azure** to begin the modernization process.

	!IMAGE[module2-step2-extension-interface.png](instructions310381/module2-step2-extension-interface.png)

<!-- 1. Allow the GitHub Copilot app modernization to sign in to GitHub 
	!IMAGE[ghcp-allow-signin.png](instructions310381/ghcp-allow-signin.png)

1. Authorize your user to sign in

	!IMAGE[gh-auth-user.png](instructions310381/gh-auth-user.png)

1. And finally, authorized it again on this screen

	!IMAGE[gh-auth-screen.png](instructions310381/gh-auth-screen.png)

1. The assessment will start now. Notice that GitHub will install the AppCAT CLI for Java. This might take a few minutes

	!IMAGE[appcat-install.png](instructions310381/appcat-install.png) -->

> [!hint] You can follow the progress of the upgrade by looking at the Terminal in vscode
!IMAGE[assessment-rules.png](instructions310381/assessment-rules.png)

<!-- Also note that you might be prompted to allow access to the language models provided by GitHub Copilot Chat. Click on **Allow**

!IMAGE[ghcp-allow-llm.png](instructions310381/ghcp-allow-llm.png) -->

### Overview of the Assessment

Assessment results are consumed by GitHub Copilot App Modernization (AppCAT). AppCAT examines the scan findings and produces targeted modernization recommendations to prepare the application for containerization and migration to Azure.

- target: the desired runtime or Azure compute service you plan to move the app to.
- mode: the analysis depth AppCAT should use.

**Analysis targets**

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

**Analysis modes**

Choose how deep AppCAT should inspect the project.

| Mode | Description |
|--------|---------|
| source-only | Fast analysis that examines source code only. |
| full | Full analysis: inspects source code and scans dependencies (slower, more thorough). |

> [!knowledge]  **Where to change these options**
>
> You can customize this report by editing the file at **.github/appmod-java/appcat/assessment-config.yaml** to change targets and modes.
>
>For this lab, AppCAT runs with the following configuration:
>
>```yaml
>appcat:
>  - target:
>      - azure-aks
>      - azure-appservice
>      - azure-container-apps
>      - cloud-readiness
>    mode: source-only
>```
>
>If you want a broader scan (including dependency checks) change `mode` to `full`, or add/remove entries under `target` to focus recommendations on a specific runtime or Azure compute service.

### Review the Assessment results

After the assessment completes, you'll see a success message in the GitHub Copilot chat summarizing what was accomplished:

!IMAGE[module2-assessment-report-overview.png](instructions310381/module2-assessment-report-overview.png)

The assessment analyzed the Spring Boot Petclinic application for cloud migration readiness and identified the following:

Key Findings:

* 8 cloud readiness issues requiring attention (1)
* 1 Java upgrade opportunity for modernization (2)

**Resolution Approach:** More than 50% of the identified issues can be automatically resolved through code and configuration updates using GitHub Copilot's built-in app modernization capabilities (3).

**Issue Prioritization:** Issues are categorized by urgency level to guide remediation efforts:

* Mandatory (Purple) - Critical issues that must be addressed before migration.
* Potential (Blue) - Performance and optimization opportunities.
* Optional (Gray) - Nice-to-have improvements that can be addressed later.

This prioritization framework ensures teams focus on blocking issues first while identifying opportunities for optimization and future enhancements.

### Review Specific Findings

Click on individual issues in the report to see detailed recommendations. In practice, you would review all recommendations and determine the set that aligns with your migration and modernization goals for the application.

> [!note] For this lab, we will spend our time focusing on one modernization recommendation: updating the code to use modern authentication via Azure Database for PostgreSQL Flexible Server with Entra ID authentication.


| Aspect | Details |
|--------|---------|
| **Modernization Lab Focus** | Database Migration to Azure PostgreSQL Flexible Server |
| **What was found** | PostgreSQL database configuration using basic authentication detected in Java source code files |
| **Why this matters** | External dependencies like on-premises databases with legacy authentication must be resolved before migrating to Azure |
| **Recommended solution** | Migrate to Azure Database for PostgreSQL Flexible Server |
| **Benefits** | Fully managed service with automatic backups, scaling, and high availability |

===

### Take Action on Findings

Based on the assessment findings, GitHub Copilot app modernization provides two types of migration actions to assist with modernization opportunities:

1. Using the **guided migrations** ("Run Task" button), which offer fully guided, step-by-step remediation flows for common migration patterns that the tool has been trained to handle. 

2. Using the **unguided migrations** ("Ask Copilot" button), which provide AI assistance with context aware guidance and code suggestions for more complex or custom scenarios.

!IMAGE[module2-step11-guided-migration-vs-copilot-prompts.png](instructions310381/module2-step11-guided-migration-vs-copilot-prompts.png)

For this workshop, we'll focus on one modernization area that demonstrates how to externalize dependencies in the workload to Azure PaaS before deploying to AKS Automatic. We'll migrate from self-hosted PostgreSQL with basic authentication to Azure PostgreSQL Flexible Server using Entra ID authentication with AKS Workload Identity.

### Select PostgreSQL Migration Task

Begin the modernization by selecting the desired migration task. For our Spring Boot application, we will migrate to Azure PostgreSQL Flexible Server using the Spring option. The other options shown are for generic JDBC usage.

!IMAGE[module2-step12-select-postgres-migration-task.png](instructions310381/module2-step12-select-postgres-migration-task.png)

> [!note]: Choose the "Spring" option for Spring Boot applications, as it provides Spring-specific optimizations and configurations. The generic JDBC options are for non-Spring applications.

### Execute Postgres Migration Task

Click the **Run Task** button described in the previous section to kick off the modernization changes needed in the PetClinic app. This will update the Java code to work with PostgreSQL Flexible Server using Entra ID authentication.

!IMAGE[module2-step12-run-migration-task.png](instructions310381/module2-step12-run-migration-task.png)

The tool will execute the `appmod-run-task` command for `managed-identity-spring/mi-postgresql-spring`, which will examine the workspace structure and initiate the migration task to modernize your Spring Boot application for Azure PostgreSQL with managed identity authentication. If prompted to run shell commands, please review and allow each command as the Agent may require additional context before execution.

### Review Migration Plan and Begin Code Migration

The App Modernization tool has analyzed your Spring Boot application and generated a comprehensive migration plan in its chat window and in the `plan.md` file. This plan outlines the specific changes needed to implement Azure Managed Identity authentication for PostgreSQL connectivity.

!IMAGE[module2-step14-review-migration-plan.png](instructions310381/module2-step14-review-migration-plan.png)

To Begin Migration type **"Continue"** in the GitHub Agent Chat to start the code refactoring.

### Review Migration Process and Progress Tracking

Once you confirm with **"Continue"**, the migration tool begins implementing changes using a structured, two-phase approach designed to ensure traceability and commit changes to a new dedicated code branch for changes to enable rollback if needed.

**Two-Phase Migration Process:**

> [!knowledge] 
> **Phase 1: Update Dependencies**
- **Purpose**: Add the necessary Azure libraries to your project.
- **Changes made**:
  - Updates `pom.xml` with Spring Cloud Azure BOM and PostgreSQL starter dependency
  - Updates `build.gradle` with corresponding Gradle dependencies
  - Adds Spring Cloud Azure version properties.

> [!knowledge] 
> **Phase 2: Configure Application Properties**
- **Purpose**: Update configuration files to use managed identity authentication.
- **Changes made**:
  - Updates `application.properties` to configure PostgreSQL with managed identity (9 lines added, 2 removed)
  - Updates `application-postgres.properties` with Entra ID authentication settings (5 lines added, 4 removed)
  - Replaces username/password authentication with managed identity configuration.

**Progress Tracking:**
The `progress.md` file provides real-time visibility into the migration process:
- **Change documentation**: Detailed
-  log of what changes are being made and why.
- **File modifications**: Clear tracking of which files are being updated.
- **Rationale**: Explanation of the reasoning behind each modification.
- **Status updates**: Real-time progress of the migration work.

> [!hint] 
**How to Monitor Progress:**
- Watch the GitHub Copilot chat for real-time status updates
- Check the `progress.md` file in the migration directory for detailed
-  change logs
- Review the `plan.md` file to understand the complete migration strategy
- Monitor the terminal output for any build or dependency resolution messages
> [!hint] 

### Review Migration Completion Summary

Upon successful completion of the validation process, the App Modernization tool presents a comprehensive migration summary report confirming the successful implementation of Azure Managed Identity authentication for PostgreSQL in your Spring Boot application.

!IMAGE[module2-step17-migration-success-summary.png](instructions310381/module2-step17-migration-success-summary.png)

The migration has successfully transformed your application from **password-based** Postgres authentication to **Azure Managed Identity** for PostgreSQL, removing the need for credentials in code while maintaining application functionality. The process integrated Spring Cloud Azure dependencies, updated configuration properties for managed identity authentication, and ensured all validation stages passed including: **CVE scanning, build validation, consistency checks, and test execution**.

> [!knowledge] Because the workload is based on Java Spring Boot, an advantage of this migration is that no Java code changes were required. Spring Boot's configuration-driven architecture automatically handles database connection details based on the configuration files. 
>
> When switching from password authentication to managed identity, Spring reads the updated configuration and automatically uses the appropriate authentication method. Your existing Java code for database operations (such as saving pet records or retrieving owner information) continues to function as before, but now connects to the database using the more secure managed identity approach.

**Files Modified:**

The migration process updated the following configuration files:

- `pom.xml` and `build.gradle` - Added Spring Cloud Azure dependencies.

- `application.properties` and `application-postgres.properties` - Configured managed identity authentication.

- Test configurations - Updated to work with the new authentication method

> [!hint] Througout this lab, the GitHub Copilot App Modernization extension will create, edit and change various files. The Agent will give you an option to _Keep_ or _Undo_ these changes which will be saved into a new Branch, preserving your original files in case you need to rollback any changes.
!IMAGE[keep-or-undo.png](instructions310381/keep-or-undo.png)


### Validation and Fix Iteration Loop

After implementing the migration changes, the App Modernization tool automatically validates the results through a comprehensive testing process to ensure the migration changes are secure, functional, and consistent.

!IMAGE[module2-step16-cve-validation-iteration-loop.png](instructions310381/module2-step16-cve-validation-iteration-loop.png)

**Validation Stages:**

| Stage | Validation | Details |
|--------|---------|---------
| 1 | **CVE Validation** | Scans newly added dependencies for known security vulnerabilities.
| 2 | **Build Validation** | Verifies the application compiles and builds successfully after migration changes.
| 3 | **Consistency Validation** | Ensures all configuration files are properly updated and consistent.
| 4 | **Test Validation** | Executes application tests to verify functionality remains intact.

> [!note] During these stages, you might be prompted to allow the **GitHub Copilot app modernization** extension to access GitHub. Allow it and select your user account when asked.
>
>!IMAGE[allow-ghcp-cve.png](instructions310381/allow-ghcp-cve.png)

**Automated Error Detection and Resolution:**

The tool includes intelligent error detection capabilities that automatically identify and resolve common issues:

- Parses build output to detect compilation errors.
- Identifies root causes of test failures.
- Applies automated fixes for common migration issues.
- Continues through validation iterations (up to 10 iterations) until the build succeeds.

> [!hint] 
> **User Control:**
> At any point during this validation process, you may interrupt the automated fixes and manually resolve issues if you prefer to handle specific problems yourself. The tool provides clear feedback on what it's attempting to fix and allows you to take control when needed at any time.
>
>This systematic approach ensures your Spring Boot application is successfully modernized for Azure PostgreSQL with Entra ID authentication while maintaining full functionality.
> [!hint] 

===

##  Generate Containerization Assets with AI

**What You'll Do:** Use AI-powered tools to generate Docker and Kubernetes manifests for your modernized Spring Boot application.

**What You'll Learn:** How to create production-ready containerization assets - including optimized Dockerfiles and Kubernetes manifests configured with health checks, secrets, and workload identity.

---

### Using Containerization Assist

In the GitHub Copilot agent chat, use the following prompt to generate production-ready Docker and Kubernetes manifests:

```prompt
/petclinic Help me containerize the application. Create me a new Dockerfile and update my ACR with @lab.CloudResourceTemplate(LAB502).Outputs[acrLoginServer]
```

> [!note] To expedite your lab experience, you can allow the Containerization Assist MCP server to run on this Workspace. Select **Allow in this Workspace** or **Always Allow**.
> 
> !IMAGE[ca-mcp-allow.png](instructions310381/ca-mcp-allow.png)
>
> You will also need to allow the MCP server to make LLM requests. 
> Select **Always**.
> !IMAGE[ca-mcp-llm.png](instructions310381/ca-mcp-llm.png)

The Containerization Assist MCP Server will analyze your repository and generate:

- **Dockerfile**: Multi-stage build with optimized base image

- **Kubernetes Deployment**: With Azure workload identity, PostgreSQL secrets, health checks, and resource limits

- **Kubernetes Service**: LoadBalancer configuration for external access

**Expected Result**: Kubernetes manifests in the `k8s/` directory.

> [!tip] You are almost there. You will deploy the AI generated files, but they might need some tuning later. Before deploying it to your cluster, double check the image location, the use of workload identity and if the service connector secret reference in the deployment file are correct to your environment.


### Build and Push Container Image to ACR

Build the containerized application and push it to your Azure Container Registry:

1. In your terminal window, login to ACR using Azure CLI

	```bash
	az acr login --name @lab.CloudResourceTemplate(LAB502).Outputs[acrName]
  
	```

1. Build the Docker image in Azure Container Registry

	```bash
	az acr build -t petclinic:0.0.1 . -r @lab.CloudResourceTemplate(LAB502).Outputs[acrName]
	```

===

## Deploy to AKS

**What You'll Do:** Deploy the modernized application to AKS Automatic using Service Connector secrets for passwordless authentication with PostgreSQL.

**What You'll Learn:** Kubernetes deployment with workload identity, Service Connector integration, and testing deployed applications with Entra ID authentication.

---

> [!knowledge] **About AKS Automatic:** AKS Automatic is a new mode for Azure Kubernetes Service that provides an optimized and simplified Kubernetes experience. It offers automated cluster management, built-in security best practices, intelligent scaling, and pre-configured monitoring - making it ideal for teams who want to focus on applications rather than infrastructure management.

### Deploy the application to AKS Automatic

Using Containerization Assist we have built a Kubernetes manifest for the Petclini application. In the next steps we will deploy it to the AKS Automatic cluster and verify that it is working:

1. Deploy the application:

	```bash
	kubectl apply -f k8s/petclinic.yaml
	```

1.  Monitor deployment status

	```bash
	kubectl get pods,services,deployments
	```

	It might take a minute for the AKS Automatic cluster to provision new nodes for the workload so it is normal to see your pods in a `Pending` state until the new nodes are available. You can verify is there are nodes available with the `kubectl get nodes` command.

	```bash
	NAME                                    READY   STATUS              RESTARTS   AGE
	petclinic-deployment-5f9db48c65-qpb8l   0/1     Pending             0          2m2s
	```

### Verify Deployment and Connectivity

Test the deployed application and verify Entra ID authentication:

1. Port forward to access the application

	```bash
  kubectl port-forward svc/spring-petclinic-service 9090:8080
	```
1. To test the application, open a new tab in Microsoft Edge and go to `http://localhost:9090`


### Validate Entra ID Authentication

Verify that the application is using passwordless authentication:

1. Check environment variables in the pod (get first pod with label)
	```bash
	POD_NAME=$(kubectl get pods -l app=petclinic -o jsonpath='{.items[0].metadata.name}')
	kubectl exec $POD_NAME -- env | grep POSTGRES
	```

1. Verify no password environment variables are present

	```bash
	kubectl exec $POD_NAME -- env | grep -i pass
	```

1. Check application logs for successful authentication

	```bash
	kubectl logs -l app=petclinic --tail=100 | grep -i "connected\|authenticated"
	```

**Expected Outcome:** The application is successfully deployed to AKS with passwordless authentication to PostgreSQL using Entra ID and workload identity.

=== 

## Workshop Recap & What's Next

**Congratulations!** You've successfully completed a comprehensive application modernization journey, transforming a legacy Spring Boot application into a cloud-native, secure, and scalable solution on Azure.

!IMAGE[petclinic-on-azure.png](instructions310381/petclinic-on-azure.png)

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

---

### Next Steps & Learning Paths

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

===

### Help

In this section you can find tips on how to troubleshoot your lab.

---

#### Troubleshooting the local deployment

**If the application fails to start:**
1. Check Docker is running: `docker ps`
2. Verify PostgreSQL container is healthy: `docker logs petclinic-postgres`
3. Check application logs: `tail -f ~/app.log`
4. Ensure port 8080 is not in use: `lsof -i :8080`

**If the database connection fails:**
1. Verify PostgreSQL container is running on port 5432: `docker port petclinic-postgres`
2. Test database connectivity: `docker exec -it petclinic-postgres psql -U petclinic -d petclinic -c "SELECT 1;"`

---
### Troubleshooting the Service Connector

### Retrieve PostgreSQL Configuration from AKS Service Connector

Before you can use **Containerization Assist**, you must first retrieve the PostgreSQL Service Connector configuration from your AKS cluster.

This information ensures that your generated Kubernetes manifests are correctly wired to the database using managed identity and secret references.

### Access AKS Service Connector and Retrieve PostgreSQL Configuration

1. Open a new tab in the Edge browser and navigate to +++https://portal.azure.com/+++

1. In the top search bar, type **aks-petclinic** and select the AKS Automic cluster.

	!IMAGE[select-aks-petclinic.png](instructions310381/select-aks-petclinic.png)

1. In the left-hand menu under **Settings**, select **Service Connector**.

	!IMAGE[select-sc.jpg](instructions310381/select-sc.jpg)

1.  You'll see the service connection that was automatically created **PostgreSQL connection** with a name that starts with **postgresflexible_** connecting to your PostgreSQL flexible server.

1. Select the **DB for PostgreSQL flexible server** and click the **YAML snippet** button in the action bar

	!IMAGE[yaml-snippet.png](instructions310381/yaml-snippet.png)

1. Expand this connection to see the variables that were created by the `sc-postgresflexiblebft3u-secret` in the cluster

	!IMAGE[sc-variables.png](instructions310381/sc-variables.png)

### Retrieve PostgreSQL YAML Configuration

The Azure Portal will display a YAML snippet showing how to use the Service Connector secrets for PostgreSQL connectivity.
> [+] Service Connector YAML snippet
> 
> !IMAGE[sample-yaml.jpg](instructions310381/sample-yaml.jpg)

> [!note] 
> 1. The portal shows a sample deployment with workload identity configuration
> 2. Key Elements:
>   - Service account: `sc-account-d4157fc8-73b5-4a68-acf4-39c8f22db792`
>   - Secret reference: `sc-postgresflexiblebft3u-secret`
>   - Workload identity label: `azure.workload.identity/use: "true"`
> 
> The Service Connector secret (`sc-postgresflexiblebft3u-secret` in this example), will contain the following variables:
- AZURE_POSTGRESQL_HOST
- AZURE_POSTGRESQL_PORT
- AZURE_POSTGRESQL_DATABASE
- AZURE_POSTGRESQL_CLIENTID (map to both AZURE_CLIENT_ID and AZURE_MANAGED_IDENTITY_NAME)
- AZURE_POSTGRESQL_USERNAME

---

#### Troubleshooting the application in AKS

If for some reason you've made here and your deployment did not work, your deployment file should ressemble this example.

> [!hint] Key areas to pay close attention to are:
> - `azure.workload.identity/use: "true"`
> - `serviceAccountName: sc-account-XXXX` this needs to reflect the service account created earlier during the PostgreSQL Service Connector
> - `image: <acr-login-server>/petclinic:0.0.1` this should point to your ACR and image created earlier.

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
