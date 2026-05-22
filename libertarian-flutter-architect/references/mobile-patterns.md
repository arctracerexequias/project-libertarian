# Flutter Architectural Patterns

This document defines the standard patterns for the mobile applications.

## 1. Directory Structure
```
lib/
├── screens/    - Full page widgets
├── widgets/    - Reusable UI components
├── controllers/- (Optional) Logic controllers
└── models/     - (Usually in shared_core)
```

## 2. Shared Core (`shared_core`)
Everything that is used by both Apps (Customer & Provider) MUST live here:
- **`AuthService`**: Handles login/register and token persistence.
- **`MarketplaceService`**: Handles job postings, bids, and marketplace logic.
- **`DispatchService`**: Handles GPS tracking and provider discovery.
- **`AppConfig`**: Centralized API URLs and keys.

## 3. Dio Interceptors
All services MUST use the shared interceptor to automatically inject the JWT:
```dart
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  },
));
```

## 4. Real-time Map Standards
- Use `flutter_map` with OpenStreetMap.
- Implement polling via `Timer.periodic` for GPS updates.
- Always include a "Location Toggle" in the Provider app to respect privacy and battery.
