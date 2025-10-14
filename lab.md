@lab.Title

## Welcome to Your Lab Environment

To begin, log into the virtual machine using the following credentials: +++@lab.VirtualMachine(Win11-Pro-Base).Password+++

---

===

# Spring Boot PetClinic Migration & Modernization Workshop

This workshop demonstrates how to migrate and modernize the iconic Spring Boot PetClinic application from local execution to cloud deployment on Azure AKS Automatic. Participants will experience the complete modernization journey using AI-powered tools: GitHub Copilot app modernization and Containerization Assist MCP Server.

## Workshop Goals

Simulate on‑prem execution by running [Spring Boot PetClinic](https://github.com/spring-projects/spring-petclinic) locally with PostgreSQL and basic auth, modernize the code with [GitHub Copilot app modernization](https://marketplace.visualstudio.com/items?itemName=vscjava.migrate-java-to-azure), migrate to [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/) using [Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/), containerize with (Containerization Assist MCP Server)[https://www.npmjs.com/package/containerization-assist-mcp?activeTab=readme] to generate Docker and Kubernetes manifests, and deploy to [AKS Automatic](https://learn.microsoft.com/azure/aks/automatic/) with [workload identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) and [Service Connector](https://learn.microsoft.com/azure/service-connector/).

## Workshop Structure

```
~/mm-springboot-petclinic-to-aks-automatic-ignite/
├── lab.md                              # This file - Complete workshop guide
├── infra/                              # Infrastructure and automation
│   ├── setup-local-lab-infra.sh        # One-command workshop setup
├── src/                                # Symlink to ~/spring-petclinic
├── manifests/                          # Generated Kubernetes manifests (empty initially)
└── images/                             # Workshop screenshots and diagrams

~/spring-petclinic/                     # Spring PetClinic repository
├── src/main/java/                      # Java source code (modernized during workshop)
├── src/main/resources/                 # Application properties and configuration
├── pom.xml                             # Maven dependencies
└── ...                                 # Other Spring Boot PetClinic files
```

### Prerequisites Check

For this lab, we will use the following tools, which are already installed on this Virtual Machine:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (logged in with `az login` )
- [Java 17 or 21](https://learn.microsoft.com/en-us/java/openjdk/download) (Microsoft OpenJDK)
- [Maven 3.8+](https://maven.apache.org/install.html)
- [Docker Desktop](https://www.docker.com/) or equivalent.
- [VS Code with Java Extension Pack](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack)
- [GitHub Copilot app modernization Extension Pack](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-upgrade)
- [kubectl](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#install-the-azure-cli-and-kubernetes-cli) (available via Azure AKS client tools).
- Windows Terminal with `bash` (Windows Subsystem for Linux).
- git

===

## Module 1: Set Up and Test PetClinic Locally

**What You'll Do:** Set up a complete local development environment with the PetClinic application running against PostgreSQL, then explore the application in your browser.

**What You'll Learn:** How to quickly deploy a local Spring Boot development environment with Docker-based PostgreSQL and verify application functionality.

---

### Run the Automated Setup Script

To facilitate standing up our local environment, we will use a script to perform a complete one-command setup. This script will:

1. **Clone the repository** to `~/spring-petclinic` and creates a symlink for easy access
2. **Launch PostgreSQL** in a Docker container with pre-configured credentials
3. **Build and start** the Spring Boot application connected to the database

Steps:

1. Open the Windows Terminal

	!IMAGE[windows-term.png](instructions310381/windows-term.png)

1. Clone the GitHub repository for this workshop.

	```bash
	git clone https://github.com/appdevgbb/mm-springboot-petclinic-to-aks-automatic-ignite.git
	```

1. Next, execute the setup script from the `infra` directory:

	```bash
	cd mm-springboot-petclinic-to-aks-automatic-ignite/infra
	chmod +x setup-local-lab-infra.sh
	./setup-local-lab-infra.sh
	```

The script will complete in approximately 1-2 minutes. When finished, your PetClinic application will be running at **http://localhost:8080**.

> [!alert] If prompted, click on **Allow** the Docker Desktop access to the network
!IMAGE[allow-docker.png](instructions310381/allow-docker.png)


### Verify the Application

Open your browser and navigate to `http://localhost:8080` to confirm the application is running. 

!IMAGE[peclinic.png](instructions310381/peclinic.png)

**Explore the PetClinic Application:**

Once the application is running in your browser, take some time to explore the functionality:

- **Find Owners**: Go to "FIND OWNERS" -> leave the "Last Name" field blank -> click "Find Owner" to see all 10 owners.

- **View Owner Details**: Click on an owner like "Betty Davis" to see their information and pets.

- **Edit Pet Information**: From an owner's page, click "Edit Pet" to see how pet details are managed.

- **Review Veterinarians**: Navigate to "VETERINARIANS" to see the 6 vets with their specialties (radiology, surgery, dentistry).

---

### Troubleshooting Module 1

**If the application fails to start:**
1. Check Docker is running: `docker ps`
2. Verify PostgreSQL container is healthy: `docker logs petclinic-postgres`
3. Check application logs: `tail -f ~/app.log`
4. Ensure port 8080 is not in use: `lsof -i :8080`

**If the database connection fails:**
1. Verify PostgreSQL container is running on port 5432: `docker port petclinic-postgres`
2. Test database connectivity: `docker exec -it petclinic-postgres psql -U petclinic -d petclinic -c "SELECT 1;"`

===

## Module 2: Application Modernization

**What You'll Do:** Use GitHub Copilot app modernization to assess, remediate, and modernize the Spring Boot application in preparation to migrate the workload to AKS Automatic.

**What You'll Learn:** How GitHub Copilot app modernization works, demonstration of modernizing elements of legacy applications, and the modernization workflow

---

Next, let's open the Petclinic project in a new instance of VS Code and begin our modernization work. 

1. In VS Code, open a terminal and run the following command to launch a new VS Code instance into the `spring-petclinic` source directory:
   
	```bash
	cd ~/spring-petclinic
	code .
	```

1. Once VS Code opens with the PetClinic project, we will be asked a few questions. You can select **Use Maven** and close the two other pop-up windows.

	!IMAGE[vs-code-first-run.png](instructions310381/vs-code-first-run.png)
 	
1. we are ready to use the `GitHub Copilot app modernization`. Go to the Extensions icon in VS Code and then search for `GitHub Copilot app modernization`

	!IMAGE[ghcp-extension.png](instructions310381/ghcp-extension.png)

1. Check if there's any update available for the extension. If there is one, click on **Update** and continue.
1. Select it from the Activity Bar.

	!IMAGE[module2-step1-vscode-extension-selection.png](instructions310381/module2-step1-vscode-extension-selection.png)

> [!alert] If prompted by this windows if you should enable null annotation, click on **Enable**.
!IMAGE[java-null.png](instructions310381/java-null.png)

===


### Authenticate GitHub Copilot

In order to use the GitHub Copilot, you will need to log in using the provided GitHub account.

1. Open a new tab in the Edge browser and navigate to +++https://github.com/enterprises/skillable-events/sso+++

1. Sign in with the GitHub account credentials provided in your lab environment.

> [!hint] Your credentials can be found in the **Resources** tab
!IMAGE[resources.png](instructions310381/resources.png)


### Log into VS Code with GitHub account

After you have logged in, return to VS Code, click the account icon in the bottom right corner, then:

1. Click **Sign in to use Copilot**. 

	!IMAGE[copilot-signin.png](instructions310381/copilot-signin.png)

1. Then select **Continue with GitHub**

	!IMAGE[continue-to-github.png](instructions310381/continue-to-github.png)

1. This will redirect you to a webpage to authorize VS Code to access your GitHub account. 

	!IMAGE[authorize-github.png](instructions310381/authorize-github.png)

1. Click the **Connect** button, then click **Authorize Visual-Studio-Code** to complete the authorization.

	!IMAGE[authorized-github.png](instructions310381/authorized-github.png)

1. Next, select to always allow vscode.dev to open links

	!IMAGE[allow-vs-code.png](instructions310381/allow-vs-code.png)

1. Now back in vs code, go to the GitHub Copilot chat window and change the model to **Claude Sonet 3.7** or later

	!IMAGE[github-claude.png](instructions310381/github-claude.png)
===

### Execute the Assessment

Now that you have GitHub Copilot setup, you can use the assessment tool to analyze your Spring Boot PetClinic application using the configured analysis parameters.

1. Navigate the Extension Interface and click **Migrate to Azure** to begin the modernization process.

	!IMAGE[module2-step2-extension-interface.png](instructions310381/module2-step2-extension-interface.png)

1. Allow the GitHub Copilot app modernization to sign in to GitHub 
	!IMAGE[ghcp-allow-signin.png](instructions310381/ghcp-allow-signin.png)

1. Authorize your user to sign in

	!IMAGE[gh-auth-user.png](instructions310381/gh-auth-user.png)

1. And finally, authorized it again on this screen

	!IMAGE[gh-auth-screen.png](instructions310381/gh-auth-screen.png)

1. The assessment will start now. Notice that GitHub will install the AppCAT CLI for Java. This might take a few minutes

	!IMAGE[appcat-install.png](instructions310381/appcat-install.png)

> [!hint] You can follow the progress of the upgrade by looking at the Terminal in vscode
!IMAGE[assessment-rules.png](instructions310381/assessment-rules.png)

Also note that you might be prompted to allow access to the language models provided by GitHub Copilot Chat. Click on **Allow**

!IMAGE[ghcp-allow-llm.png](instructions310381/ghcp-allow-llm.png)

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

**Where to change these options**

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

===

### Review the Assessment results

After the assessment completes, you'll see a success message in the GitHub Copilot chat summarizing what was accomplished:

!IMAGE[module2-step8-assessment-report-details.png](instructions310381/module2-step8-assessment-report-details.png)

The assessment analyzed the Spring Boot Petclinic application for cloud migration readiness and identified the following:

Key Findings:

* 8 cloud readiness issues requiring attention (1)
* 1 Java upgrade opportunity for modernization (2)

!IMAGE[module2-assessment-report-overview.png](instructions310381/module2-assessment-report-overview.png)

**Resolution Approach:** More than 50% of the identified issues can be automatically resolved through code and configuration updates using GitHub Copilot's built-in app modernization capabilities (3).

**Issue Prioritization:** Issues are categorized by urgency level to guide remediation efforts:

* Mandatory (Purple) - Critical issues that must be addressed before migration.
* Potential (Blue) - Performance and optimization opportunities.
* Optional (Gray) - Nice-to-have improvements that can be addressed later.

This prioritization framework ensures teams focus on blocking issues first while identifying opportunities for optimization and future enhancements.

### Review Specific Findings

Click on individual issues in the report to see detailed recommendations. In practice, you would review all recommendations and determine the set that aligns with your migration and modernization goals for the application.

For this lab, we will spend our time focusing on one modernization recommendation: updating the code to use modern authentication via Azure Database for PostgreSQL Flexible Server with Entra ID authentication.

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

When the migration task for PostgreSQL with Entra ID authentication begins to run, you will see a chat similar to this in the agent interface:

!IMAGE[module2-step13-migration-task-initialized.png](instructions310381/module2-step13-migration-task-initialized.png)

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

During these stages, you might be prompted to allow the **GitHub Copilot app modernization** extension to access GitHub. Allow it and select your user account when asked.

!IMAGE[allow-ghcp-cve.png](instructions310381/allow-ghcp-cve.png)

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

## Module 3: Generate Containerization Assets

**What You'll Do:** Use AI-powered containerization tools to create Docker and Kubernetes manifests for the modernized Spring Boot application.

**What You'll Learn:** How AI-powered tools can generate production-ready containerization assets, including optimized Dockerfiles and Kubernetes deployment manifests with proper health checks and service configurations.

---

### Install Containerization MCP Server

For the next steps we will use the [Containerization Assist MCP Server](https://www.npmjs.com/package/containerization-assist-mcp?activeTab=readme). Open a new terminal in VS Code:

1. Open a terminal and run:

	```bash
	cd ~/spring-petclinic
	npm install containerization-assist-mcp
	```

1. Configure VS Code to use the MCP server. Create `.vscode/mcp.json` inside of the `spring-petclinic` directory:

	```json
	{  
	  "servers": {
	    "containerization-assist": {
		  "command": "./node_modules/.bin/containerization-assist-mcp",
		  "args": ["start"],
		  "env": {
			"DOCKER_SOCKET": "/var/run/docker.sock",
			"LOG_LEVEL": "info"
		  }
		}
	  }
	}
	```
    
1. Restart VS Code to enable the Containerization Assist MCP  server in GitHub Copilot.

**Validation:** After restarting VS Code, you should see the Containerization Assist MCP Server available in the Configure Tools dialog:

!IMAGE[ca-mcp.png](instructions310381/ca-mcp.png)

### Generate Containerization Assets with AI

In the GitHub Copilot agent chat, use the following prompt to generate production-ready Docker and Kubernetes manifests:

```prompt
Help me containerize the application at ./src and generate Kubernetes deployment artifacts using Containerization Assist. Put all of the kubernetes files in a directory called k8s. 

PostgreSQL Configuration via Azure Service Connector:
- Reference secret: sc-pg-secret
- Map these secret keys to environment variables:
  - AZURE_POSTGRESQL_HOST
  - AZURE_POSTGRESQL_PORT
  - AZURE_POSTGRESQL_DATABASE
  - AZURE_POSTGRESQL_CLIENTID (map to both AZURE_CLIENT_ID and AZURE_MANAGED_IDENTITY_NAME)
  - AZURE_POSTGRESQL_USERNAME

Health Checks:
- Liveness probe: /actuator/health
- Readiness probe: /actuator/health

Also include:
- A LoadBalancer Service exposing port 80 (targeting container port 8080)
- Keep envFrom with secretRef to make all secret keys available in the pod
```

> [!note] To expedite your lab experience, you can allow the Containerization Assist MCP server to run on this Workspace
!IMAGE[ca-mcp-allow.png](instructions310381/ca-mcp-allow.png)


The Containerization Assist MCP Server will analyze your repository and generate:

- **Dockerfile**: Multi-stage build with optimized base image

- **Kubernetes Deployment**: With Azure workload identity, PostgreSQL secrets, health checks, and resource limits

- **Kubernetes Service**: LoadBalancer configuration for external access

**Expected Result**: Production-ready containerization assets in the `k8s/` directory.

===

## Module 4: Deploy to AKS

**What You'll Do:** Deploy the modernized application to AKS Automatic using Service Connector secrets for passwordless authentication with PostgreSQL.

**What You'll Learn:** Kubernetes deployment with workload identity, Service Connector integration, and testing deployed applications with Entra ID authentication.

---

> [!knowledge] **About AKS Automatic:** AKS Automatic is a new mode for Azure Kubernetes Service that provides an optimized and simplified Kubernetes experience. It offers automated cluster management, built-in security best practices, intelligent scaling, and pre-configured monitoring - making it ideal for teams who want to focus on applications rather than infrastructure management.



### Access AKS Service Connector and Retrieve PostgreSQL Configuration

Navigate to your AKS cluster in the Azure Portal and access the Service Connector blade to retrieve the PostgreSQL connection configuration.

1. Open a new tab in the Edge browser and navigate to +++https://portal.azure.com/+++

1. Sign in to Azure using your lab provided credentials available in the **Resources** tab.

1. In the search bar, type "petclinic-workshop-rg" and select the resource group that was created by the setup script

	!IMAGE[module5-step1-2-navigate-to-rg.png](instructions310381/module5-step1-2-navigate-to-rg.png)

1. In the resource group, locate your AKS cluster (it will have a name like `petclinic-workshop-aks-xxxxxx` where xxxxxx is a random suffix)

	!IMAGE[module5-step1-3-Find-AKS-Cluster.png](instructions310381/module5-step1-3-Find-AKS-Cluster.png)

1. Click on the AKS cluster name to open the cluster overview page.

1. In the left menu under "Settings", click on "Service Connector"

	!IMAGE[module5-step1-aks-service-connector-postgres-view.png](instructions310381/module5-step1-aks-service-connector-postgres-view.png)

1.  You'll see the service connection that was automatically created **PostgreSQL connection** with name "pg" connecting to your PostgreSQL flexible server.

1. Select the PostgreSQL connection row (the one with "DB for PostgreSQL flexible server") and click the "Sample code" button in the action bar

	!IMAGE[module5-step1-azure-service-connector-postgres.png](instructions310381/module5-step1-azure-service-connector-postgres.png)

### Retrieve PostgreSQL YAML Configuration

The Azure Portal will display a YAML snippet showing how to use the Service Connector secrets for PostgreSQL connectivity.

> [!note] 
> 1. Review YAML Snippet: The portal shows a sample deployment with workload identity configuration
> 2. Key Elements:
>   - Service account: `sc-account-d4157fc8-73b5-4a68-acf4-39c8f22db792`
>   - Secret reference: `sc-pg-secret`
>   - Workload identity label: `azure.workload.identity/use: "true"`

> [+] Service Connector YAML snippet
> 
> !IMAGE[module5-step2-azure-service-connector-yaml-snippet.png](instructions310381/module5-step2-azure-service-connector-yaml-snippet.png)

===

### Build and Push Container Image to ACR

Build the containerized application and push it to your Azure Container Registry:

1. From a terminal, login into Azure:

	```bash
	az login --use-device-code	
	```
	Open up Edge and navigate to +++https://microsoft.com/devicelogin+++. Once there, type in the code provided and follow through the login process.

	!IMAGE[az-login.png](instructions310381/az-login.png)

	>[!note] You might need to enter your Temporary Access Pass. This information is available in the **Resources** tab of your instructions.

	!IMAGE[az-cli-login.png](instructions310381/az-cli-login.png)

	Click on **Continue**

1. Lets create a file that will contain all of the environment variables you might need

	```bash
	# configure your environment
	cat <<EOF> ~/azure.env
	export RESOURCE_GROUP_NAME=myResourceGroup
	export AKS_CLUSTER_NAME=$(az aks list -o tsv --query [].name)
	export CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
	export CURRENT_USER_UPN=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")
	export CLUSTER_ID=$(az aks show -g ${RESOURCE_GROUP_NAME} -n ${AKS_CLUSTER_NAME} --query id -o tsv)
	export ACR_NAME=$(az acr list -o tsv --query [].name)
	export ACR_LOGIN_SERVER=$(az acr list -o tsv --query [].loginServer)
	EOF
	```
1. Load the environment variables:

	```bash
	source ~/azure.env
	```

	> [!tip] Now that we have saved the environment variables, you can always reload these variables later if needed by running source azure.env on this directory.

1. Login to ACR using Azure CLI

	```bash
	az acr login --name ${ACR_NAME}
	```

1. Build the Docker image

	```bash
	docker build -t petclinic:0.0.1 .
	```

1. Tag the image for ACR
	
	```bash
	docker tag petclinic:0.0.1 $ACR_LOGIN_SERVER/petclinic:0.0.1
	```

1. Push the image to ACR

	```bash
	docker push $ACR_LOGIN_SERVER/petclinic:0.0.1
	```

### Configure Azure RBAC Authentication for kubectl

Before deploying to AKS, you need to configure kubectl to use Azure RBAC authentication:

```bash
# add Admin to your user
az role assignment create --assignee "${CURRENT_USER_UPN}" --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "$CLUSTER_ID"

# Get AKS credentials (this downloads the kubeconfig)
az aks get-credentials --resource-group ${RESOURCE_GROUP_NAME} --name ${AKS_CLUSTER_NAME}

# Configure kubectl to use Azure RBAC authentication
kubelogin convert-kubeconfig --login azurecli

# Test AKS access
kubectl get pods
```

> [!note] The `kubelogin convert-kubeconfig --login azurecli` command configures kubectl to use Entra (Azure AD) authentication with the Azure RBAC roles assigned to your user account. This is required for AKS Automatic clusters with Azure RBAC enabled.


### Deploy to AKS

Apply the Kubernetes manifests to deploy the application:

1. Update the image name in your deployment manifest with your ACR login server. You can retrieve the name of your Azure Container Registry with this command:

	```bash
	echo $ACR_LOGIN_SERVER
	```

1. Apply the deployment manifest

	```bash
	kubectl apply -f k8s/petclinic.yaml
	```
1.  Monitor deployment status

	```bash
	kubectl get pods,services,deployments -w
	```

	It might take a minute for the AKS Automatic cluster to provision new nodes for the workload so it is normal to see your pods in a `Pending` state until the new nodes are available:

	```bash
	NAME                                    READY   STATUS              RESTARTS   AGE
	petclinic-deployment-5f9db48c65-qpb8l   0/1     Pending             0          2m2s
	petclinic-deployment-5f9db48c65-vqb8x   0/1     Pending             0          2m2s
	```

### Verify Deployment and Connectivity

Test the deployed application and verify Entra ID authentication:

1. Port forward to access the application

	```bash
	kubectl port-forward svc/petclinic-service 8080:80
	```
1. Test the application (in another terminal)

	```bash
	curl http://localhost:8080
	```

1. Check pod logs for successful database connections

	```bash
	kubectl logs -l app=petclinic
	```
1. Verify health endpoints

	```bash
	curl http://localhost:8080/actuator/health
	```

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

**Module 1 - Local Environment Setup**
- Set up Spring Boot PetClinic with PostgreSQL in Docker
- Validated local application functionality and database connectivity

**Module 2 - Application Modernization** 
- Used GitHub Copilot App Modernization to assess code for cloud readiness
- Migrated from basic PostgreSQL authentication to Azure PostgreSQL Flexible Server
- Implemented Microsoft Entra ID authentication with managed identity
- Applied automated code transformations for cloud-native patterns

**Module 3 - Containerization**
- Generated Docker containers using AI-powered tools
- Created optimized Kubernetes manifests with health checks and security best practices
- Built and pushed container images to Azure Container Registry

**Module 4 - Cloud Deployment**
- Deployed to AKS Automatic with enterprise-grade security
- Configured passwordless authentication using workload identity
- Integrated Azure Service Connector for seamless database connectivity
- Validated production deployment with secure authentication

---

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

===

## Help

If for some reason you've made here and your deployment did not work, your deployment file should ressemble this example.

> [!hint] Key areas to pay close attention to are:
> - `azure.workload.identity/use: "true"`
> - `serviceAccountName: sc-account-XXXX` this needs to reflect the service account created earlier during the PostgreSQL Service Connector
> - `image: <acr-login-server>/petclinic:0.0.1` this should point to your ACR and image created earlier.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: petclinic
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: petclinic
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic
  labels:
    app: petclinic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: petclinic
  template:
    metadata:
      labels:
        app: petclinic
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: sc-account-XXXXXXXXXX
      containers:
        - name: workload
          image: $ACR_LOGIN_SERVER/petclinic:0.0.1
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: postgres
            - name: AZURE_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.cloud.azure.credential.client-id
            - name: AZURE_MANAGED_IDENTITY_NAME
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.cloud.azure.credential.client-id
            - name: SPRING_CLOUD_AZURE_CREDENTIAL_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.cloud.azure.credential.client-id
            - name: SPRING_CLOUD_AZURE_CREDENTIAL_MANAGED_IDENTITY_ENABLED
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.cloud.azure.credential.managed-identity-enabled
            - name: SPRING_DATASOURCE_AZURE_PASSWORDLESS_ENABLED
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.datasource.azure.passwordless-enabled
            - name: SPRING_DATASOURCE_URL
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.datasource.url
            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: sc-pg-secret
                  key: spring.datasource.username
          envFrom:
            - secretRef:
                name: sc-pg-secret
          volumeMounts:
            - name: config-volume
              mountPath: /app/config
              readOnly: true
          ports:
            - name: http
              containerPort: 8080
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 30
            failureThreshold: 3
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
```
