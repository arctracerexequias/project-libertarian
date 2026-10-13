import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_core/create_job_screen.dart';

class TestLocation extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  int fixes = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    fixes++;
    return Position(
        latitude: 14.55,
        longitude: 121.02,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);
  }
}

class TestGeocoding extends GeocodingPlatform {
  List<Placemark> places = [
    const Placemark(
        street: '123 Sampaguita Street',
        subLocality: 'Poblacion',
        locality: 'Makati')
  ];
  Completer<List<Placemark>>? pending;
  bool fail = false;
  LatLng? coordinates;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
      double lat, double lng) async {
    coordinates = LatLng(lat, lng);
    if (fail) throw Exception('Offline');
    return pending == null ? places : await pending!.future;
  }
}

void main() {
  late TestLocation location;
  late TestGeocoding geocoding;
  setUp(() {
    final originalLocation = GeolocatorPlatform.instance;
    final originalGeocoding = GeocodingPlatform.instance ?? TestGeocoding();
    location = TestLocation();
    geocoding = TestGeocoding();
    GeolocatorPlatform.instance = location;
    GeocodingPlatform.instance = geocoding;
    addTearDown(() {
      GeolocatorPlatform.instance = originalLocation;
      GeocodingPlatform.instance = originalGeocoding;
    });
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CreateJobScreen(
      initialLocation: const LatLng(1, 2),
      onJobCreated: () {},
    )));
  }

  Future<void> locate(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();
  }

  testWidgets('fills visible address fields using a fresh fix on every tap',
      (tester) async {
    await open(tester);
    await locate(tester);
    expect(location.fixes, 1);
    expect(geocoding.coordinates, const LatLng(14.55, 121.02));
    expect(find.text('123 Sampaguita Street'), findsOneWidget);
    expect(find.text('Poblacion'), findsOneWidget);
    expect(find.text('Makati'), findsOneWidget);
    geocoding.places = [
      const Placemark(street: '456 New Street', locality: 'Pasig')
    ];
    await locate(tester);
    expect(location.fixes, 2);
    expect(find.text('456 New Street'), findsOneWidget);
    expect(find.text('Pasig'), findsOneWidget);
    expect(find.text('Poblacion'), findsNothing);
  });

  for (final reason in [
    'disabled',
    'denied',
    'permanent',
    'offline',
    'empty'
  ]) {
    testWidgets('$reason lookup preserves the manually entered address',
        (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'My unit address');
      if (reason == 'disabled') location.enabled = false;
      if (reason == 'denied') location.permission = LocationPermission.denied;
      if (reason == 'permanent') {
        location.permission = LocationPermission.deniedForever;
      }
      if (reason == 'offline') geocoding.fail = true;
      if (reason == 'empty') geocoding.places = [];
      await locate(tester);
      expect(find.text('My unit address'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
          tester
              .widget<IconButton>(find.byWidgetPredicate((w) =>
                  w is IconButton && w.tooltip == 'Use current location'))
              .onPressed,
          isNotNull);
      if (['disabled', 'denied', 'permanent'].contains(reason)) {
        expect(location.fixes, 0);
      }
    });
  }

  testWidgets(
      'loading prevents duplicate requests and survives closing the screen',
      (tester) async {
    await open(tester);
    geocoding.pending = Completer<List<Placemark>>();
    await tester.tap(find.byTooltip('Use current location'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Use current location'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    geocoding.pending!.complete(geocoding.places);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
