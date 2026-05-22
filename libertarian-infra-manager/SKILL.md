---
name: libertarian-infra-manager
description: Expert guidance for managing the infrastructure, Docker environment, and database migrations of the Libertarian Marketplace. Use this skill when updating docker-compose, adding new migrations, or optimizing the build process.
---

# Libertarian Infrastructure Manager

This skill ensures the platform's deployment environment is secure, scalable, and automated.

## DevOps Principles
- **Immutable Infrastructure:** Containers should be stateless and easily replaceable.
- **Automated Schema Changes:** Never apply SQL manually; always use versioned migrations.
- **Root-Context Builds:** Maintain the root directory as the source of truth for all service builds to support local shared dependencies.

## Key Workflows
Follow the standards in [references/devops-standards.md](references/devops-standards.md).

1.  **New Migration:** Create versioned files in `database/migrations/`.
2.  **Service Deployment:** Update `docker-compose.yml` following the "Root-Context" pattern.
3.  **Local Dev Setup:** Ensure `go.work` is used for local module resolution.

## Environment Standards
- **DB:** PostGIS extension must be active.
- **Auth:** `JWT_SECRET` must be present in every auth-dependent service.
- **Stripe:** `STRIPE_SECRET_KEY` must be injected into `payment-service`.
