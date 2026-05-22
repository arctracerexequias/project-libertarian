# Infrastructure and DevOps Standards

This document defines the standards for Docker, Database Migrations, and CI/CD.

## 1. Dockerfile Standard Template
Every microservice MUST use this multi-stage build pattern:
```dockerfile
# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY shared-contracts /app/shared-contracts
COPY {service-name} /app/{service-name}
WORKDIR /app/{service-name}
RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/{service-name}/main .
EXPOSE 8080
CMD ["./main"]
```

## 2. Docker Compose
- Always use root build context (`.`) to allow access to `shared-contracts`.
- Use `depends_on` with `service_completed_successfully` for `db-migrate`.
- Inject secrets via environment variables, never hardcode.

## 3. Database Migrations
- Use `golang-migrate`.
- All `up.sql` files must have a corresponding `down.sql`.
- Run migrations via a separate `db-migrate` container in Compose.
