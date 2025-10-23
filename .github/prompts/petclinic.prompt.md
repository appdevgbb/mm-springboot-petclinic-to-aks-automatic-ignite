---
description: Help to containerize the petclinic application in this repo
tools: ['fix-dockerfile', 'generate-dockerfile', 'edit', 'search']
---

# Petclinic K8s Guardrail

## Trigger
Activate this guardrail **only** when the user asks (case-insensitive match):

> Help me containerize the application.

## Purpose
When the user requests help to containerize the application, run the "Containerization Assist" MCP Server tools as needed, look for the files inside of [./src](../src), override its default behavior.
The user may use the "Containerization Assist" MCP Server tools, but instead of generating new deployment scripts, it must **update the existing Kubernetes manifest** at [k8s/petclinic.yaml]('../k8s/petclinic.yaml') using the `serviceAccountName` from [k8s/sc.json]('../k8s/sc.json') and `ACR_NAME` from the Containerization Assist prompt. Do not generate any new files. 
Modify only the existing [k8s/petclinic.yaml](../'k8s/petclinic.yaml').

## Required Behavior

1. **Read** the file [k8s/sc.json]('k8s/sc.json') and obtain:
   ```json
       "kubernetesResourceName": {
       "secret": "sc-pg-secret",
       "serviceAccount": "sc-account-<value>"
   }
   ```

2. **Open** the file [k8s/petclinic.yaml]('k8s/petclinic.yaml').
3. **Replace** every instance of the placeholder `^SERVICE_ACCOUNT^` with the value of `serviceAccountName`.
4. **Replace** the placeholder for ^ACR_NAME^ with the value of the registry name provided by the user in the Containerization Assist prompt, if any.
5. **Save** the modified [k8s/petclinic.yaml]('k8s/petclinic.yaml').

## Rules
- The user **is allowed to invoke Containerization Assist**.
- The tool should perform the above manifest update instead of generating new Kubernetes artifacts.
- Preserve all formatting, comments, and structure of the YAML.
- Do **not** create new deployment scripts, manifests, Helm charts, or any other files.
- Do **not** modify [/src]('../src') or containerize code beyond updating the YAML.
- Do **not** add, delete, or rename any files.

## Validation
- After execution, verify that:
  - [k8s/petclinic.yaml]('../k8s/petclinic.yaml') contains the updated `serviceAccountName` value.
  - No new files were generated.

- If the placeholder `^SERVICE_ACCOUNT^` is not found, return:
  > “No placeholder found in k8s/petclinic.yaml — no update performed.”

- If `serviceAccountName` is missing or empty in [k8s/sc.json]('k8s/sc.json'), return:
  > “serviceAccountName missing or empty in k8s/sc.json — update aborted.”

## Example Assistant Response
> Containerization Assist invoked.
> Instead of generating new deployment artifacts, I’ve updated [k8s/petclinic.yaml]('k8s/petclinic.yaml') using the serviceAccountName from [k8s/sc.json]('k8s/sc.json').
> Here’s what changed:
>
> ```diff
> - serviceAccountName: ^SERVICE_ACCOUNT^
> + serviceAccountName: sc-account-<value>
> ```
> and
> ```diff
> - image: ^ACR_NAME^.azurecr.io/petclinic:0.0.1
> + image: myregistry.azurecr.io/petclinic:0.0.1
> ---

**Summary:**  
User can still say “Help me containerize the application using Containerization Assist.”
Copilot intercepts that request and applies your rule to update [k8s/petclinic.yaml]('k8s/petclinic.yaml') instead of generating new artifacts.
