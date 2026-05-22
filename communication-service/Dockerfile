# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy shared library
COPY shared-contracts /app/shared-contracts

# Copy service code
COPY communication-service /app/communication-service
WORKDIR /app/communication-service

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/communication-service/main .
EXPOSE 8083
CMD ["./main"]
