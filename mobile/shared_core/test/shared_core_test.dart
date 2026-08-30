import 'package:flutter_test/flutter_test.dart';

import 'package:shared_core/shared_core.dart';

Map<String, dynamic> _jobJson({
  String? paymentMethod,
  String description = 'Repair the kitchen sink',
}) {
  return {
    'id': 'job-1',
    'customer_id': 'customer-1',
    'title': 'Sink repair',
    'description': description,
    'category': 'Home Repair',
    'status': 'PUBLISHED',
    'payment_method': paymentMethod,
    'created_at': '2026-08-30T00:00:00Z',
  };
}

void main() {
  test('recognizes an explicit cash payment method', () {
    final job = Job.fromJson(_jobJson(paymentMethod: 'CASH'));

    expect(job.isCashOnDelivery, isTrue);
  });

  test('recognizes cash payment on older description-only jobs', () {
    final json = _jobJson(
      description: 'Repair the kitchen sink\nPayment: Cash after service',
    )..remove('payment_method');

    final job = Job.fromJson(json);

    expect(job.isCashOnDelivery, isTrue);
  });
}
