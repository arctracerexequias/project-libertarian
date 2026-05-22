---
name: libertarian-flutter-architect
description: Expert guidance for developing Flutter mobile applications for the Libertarian Marketplace. Use this skill when building new screens, implementing real-time maps, or refactoring mobile logic. It ensures clean architecture, consistent styling, and proper integration with the backend via shared-core.
---

# Libertarian Flutter Architect

This skill ensures the mobile apps remain production-grade, modular, and consistent.

## Mobile Principles
- **Shared-First:** Any logic, model, or service that *could* be used by both apps must be placed in `shared_core`.
- **Stateless UI:** Keep screens lean; move API calls and complex logic into Services.
- **Real-time UX:** Prioritize smooth map transitions and live status updates (e.g., bid acceptance).

## Implementation Workflow
Follow the standards in [references/mobile-patterns.md](references/mobile-patterns.md).

1.  **Shared Service:** If adding a new feature (e.g., Reviews), implement the Service in `shared_core` first.
2.  **Screen Scaffolding:** Create the new screen in `lib/screens/` of the target app.
3.  **Widget Extraction:** Identify reusable UI parts and move them to `lib/widgets/`.
4.  **Gateway Check:** Ensure the service uses the correct `AppConfig.baseUrl` and handles 401 Unauthorized errors by redirecting to login.

## Real-time Requirements
- **Tracking:** Use `Geolocator` and `DispatchService` for provider location sync.
- **Messaging:** Use WebSockets (from `communication-service`) for chat rooms.
- **Polling:** Use `Timer` for non-critical live updates (e.g., nearby provider counts).
