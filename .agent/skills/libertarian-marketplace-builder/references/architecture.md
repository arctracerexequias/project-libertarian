# Layered Architecture Patterns (MVC/SOLID)

This document provides the standard patterns for building services in the Libertarian Marketplace.

## 1. Domain Layer (`internal/domain/`)
Define interfaces and data models. **No external dependencies** (except context or time).

```go
type Entity struct { ... }

type Repository interface {
    Get(ctx, id) (*Entity, error)
}

type Service interface {
    Process(ctx, req) error
}
```

## 2. Repository Layer (`internal/repository/postgres/`)
Implement the Repository interface using `pgxpool`. Focus strictly on SQL.

```go
type repo struct { db *pgxpool.Pool }

func NewRepository(db *pgxpool.Pool) domain.Repository {
    return &repo{db}
}
```

## 3. Service Layer (`internal/service/`)
Implement business logic. Inject the Repository interface. Use mocks for testing.

```go
type service struct { repo domain.Repository }

func NewService(repo domain.Repository) domain.Service {
    return &service{repo}
}
```

## 4. Handler Layer (`internal/handler/http/`)
Gin controllers. Inject the Service interface. Handle HTTP translations.

```go
type Handler struct { svc domain.Service }

func (h *Handler) HandleRequest(c *gin.Context) {
    userID := middleware.GetUserID(c) // From shared-contracts
    // ...
}
```

## 5. Main Entry (`main.go`)
Wiring and Dependency Injection.

1. Connect DB via `database.ConnectPostgres`.
2. Instantiate Repo -> Service -> Handler.
3. Register routes.
