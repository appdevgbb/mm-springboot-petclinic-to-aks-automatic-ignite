#!/bin/bash

# Spring Boot PetClinic Workshop - Quick Start Script
# This script sets up the entire workshop environment

set -e

echo "🚀 Spring Boot PetClinic Migration Workshop - Quick Start"
echo "========================================================"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."
command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI not found. Please install and login first."; exit 1; }
command -v java >/dev/null 2>&1 || { echo "❌ Java not found. Please install Java 17 or 21."; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo "❌ Maven not found. Please install Maven 3.8+."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Please install Docker Desktop."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found. Please install kubectl."; exit 1; }

echo "✅ All prerequisites are met!"
echo ""

# Check Azure login
if ! az account show > /dev/null 2>&1; then
    echo "🔐 Please login to Azure first:"
    echo "   az login"
    exit 1
fi

echo "✅ Azure login verified!"
echo ""

# Create src directory for the Spring Boot application
echo "📁 Creating src directory for Spring Boot application..."
if [ -d "src" ]; then
    echo "📁 src directory already exists. Removing..."
    rm -rf "src"
fi

mkdir -p "src"
echo "📁 Created src directory: src/"
echo ""

# Clone Spring Boot PetClinic into src directory
echo "📥 Cloning Spring Boot PetClinic repository into src/..."
cd "src"
git clone https://github.com/spring-projects/spring-petclinic.git .
echo "✅ Repository cloned successfully into src/!"
echo ""

# Start PostgreSQL container
echo "🐘 Starting PostgreSQL container..."
docker run --name petclinic-postgres \
  -e POSTGRES_DB=petclinic \
  -e POSTGRES_USER=petclinic \
  -e POSTGRES_PASSWORD=petclinic \
  -p 5432:5432 \
  -d postgres:15

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 15
echo "✅ PostgreSQL container is running!"
echo ""

# Configure local database connection
echo "⚙️  Configuring local database connection..."
cat > src/main/resources/application.properties << 'EOF'
spring.datasource.url=jdbc:postgresql://localhost:5432/petclinic
spring.datasource.username=petclinic
spring.datasource.password=petclinic
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=create-drop
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.show-sql=true
EOF
echo "✅ Local database configuration updated!"
echo ""

# Test local application
echo "🧪 Testing local application..."
echo "📦 Building application..."
mvn clean compile -q
echo "✅ Build successful!"

echo "🚀 Starting application (this will run in background)..."
nohup mvn spring-boot:run -Dspring-boot.run.arguments="--spring.messages.basename=messages/messages --spring.datasource.url=jdbc:postgresql://localhost/petclinic --spring.sql.init.mode=always --spring.sql.init.schema-locations=classpath:db/postgres/schema.sql --spring.sql.init.data-locations=classpath:db/postgres/data.sql --spring.jpa.hibernate.ddl-auto=none" > ../app.log 2>&1 &
APP_PID=$!

echo "⏳ Waiting for application to start..."
sleep 30

# Test the application
if curl -s http://localhost:8080 > /dev/null; then
    echo "✅ Application is running successfully at http://localhost:8080"
else
    echo "❌ Application failed to start. Check logs in app.log"
    kill $APP_PID 2>/dev/null || true
    exit 1
fi

cd ..
echo ""

echo "🎉 Workshop environment setup completed!"
echo ""
echo "📋 Next Steps:"
echo "   1. Your local PetClinic app is running at http://localhost:8080"
echo "   2. Open the project in VS Code: code src/"
echo "   3. Use GitHub Copilot App Modernization to upgrade the codebase"
echo "   4. Run the Azure infrastructure setup: ./scripts/setup-azure-infrastructure.sh"
echo "   5. Use Containerization Assist to generate Docker and K8s manifests"
echo "   6. Deploy to AKS and test the modernized application"
echo ""
echo "🧹 To clean up local resources:"
echo "   docker stop petclinic-postgres && docker rm petclinic-postgres"
echo "   kill $APP_PID"
echo ""
echo "🚀 Lets get to modernizing!"
