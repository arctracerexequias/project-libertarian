import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _biometricsEnabledKey = 'biometrics_enabled';

  Future<bool> isBiometricsSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print('Error checking biometric support: $e');
      return false;
    }
  }

  Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _biometricsEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: enabled ? 'true' : 'false');
  }

  Future<bool> authenticate(String reason) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern/passcode fallback
        ),
      );
      return didAuthenticate;
    } catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  Future<void> clearSettings() async {
    await _storage.delete(key: _biometricsEnabledKey);
  }
}
