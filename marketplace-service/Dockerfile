# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy shared library
COPY shared-contracts /app/shared-contracts

# Copy service code
COPY marketplace-service /app/marketplace-service
WORKDIR /app/marketplace-service

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/marketplace-service/main .
EXPOSE 8082
CMD ["./main"]
