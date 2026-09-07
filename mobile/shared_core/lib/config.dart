/// Build with --dart-define=API_BASE_URL=https://api.example.com/api/v1.
/// Release builds require HTTPS; local Android emulators default to the host.
class AppConfig {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api/v1');
  static String get wsBaseUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString();
  }

  static const bool enableNetworkLogs = bool.fromEnvironment('NETWORK_LOGS');
  static const double defaultDiscoveryRadius = 5000;
  static const double maxDispatchRadius = 50000;
}
