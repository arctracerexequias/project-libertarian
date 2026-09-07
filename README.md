# Decentralized Service Marketplace Platform

A microservices platform under active development for multi-category service marketplaces (Home Repair, Personal Care, Automotive, Device Repair, and Appliance Repair).

## 🚀 Quick Start (Backend)

The entire backend ecosystem is containerized using Docker.

### Prerequisites
- Docker & Docker Compose

### Launching the Platform
```bash
cp .env.example .env
# Fill in the required independent secrets in .env first.
docker compose up --build
```

Test accounts are opt-in. Use `docker compose --profile dev up --build` and wait for `db-seed` to finish to create these verified development accounts:

| Role | Email | Password |
| --- | --- | --- |
| Customer | `customer1@odg.test` | `OdgTest123!` |
| Customer | `customer2@odg.test` | `OdgTest123!` |
| Service provider | `provider1@odg.test` | `OdgTest123!` |

The seed is idempotent, so restarting the stack does not create duplicate
accounts.

The services will be available at:
- **API Gateway:** `http://localhost:8080/api/v1`
- **Admin Dashboard:** `http://localhost:8080/api/v1/admin/dashboard/`

## 🏗 Microservices Architecture

- **api-gateway:** Central routing and reverse proxy (:8080).
- **identity-service:** Auth, JWT, KYC, and Profile management (:8081).
- **marketplace-service:** Job posting, Bidding engine, and Market insights (:8082).
- **communication-service:** Real-time WebSockets for job chat (:8083).
- **payment-service:** Hosted card checkout, payment authorization/capture, and refund reconciliation (:8084).
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
2. Run `flutter pub get`.
3. Run `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1` for an Android emulator. Use a reachable LAN URL for a physical device and HTTPS for release builds.

## 🛠 Tech Stack
- **Backend:** Go (Golang) + Gin-Gonic
- **Database:** PostgreSQL + PostGIS (Schema defined in `database/schema.sql`)
- **Real-time:** WebSockets
- **Maps:** Leaflet.js / flutter_map (OpenStreetMap)
- **Mobile:** Flutter (iOS/Android)
- **Infrastructure:** Docker / Docker Compose

## ⚖️ Marketplace Philosophy
Built to empower MSMEs through free-market efficiency, reputation-based trust, and minimal unnecessary platform intervention.

## Release and verification

Read [security and release notes](docs/security-and-release-notes.md) before upgrading an existing database or enabling online payments. Run `scripts/test-backend.sh` for Go tests; set `TEST_DATABASE_URL` to enable database regressions. Run `flutter test` in each mobile package.
