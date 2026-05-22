---
name: libertarian-marketplace-builder
description: Expert guidance for building and scaling the Libertarian Service Marketplace. Use this skill when implementing new microservices, refactoring existing ones, or adding marketplace features (bidding, tracking, chat). It ensures adherence to the platform's layered (MVC/SOLID) architecture, security standards (Gateway Auth), and free-market philosophy.
---

# Libertarian Marketplace Builder

This skill codifies the architectural and philosophical standards of the platform.

## Core Philosophy
- **Free-Market Efficiency:** Prioritize voluntary transactions and decentralized operational flexibility.
- **Provider Empowerment:** Design features that give providers autonomy (e.g., counteroffers, schedule management).
- **Minimal Intervention:** The platform should be a facilitator, not a regulator.

## Architectural Standards
Follow the Layered Architecture pattern documented in [references/architecture.md](references/architecture.md).

1.  **Domain-Driven:** Always start by defining interfaces in the `domain` package.
2.  **Dependency Injection:** Never use global variables for database pools or configurations. Inject dependencies through constructors.
3.  **Shared Contracts:** Use `github.com/service-marketplace/shared-contracts` for:
    *   Database connection (`pkg/database`)
    *   Auth middleware/helpers (`pkg/middleware`)
4.  **Database Migrations:** All schema changes must be versioned in `database/migrations` using `golang-migrate`.

## Security Protocol
- **Gateway Validation:** JWTs are validated *only* at the API Gateway.
- **Identity Propagation:** Downstream services identify users via the `X-User-Id` header.
- **Secret Management:** Never hardcode secrets. Use `os.Getenv("JWT_SECRET")`.

## Testing Mandate
- **Service Layer Coverage:** Every new service feature must have a corresponding unit test in `internal/service`.
- **Mocking:** Use manual mock repositories (as seen in `identity-service`) to isolate business logic during tests.

## Workflow: Adding a New Service
1.  Initialize a new Go module.
2.  Add to the root `go.work` file.
3.  Link `shared-contracts` via `replace` in `go.mod`.
4.  Scaffold `internal/domain`, `internal/repository`, `internal/service`, and `internal/handler`.
5.  Implement logic starting from the Domain layer.
6.  Create a Dockerfile based on the project's standard template (multi-stage, copying `shared-contracts`).
7.  Register the service in `docker-compose.yml` and the `api-gateway`.
