import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/main.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  testWidgets('signed-out providers see login instead of the dashboard',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const ProviderApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProviderMainContainer), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
