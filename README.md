# Decentralized Service Marketplace Platform

A production-grade microservices platform for multi-category service marketplaces (Home Repair, Personal Care, Automotive, Device Repair, and Appliance Repair).

## 🚀 Quick Start (Backend)

The entire backend ecosystem is containerized using Docker.

### Prerequisites
- Docker & Docker Compose

### Launching the Platform
```bash
docker-compose up --build
```

The services will be available at:
- **API Gateway:** `http://localhost:8080/api/v1`
- **Admin Dashboard:** `http://localhost:8080/api/v1/admin/dashboard/`

## 🏗 Microservices Architecture

- **api-gateway:** Central routing and reverse proxy (:8080).
- **identity-service:** Auth, JWT, KYC, and Profile management (:8081).
- **marketplace-service:** Job posting, Bidding engine, and Market insights (:8082).
- **communication-service:** Real-time WebSockets for job chat (:8083).
- **payment-service:** Escrow stubs and transaction history (:8084).
- **admin-service:** Platform metrics and operations dashboard (:8085).
- **dispatch-service:** Real-time GPS telemetry and tracking (:8086).

## 📱 Mobile Applications (Flutter)

Located in the `mobile/` directory.

### Structure
- `shared_core/`: Shared theme, models, and networking logic.
- `customer_app/`: Android & iOS app for service seekers.
- `provider_app/`: Android & iOS app for MSME service providers.

### Running the Apps
1. Navigate to either `customer_app` or `provider_app`.
2. Run `flutter run`.

## 🛠 Tech Stack
- **Backend:** Go (Golang) + Gin-Gonic
- **Database:** PostgreSQL + PostGIS (Schema defined in `database/schema.sql`)
- **Real-time:** WebSockets
- **Maps:** Leaflet.js / flutter_map (OpenStreetMap)
- **Mobile:** Flutter (iOS/Android)
- **Infrastructure:** Docker / Docker Compose

## ⚖️ Marketplace Philosophy
Built to empower MSMEs through free-market efficiency, reputation-based trust, and minimal unnecessary platform intervention.
