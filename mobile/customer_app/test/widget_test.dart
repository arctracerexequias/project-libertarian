import 'package:customer_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  testWidgets('customer home shows the primary service shortcuts',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('ODG'), findsOneWidget);
    expect(find.text('How can we help today?'), findsOneWidget);
    expect(find.text('Home Repair'), findsOneWidget);
    expect(find.text('Vehicle Repair'), findsOneWidget);
    expect(find.text('Personal Services'), findsOneWidget);
    expect(find.text('Job Requests'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
  });

  testWidgets('home repair shows functional repair choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeRepairScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Home Repair'), findsOneWidget);
    expect(find.text('Carpentry'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Structural'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Flooring'), findsOneWidget);
    expect(find.text('Roofing'), findsOneWidget);
    expect(find.text('Metalwork'), findsOneWidget);
    expect(find.text('Glasswork'), findsOneWidget);
    expect(find.text('Upholstery'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('HOME'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('every chosen home repair type uses the same booking pattern',
      (tester) async {
    const repairTypes = [
      'Carpentry',
      'Plumbing',
      'Structural',
      'Electrical',
      'Flooring',
      'Roofing',
      'Metalwork',
      'Glasswork',
      'Upholstery',
    ];

    for (final repairType in repairTypes) {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateJobScreen(
            key: ValueKey(repairType),
            initialCategory: 'Home Repair > $repairType',
            onJobCreated: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Home Repair'), findsOneWidget);
      expect(find.text(repairType), findsOneWidget);
      expect(find.text('Home / Building / Unit Number'), findsOneWidget);
      expect(find.text('Contact Number'), findsOneWidget);
      expect(find.text('Set to Immediately'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    }
  });

  testWidgets('vehicle repair shows selectable vehicle types', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          initialCategory: 'Automotive',
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Vehicle Repair'), findsOneWidget);
    expect(find.text('4 Wheels'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);
    expect(find.text('EV'), findsOneWidget);
    expect(find.text('Trucks'), findsOneWidget);
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('e-Bike'), findsOneWidget);

    await tester.tap(find.text('4 Wheels'));
    await tester.scrollUntilVisible(
      find.text('NEXT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('NEXT'));
    await tester.pump();

    expect(find.text('Brand'), findsOneWidget);
    expect(
        find.text('Willing to bring car to shop if needed?'), findsOneWidget);
  });

  testWidgets('appliance repair shows appliance and service choices',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          initialCategory: 'Appliance Repair',
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Appliance Repair'), findsOneWidget);
    expect(find.text('HVAC'), findsOneWidget);
    expect(find.text('Refrigerator'), findsOneWidget);
    expect(find.text('Stove / Oven'), findsOneWidget);
    expect(find.text('Electric Fan'), findsOneWidget);
    expect(find.text('Washing Machine / Dryer'), findsOneWidget);
    expect(find.text('Television'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Electric Fan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Electric Fan'));
    await tester.scrollUntilVisible(
      find.text('NEXT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('NEXT'));
    await tester.pump();

    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('Model (optional)'), findsOneWidget);
    expect(find.text('Do you require Home Service?'), findsOneWidget);
  });

  testWidgets('appliance category screen matches the six repair shortcuts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ApplianceRepairScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Appliance Repair'), findsOneWidget);
    expect(find.text('HVAC'), findsOneWidget);
    expect(find.text('Refrigerator'), findsOneWidget);
    expect(find.text('Stove / Oven'), findsOneWidget);
    expect(find.text('Electric Fan'), findsOneWidget);
    expect(find.text('Washing Machine / Dryer'), findsOneWidget);
    expect(find.text('Television'), findsOneWidget);
  });

  testWidgets('chosen appliance starts on brand and service details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          initialCategory: 'Appliance Repair > Electric Fan',
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Electric Fan'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('Model (optional)'), findsOneWidget);
    expect(find.text('Do you require Home Service?'), findsOneWidget);
  });

  testWidgets('device category screen shows all device shortcuts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceRepairScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Device Repair'), findsOneWidget);
    expect(find.text('Mobile Phone'), findsOneWidget);
    expect(find.text('Tablet'), findsOneWidget);
    expect(find.text('Laptop'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Sound System'), findsOneWidget);
    expect(find.text('Peripherals'), findsOneWidget);
    expect(find.text('Digital Camera'), findsOneWidget);
    expect(find.text('Drone'), findsOneWidget);
  });

  testWidgets('chosen device starts on brand and service details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          initialCategory: 'Device Repair > Tablet',
          onJobCreated: () {},
        ),
      ),
    );

    expect(find.text('Device Repair'), findsOneWidget);
    expect(find.text('Tablet'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Do you require Home Service?'), findsOneWidget);
  });
}
