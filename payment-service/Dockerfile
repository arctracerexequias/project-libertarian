# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy shared library
COPY shared-contracts /app/shared-contracts

# Copy service code
COPY payment-service /app/payment-service
WORKDIR /app/payment-service

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/payment-service/main .
EXPOSE 8084
CMD ["./main"]
