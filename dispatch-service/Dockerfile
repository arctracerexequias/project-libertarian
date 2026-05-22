# Build Stage
FROM golang:1.25-alpine AS builder
WORKDIR /app

# Copy shared library
COPY shared-contracts /app/shared-contracts

# Copy service code
COPY dispatch-service /app/dispatch-service
WORKDIR /app/dispatch-service

RUN go mod download
RUN go build -o main .

# Run Stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/dispatch-service/main .
EXPOSE 8086
CMD ["./main"]
