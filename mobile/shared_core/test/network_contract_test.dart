import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_core/boost_service.dart';
import 'package:shared_core/network_service.dart';

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  int status = 200;
  Map<String, dynamic> body = {};
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingAdapter adapter;
  late HttpClientAdapter original;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'test-token'});
    adapter = RecordingAdapter();
    original = NetworkService().dio.httpClientAdapter;
    NetworkService().dio.httpClientAdapter = adapter;
  });
  tearDown(() => NetworkService().dio.httpClientAdapter = original);

  test('checkout sends the job only and preserves pending status', () async {
    adapter.body = {
      'status': 'PENDING',
      'checkout_url': 'https://checkout.stripe.com/test'
    };
    final result = await PaymentService().initEscrow('job');
    expect(adapter.request!.path, '/payment/escrow/init');
    expect(adapter.request!.data, {'job_id': 'job'});
    expect(result!['status'], 'PENDING');
  });

  test('boost requests use the server weekly plan and correct toggle field',
      () async {
    expect(await BoostService().purchaseCoverageBoost(), isTrue);
    expect(adapter.request!.data, {'duration_days': 7});
    await BoostService().toggleCoverageBoost(false);
    expect(adapter.request!.data, {'active': false});
  });

  test('verification submits a request rather than marking the user verified',
      () async {
    adapter.status = 202;
    expect(await AuthService().requestVerification(), isTrue);
    expect(adapter.request!.path, '/identity/auth/verification/request');
    expect(adapter.request!.data, isNull);
  });

  test('chat retains message identity for reconciling persisted notifications',
      () {
    final message = ChatMessage.fromJson({
      'id': 'message-1',
      'job_id': 'job',
      'sender_id': 'SYSTEM',
      'content': 'JOB_CANCELLED',
      'created_at': '2026-09-07T00:00:00Z',
    });
    expect(message.id, 'message-1');
    expect(message.senderId, 'SYSTEM');
  });
}
