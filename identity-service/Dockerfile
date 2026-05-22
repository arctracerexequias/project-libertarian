# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy shared library
COPY shared-contracts /app/shared-contracts

# Copy service code
COPY identity-service /app/identity-service
WORKDIR /app/identity-service

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/identity-service/main .
EXPOSE 8081
CMD ["./main"]
