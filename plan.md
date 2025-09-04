# Spring Boot PetClinic Migration & Modernization Workshop

## Workshop Overview
This 90-minute workshop demonstrates how to migrate and modernize the iconic Spring Boot PetClinic application to Azure using modern cloud-native technologies. Participants will experience the complete journey from local development to cloud deployment using Azure PostgreSQL Flexible Server, AKS Automatic, and the new Containerization Assist tool.

## Learning Objectives
- Clone and run the Spring Boot PetClinic app locally with PostgreSQL in a container
- Use GitHub Copilot App Modernization for Java to upgrade and modernize the codebase
- Migrate from local PostgreSQL to Azure PostgreSQL Flexible Server with Entra ID authentication
- Deploy to AKS Automatic using Containerization Assist for Docker and Kubernetes manifests
- Implement workload identity and service connector for secure database connectivity

## Prerequisites

| Tool/Service | Version/Details | Notes |
|--------------|-----------------|-------|
| Azure CLI | Latest | Must be logged in with `az login` |
| Java | 17 or 21 | OpenJDK or Oracle JDK |
| Maven | 3.8+ | Available in PATH |
| Docker Desktop | Latest | Running and accessible |
| VS Code | Latest | With Java Extension Pack |
| GitHub Copilot App Modernization | Latest | VSCode extension pack |
| kubectl | Latest | For local testing |
| Bash/Zsh shell | - | macOS or WSL2 on Windows |

## Workshop Structure

### Phase 1: Local Setup & Initial App (15 minutes)
1. Clone Spring Boot PetClinic repository
2. Run PostgreSQL in container
3. Test local application

### Phase 2: Code Modernization (20 minutes)
1. Use GitHub Copilot App Modernization for Java
2. Upgrade Spring Boot version
3. Update dependencies and configurations

### Phase 3: Azure Infrastructure (25 minutes)
1. Deploy Azure PostgreSQL Flexible Server
2. Create AKS Automatic cluster
3. Configure service connector with workload identity

### Phase 4: Containerization & Deployment (20 minutes)
1. Use Containerization Assist to generate Dockerfile and K8s manifests
2. Deploy to AKS Automatic
3. Test deployed application

### Phase 5: Cleanup & Wrap-up (10 minutes)
1. Clean up Azure resources
2. Workshop summary and next steps

## Detailed Workshop Steps

### Phase 1: Local Setup & Initial App

#### Step 1.1: Clone Repository
```bash
# Create workshop directory
mkdir petclinic-workshop && cd petclinic-workshop

# Clone the Spring Boot PetClinic repository
git clone https://github.com/spring-projects/spring-petclinic.git src
cd src
```

#### Step 1.2: Start PostgreSQL Container
```bash
# Start PostgreSQL container for local development
docker run --name petclinic-postgres \
  -e POSTGRES_DB=petclinic \
  -e POSTGRES_USER=petclinic \
  -e POSTGRES_PASSWORD=petclinic \
  -p 5432:5432 \
  -d postgres:15

# Wait for PostgreSQL to be ready
sleep 10
```

#### Step 1.3: Configure Local Database
```bash
# Update application.properties for local PostgreSQL
cat > src/main/resources/application.properties << 'EOF'
spring.datasource.url=jdbc:postgresql://localhost:5432/petclinic
spring.datasource.username=petclinic
spring.datasource.password=petclinic
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.show-sql=true
EOF
```

#### Step 1.4: Test Local Application
```bash
# Build and run the application
mvn clean compile
mvn spring-boot:run

# In another terminal, test the application
curl http://localhost:8080
# Should return HTML content from PetClinic
```

### Phase 2: Code Modernization

#### Step 2.1: Open in VS Code
```bash
# Open the project in VS Code
code .
```

#### Step 2.2: Use GitHub Copilot App Modernization
1. Open Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
2. Select "GitHub Copilot: Modernize Java Application"
3. Follow the guided modernization process:
   - Upgrade Spring Boot version
   - Update dependencies
   - Modernize Java features
   - Apply security updates

