---
name: libertarian-service-generator
description: Automation tool for scaffolding new microservices in the Libertarian Marketplace workspace. Use when the user wants to add a new feature that requires a separate backend service. It ensures the service follows the MVC/SOLID pattern and integrates with the Go Workspace.
---

# Libertarian Service Generator

This skill automates the creation of new Go microservices, ensuring they are instantly compliant with the platform's architectural standards.

## Automated Tasks
The included scaffolding script performs the following:
1.  **Directory Structure:** Creates `internal/domain`, `internal/repository`, `internal/service`, and `internal/handler`.
2.  **Boilerplate:** Generates `main.go`, `go.mod`, and a multi-stage `Dockerfile`.
3.  **Dependency Management:** Automatically links the local `shared-contracts` library.
4.  **Workspace Integration:** Adds the new service to the root `go.work` file.

## Usage

To scaffold a new service, run the following command from the project root:

```bash
node libertarian-service-generator/scripts/scaffold_service.cjs <service-name>
```

### Post-Scaffold Workflow
After running the script, the agent should:
1.  **Tidy Dependencies:** Navigate to the new directory and run `go mod tidy`.
2.  **Define Domain:** Start implementing business logic by defining interfaces in `internal/domain`.
3.  **Update Compose:** Add the service to `docker-compose.yml` and point it to the root build context.
4.  **Gateway Routing:** Add the proxy route in `api-gateway/main.go`.

## Best Practices
- **Service Naming:** Use hyphenated names (e.g., `notification-service`, `review-service`).
- **Statelessness:** Ensure the new service relies on the Gateway for authentication via the `X-User-Id` header.
