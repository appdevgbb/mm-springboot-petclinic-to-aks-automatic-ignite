# Troubleshooting: Azure AD Authentication Mismatch for PostgreSQL

## Problem Summary

**Symptom:** Pods in CrashLoopBackOff with error:
```
FATAL: Service principal oid mismatch for role "The oid in the security label [ca2d3f9c-...] does not match the appid [79bfdfb1-...] or oid [e9e1d347-...] in the token."
```

**Root Cause:** The PostgreSQL AAD user (`aad_pg`) security labels contain a different Managed Identity Object ID than what the Workload Identity is presenting in its token.

**The Fix:** Update the PostgreSQL security labels to match the correct Managed Identity Object ID

---

## Prerequisites

Before starting, prepare your environment variables:

```bash
# Copy the sample file
cp azure.env.sample azure.env

# Edit azure.env with your actual values
# Then source it
source azure.env
```

See `azure.env.sample` for all required variables.

---

## Key Concepts

- **Client ID**: The application ID of the managed identity (shown in service account annotation)
- **Object ID**: The principal ID in Azure AD (what PostgreSQL security labels need)
- **Security Labels**: PostgreSQL uses these to bind roles to Azure AD identities

---

## Quick Fix Steps

---

## Quick Fix Steps

### 1. Source Your Environment Variables

Create or source your `azure.env` file:

```bash
# Load environment variables
source azure.env

# azure.env should contain:
# RESOURCE_GROUP=petclinic-workshop-rg
# PG_SERVER_NAME=postgres-petclinic-py2t5evhiqdr4
# PG_DATABASE_NAME=petclinic
# PG_AAD_ADMIN_UPN=admin@MngEnv330367.onmicrosoft.com
# TENANT_ID=de060cb6-6b37-489b-8a6e-c078c6dbeb09
# SERVICE_ACCOUNT_NAME=sc-account-79bfdfb1-54f2-4b58-9bdf-5545c12b4793
```

Get the Managed Identity Client ID and Object ID:

```bash
# Get Client ID from service account
MI_CLIENT_ID=$(kubectl get sa $SERVICE_ACCOUNT_NAME \
  -o jsonpath='{.metadata.annotations.azure\.workload\.identity/client-id}')

# Get Object ID from Azure AD
MI_OBJECT_ID=$(az ad sp show --id $MI_CLIENT_ID --query id -o tsv)

echo "Client ID: $MI_CLIENT_ID"
echo "Object ID: $MI_OBJECT_ID"
```

### 2. Create SQL Script with Variable Substitution

Use heredoc to create the SQL script with your environment variables:

```bash
cat > fix_aad_labels.sql <<EOF
-- Check current (wrong) security labels
SELECT objoid::regrole AS role_name, provider, label 
FROM pg_shseclabel 
WHERE objoid::regrole::text = 'aad_pg';

-- Update to correct Object ID
SECURITY LABEL FOR "pgaadauth-int" ON ROLE aad_pg 
  IS 'type=service,oid=${MI_OBJECT_ID},tenant_id=${TENANT_ID}';

SECURITY LABEL FOR "pgaadauth" ON ROLE aad_pg 
  IS 'aadauth,oid=${MI_OBJECT_ID},type=service';

-- Verify update
SELECT objoid::regrole AS role_name, provider, label 
FROM pg_shseclabel 
WHERE objoid::regrole::text = 'aad_pg';

SELECT 'AAD_LABELS_UPDATED' AS status;
EOF

cat fix_aad_labels.sql  # Verify the substitution worked
```

### 3. Run SQL from Inside AKS (Recommended)

Create a ConfigMap with your SQL:

```bash
kubectl create configmap pg-fix-sql --from-file=fix_aad_labels.sql
```

Get an AAD access token:

```bash
ACCESS_TOKEN=$(az account get-access-token \
  --resource https://ossrdbms-aad.database.windows.net \
  --query accessToken -o tsv)
```

Create pod manifest using heredoc with variable substitution:

```bash
cat > psql-fix-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: psql-fix
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: psql
    image: postgres:15
    env:
    - name: PGHOST
      value: ${PG_SERVER_NAME}.postgres.database.azure.com
    - name: PGDATABASE
      value: ${PG_DATABASE_NAME}
    - name: PGUSER
      value: ${PG_AAD_ADMIN_UPN}
    - name: PGPASSWORD
      value: "${ACCESS_TOKEN}"
    command:
    - /bin/bash
    - -c
    - |
      echo "=== Fixing AAD Security Labels ==="
      psql "sslmode=require" -f /scripts/fix_aad_labels.sql
      echo "=== Done ==="
      sleep 60
    volumeMounts:
    - name: script
      mountPath: /scripts
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
    # Required by Azure Policy/Gatekeeper
    livenessProbe:
      exec:
        command: ["/bin/sh", "-c", "ps aux | grep -v grep | grep -q bash || exit 0"]
      initialDelaySeconds: 5
      periodSeconds: 10
    readinessProbe:
      exec:
        command: ["/bin/sh", "-c", "ps aux | grep -v grep | grep -q bash || exit 0"]
      initialDelaySeconds: 2
      periodSeconds: 5
  volumes:
  - name: script
    configMap:
      name: pg-fix-sql
EOF
```

Apply and check logs:

```bash
kubectl apply -f psql-fix-pod.yaml
sleep 10
kubectl logs psql-fix
```

### 4. Restart Your Deployment

