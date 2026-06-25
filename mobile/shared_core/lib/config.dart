/// ─────────────────────────────────────────────────────────────────────────
/// App Configuration
///
/// Switch [_env] to change the active environment:
///   'local'    → physical device on the same Wi-Fi network
///   'emulator' → Android emulator (10.0.2.2 reaches host machine)
///   'prod'     → production deployment (update [_prodHost] before release)
/// ─────────────────────────────────────────────────────────────────────────
class AppConfig {
  static const String _env = 'local'; // ← change this before building

  // ── Host addresses ───────────────────────────────────────────────────────
  static const String _localHost    = '192.168.1.55:8080';
  static const String _emulatorHost = '10.0.2.2:8080';
  static const String _prodHost     = 'api.your-domain.com'; // TODO: set before prod release

  // ── Derived URLs ─────────────────────────────────────────────────────────
  static String get _host {
    switch (_env) {
      case 'emulator': return _emulatorHost;
      case 'prod':     return _prodHost;
      default:         return _localHost; // 'local'
    }
  }

  static String get _scheme => _env == 'prod' ? 'https' : 'http';
  static String get _wsScheme => _env == 'prod' ? 'wss' : 'ws';

  /// Base URL for all REST API calls (used by Dio in NetworkService)
  static String get baseUrl => '$_scheme://$_host/api/v1';

  /// Base URL for WebSocket connections (used in ChatScreen)
  static String get wsBaseUrl => '$_wsScheme://$_host/api/v1';

  // ── Feature flags ────────────────────────────────────────────────────────
  /// Set to true to print HTTP request/response logs in debug builds
  static const bool enableNetworkLogs = true;

  /// Default job discovery radius in meters
  static const double defaultDiscoveryRadius = 5000.0;

  /// Max allowed dispatch radius in meters (matches backend cap)
  static const double maxDispatchRadius = 50000.0;
}