#### Step 2.3: Verify Modernization
```bash
# Check updated Spring Boot version
grep "spring-boot.version" pom.xml

# Build to ensure no compilation errors
mvn clean compile
```

### Phase 3: Azure Infrastructure

#### Step 3.1: Generate Random Suffix
```bash
# Generate 6-character alphanumeric suffix for PostgreSQL
POSTGRES_SUFFIX=$(openssl rand -hex 3)
echo "PostgreSQL suffix: $POSTGRES_SUFFIX"
```

#### Step 3.2: Run Infrastructure Setup Script
```bash
# Make script executable and run
chmod +x setup-azure-infrastructure.sh
./setup-azure-infrastructure.sh $POSTGRES_SUFFIX
```

**Note**: The `setup-azure-infrastructure.sh` script will be created separately and will:
- Create resource group
- Deploy Azure PostgreSQL Flexible Server
- Create AKS Automatic cluster
- Configure service connector with workload identity
- Output connection details

#### Step 3.3: Update Application Configuration
```bash
# Get PostgreSQL connection details from script output
# Update application.properties for Azure PostgreSQL
cat > src/main/resources/application-azure.properties << 'EOF'
spring.datasource.url=jdbc:postgresql://${POSTGRES_SERVER}.postgres.database.azure.com:5432/petclinic?sslmode=require
spring.datasource.username=${POSTGRES_USER}
spring.datasource.password=${POSTGRES_PASSWORD}
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
EOF
```

### Phase 4: Containerization & Deployment

#### Step 4.1: Use Containerization Assist
1. In VS Code, open Command Palette
2. Select "Containerization Assist: Generate Dockerfile and Kubernetes Manifests"
3. Follow the guided process to:
   - Generate optimized Dockerfile
   - Create Kubernetes deployment manifests
   - Configure health checks and resource limits

#### Step 4.2: Deploy to AKS
```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods
kubectl get services
```

#### Step 4.3: Test Deployed Application
```bash
# Port forward to local machine
kubectl port-forward svc/petclinic-service 8080:80

# Test the application
curl http://localhost:8080
# Should return HTML content from PetClinic running on AKS
```

### Phase 5: Cleanup & Wrap-up

#### Step 5.1: Clean Up Resources
```bash
# Delete entire resource group (this will clean up all resources)
az group delete --name petclinic-workshop-rg --yes --no-wait
```

#### Step 5.2: Stop Local PostgreSQL
```bash
# Stop and remove local PostgreSQL container
docker stop petclinic-postgres
docker rm petclinic-postgres
```

## Workshop Deliverables
- ✅ Locally running Spring Boot PetClinic with PostgreSQL container
- ✅ Modernized codebase using GitHub Copilot App Modernization
- ✅ Azure PostgreSQL Flexible Server with Entra ID authentication
- ✅ AKS Automatic cluster with workload identity
- ✅ Containerized application deployed and accessible via kubectl port-forward
- ✅ Service connector securely connecting AKS to PostgreSQL

## Next Steps
- Explore Azure Monitor for application insights
- Set up CI/CD pipeline with GitHub Actions
- Implement Azure Application Gateway for ingress
- Add Azure Key Vault for secrets management
- Scale application with AKS cluster autoscaler

## Troubleshooting Tips
- If PostgreSQL connection fails, check firewall rules and network security groups
- If AKS deployment fails, verify service principal permissions
- Use `kubectl logs` to debug application issues
- Check Azure portal for resource health and diagnostics

## Resource Naming Convention
- Resource Group: `petclinic-workshop-rg`
- AKS Cluster: `petclinic-workshop-aks`
- PostgreSQL Server: `petclinic-workshop-postgres-{SUFFIX}`
- Storage Account: `petclinicworkshopst`
- Container Registry: `petclinicworkshopacr`
- Managed Identity: `petclinic-workshop-identity`
