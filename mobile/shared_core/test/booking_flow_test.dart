import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/create_job_screen.dart';
import 'package:shared_core/network_service.dart';
import 'package:shared_core/personal_service_form.dart';

class BookingAdapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(Map<String, dynamic>.from(options.data));
    final success = requests.length > 2;
    return ResponseBody.fromString(
        jsonEncode(success
            ? {
                ...options.data,
                'id': 'job-123',
                'customer_id': 'customer-1',
                'status': 'PUBLISHED',
                'created_at': DateTime.now().toUtc().toIso8601String(),
              }
            : {'error': 'temporarily unavailable'}),
        success ? 201 : 503,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('health answers are private and hidden answers are not submitted', () {
    final answers = <String, dynamic>{
      'gender': 'Female',
      'clients': '2',
      'home_service': 'Yes',
      'illness': 'Yes',
      'illness_details': 'Private health note',
      'recent': 'No',
      'recent_details': 'Old hidden answer'
    };
    expect(validatePersonalAnswers('Massage', answers), isNull);
    final public = personalAnswerSummary('Massage', answers, private: false);
    final private = personalAnswerSummary('Massage', answers, private: true);
    expect(public.values, isNot(contains('Private health note')));
    expect(private.values, contains('Private health note'));
    expect(private.values, isNot(contains('Old hidden answer')));
    answers['illness'] = 'No';
    expect(personalAnswerSummary('Massage', answers).values,
        isNot(contains('Private health note')));
  });

  test('babysitting requires an age for each child and conditional details',
      () {
    final answers = <String, dynamic>{
      'children': '2',
      'ages': '5',
      'illness': 'No'
    };
    expect(validatePersonalAnswers('Babysitting', answers), isNotNull);
    answers['ages'] = '0.5, 5';
    expect(validatePersonalAnswers('Babysitting', answers), isNull);
    answers['illness'] = 'Yes';
    expect(validatePersonalAnswers('Babysitting', answers), isNotNull);
    answers['illness_details'] = 'Medication schedule supplied';
    expect(validatePersonalAnswers('Babysitting', answers), isNull);
  });

  for (final service in personalServices.keys) {
    testWidgets('$service opens its intake on a small screen with large text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: CreateJobScreen(
              initialCategory: 'Personal Care > $service',
              onJobCreated: () {})));
      expect(find.byType(PersonalServiceForm), findsOneWidget);
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'landscaping posts totals and private contact, retries the same request',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'token'});
    final dio = NetworkService().dio;
    final original = dio.httpClientAdapter;
    final adapter = BookingAdapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = original);
    var created = 0;
    await tester.pumpWidget(MaterialApp(
        home: CreateJobScreen(
            initialCategory: 'Personal Care > Landscaping',
            onJobCreated: () => created++)));

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> enter(String label, String value) async {
      final field = find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.labelText == label ||
              w.decoration?.hintText == label));
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pump();
    }

    await enter('Number of landscapers', '2');
    await tap(find.text('Pruning / Trimming'));
    await tap(find.text('NEXT'));
    await enter('Home / Building / Unit Number', 'Unit 3 Private Street');
    await enter('Barangay', 'Poblacion');
    await enter('City / Town', 'Makati');
    await enter('Contact Number', '+63 917 123 4567');
    // A scheduled personal service must retain its date and time on review.
    await tap(find.text('Service Date: Today'));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(tomorrow);
    await tap(find.text('OK'));
    await tap(find.text('NEXT'));
    expect(find.text('Select the service date and required start / end times.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(find.byKey(const ValueKey('service-start-time')));
    await tap(find.text('OK'));
    // An explicit end is required when ASAP is unchecked.
    await tap(find.text('Set to ASAP'));
    await tap(find.text('NEXT'));
    expect(find.text('Select the service date and required start / end times.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tap(find.text('Set to ASAP'));
    await tap(find.text('NEXT'));
    await enter('Service request title', 'Trim the trees');
    await enter('Describe what you need done...',
        'Prune the trees and remove weeds from the garden.');
    await enter('Your offer amount (₱) for each worker', '600');
    await tap(find.text('NEXT'));
    expect(find.textContaining('₱1200.00 total offer'), findsOneWidget);
    await tap(find.text('Terms & Conditions (draft)'));
    expect(find.text('DRAFT — not yet effective'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('₱1200.00 total offer'), findsOneWidget);

    await tap(find.byType(DropdownButtonFormField<String>));
    await tap(find.text('Cash on Delivery (after service)').last);
    await tap(find.text('GRIND!'));
    expect(find.text('JOB REQUEST\nPOST FAILED!'), findsOneWidget);
    expect(created, 0);
    await tap(find.text('RETRY'));
    expect(find.text('JOB REQUEST\nPOST FAILED!'), findsOneWidget);
    await tap(find.text('BACK')); // Return to review, then inspect details.
    await tap(find.text('BACK'));
    await tap(find.text('NEXT'));
    await tap(find.text('GRIND!'));
    expect(find.text('JOB REQUEST\nSUCCESSFULLY\nPOSTED!'), findsOneWidget);
    expect(created, 1);
    expect(adapter.requests.length, 3);
    expect(adapter.requests.map((r) => r['request_id']).toSet(), hasLength(1));
    expect(
        adapter.requests[0]['request_id'], adapter.requests[1]['request_id']);
    final payload = adapter.requests.last;
    expect(payload['max_budget'], 1200);
    expect(payload['description'], isNot(contains('Private Street')));
    expect(payload['booking']['private']['contact'], '+63 917 123 4567');
    expect(
        payload['booking']['answers'].values, contains('Pruning / Trimming'));
    expect(payload['payment_method'], 'CASH');
    final scheduled = DateTime.parse(payload['scheduled_at']).toLocal();
    expect(DateUtils.isSameDay(scheduled, tomorrow), isTrue);
    expect(payload['is_emergency'], isFalse);
    expect(payload['booking']['end_asap'], isTrue);
    expect(tester.takeException(), isNull);
  });
}