```bash
kubectl rollout restart deployment petclinic-deployment
kubectl rollout status deployment petclinic-deployment
kubectl get pods -l app=petclinic
```

### 5. Cleanup

```bash
kubectl delete pod psql-fix
kubectl delete configmap pg-fix-sql
```

---

## Your Deployment YAML Should Look Like This

Key configuration in `petclinic-deployment-wi.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: petclinic-deployment
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"  # Enable Workload Identity
    spec:
      serviceAccountName: <your-service-account-name>  # Must have azure.workload.identity/client-id annotation
      containers:
      - name: petclinic
        image: <your-acr>.azurecr.io/petclinic:latest
        env:
        # Spring Boot PostgreSQL config
        - name: SPRING_PROFILES_ACTIVE
          value: "postgres"
        - name: SPRING_DATASOURCE_URL
          value: "jdbc:postgresql://$(AZURE_POSTGRESQL_HOST):$(AZURE_POSTGRESQL_PORT)/$(AZURE_POSTGRESQL_DATABASE)?sslmode=require&authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin"
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              name: sc-pg-secret
              key: AZURE_POSTGRESQL_USERNAME  # Should be "aad_pg"
        - name: SPRING_DATASOURCE_PASSWORD
          value: ""  # Empty for AAD auth
        # Azure Workload Identity
        - name: AZURE_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: sc-pg-secret
              key: AZURE_POSTGRESQL_CLIENTID
        # PostgreSQL connection details
        - name: AZURE_POSTGRESQL_HOST
          valueFrom:
            secretKeyRef:
              name: sc-pg-secret
              key: AZURE_POSTGRESQL_HOST
        - name: AZURE_POSTGRESQL_PORT
          valueFrom:
            secretKeyRef:
              name: sc-pg-secret
              key: AZURE_POSTGRESQL_PORT
        - name: AZURE_POSTGRESQL_DATABASE
          valueFrom:
            secretKeyRef:
              name: sc-pg-secret
              key: AZURE_POSTGRESQL_DATABASE
```

**Service Account** must have:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <your-service-account-name>
  annotations:
    azure.workload.identity/client-id: "<your-managed-identity-client-id>"
  labels:
    azure.workload.identity/use: "true"
```

**Secret** should contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sc-pg-secret
type: Opaque
data:
  AZURE_POSTGRESQL_HOST: <base64-encoded-server-fqdn>
  AZURE_POSTGRESQL_PORT: NTQzMg==  # 5432
  AZURE_POSTGRESQL_DATABASE: <base64-encoded-db-name>
  AZURE_POSTGRESQL_USERNAME: YWFkX3Bn  # "aad_pg"
  AZURE_POSTGRESQL_CLIENTID: <base64-encoded-client-id>
```

---

## PostgreSQL Initial Setup (For Fresh Deployments)

When creating the PostgreSQL AAD user initially, use heredoc with variables from `azure.env`:

```bash
# Source your environment first
source azure.env

# Get the Object ID
MI_CLIENT_ID=$(kubectl get sa $SERVICE_ACCOUNT_NAME \
  -o jsonpath='{.metadata.annotations.azure\.workload\.identity/client-id}')
MI_OBJECT_ID=$(az ad sp show --id $MI_CLIENT_ID --query id -o tsv)

# Create initial setup SQL script
cat > create_aad_user.sql <<EOF
-- Create role
CREATE ROLE aad_pg WITH LOGIN;

-- Set security labels with correct Object ID
SECURITY LABEL FOR "pgaadauth-int" ON ROLE aad_pg 
  IS 'type=service,oid=${MI_OBJECT_ID},tenant_id=${TENANT_ID}';

SECURITY LABEL FOR "pgaadauth" ON ROLE aad_pg 
  IS 'aadauth,oid=${MI_OBJECT_ID},type=service';

-- Grant permissions
GRANT CONNECT ON DATABASE ${PG_DATABASE_NAME} TO aad_pg;
GRANT USAGE, CREATE ON SCHEMA public TO aad_pg;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO aad_pg;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO aad_pg;

-- Future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO aad_pg;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO aad_pg;

SELECT 'AAD_USER_CREATED' AS status;
EOF

# Verify the script
cat create_aad_user.sql
```

Then execute this SQL using the same pod method shown in Step 3.

---

## Verification Commands

```bash
# Check pod status
kubectl get pods -l app=petclinic

# Check logs for errors
kubectl logs -l app=petclinic --tail=50 | grep -i "error\|fatal"

# Verify security labels from inside a pod (optional)
kubectl exec -it <petclinic-pod> -- psql "$SPRING_DATASOURCE_URL" -U aad_pg -c \
  "SELECT objoid::regrole, provider, label FROM pg_shseclabel WHERE objoid::regrole::text = 'aad_pg';"
```

---

## Prevention Checklist for Future Workshops

- [ ] Document both Client ID and Object ID of your Managed Identity when creating infrastructure
- [ ] Use the Object ID (not Client ID) when creating PostgreSQL AAD users
- [ ] Test the connection before deploying the application
- [ ] Include this troubleshooting guide in your workshop materials

---

## Summary

**The Problem:** PostgreSQL security labels had the wrong Object ID

**The Fix:** Update security labels using SQL executed from inside AKS cluster

**Key Files:**
1. SQL script with correct Object ID in security labels
2. Gatekeeper-compliant pod YAML to run the SQL
3. Deployment YAML with Workload Identity configuration

**Next time:** Create the PostgreSQL user with the correct Object ID from the beginning!
