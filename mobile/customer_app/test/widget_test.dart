import 'package:customer_app/screens/home_screen.dart';
import 'package:customer_app/main.dart' show CustomerBottomMenu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

void main() {
  Widget constrainedApp(Widget home) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.5),
        ),
        child: child!,
      ),
      home: home,
    );
  }

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

  testWidgets('customer shell uses the four-item reference bottom menu',
      (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CustomerBottomMenu(
            selectedIndex: 0,
            onSelected: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);

    await tester.tap(find.text('Help'));
    expect(selected, 3);
  });

  testWidgets('customer homepage fits without normal scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(constrainedApp(const HomeScreen()));
    await tester.pump();

    expect(find.text('Save 10% on your next service'), findsOneWidget);
    expect(find.text('View available promos'), findsOneWidget);
    expect(find.text('Be a Service Provider!'), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
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
      find.text('Landscaping'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Painting'), findsOneWidget);
    expect(find.text('Locksmith'), findsOneWidget);
    expect(find.text('Masonry'), findsOneWidget);
    expect(find.text('Landscaping'), findsOneWidget);
  });

  testWidgets('personal services shows every selectable subcategory',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalServicesScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );

    const services = [
      'Barber',
      'Manicure & Pedicure',
      'Hair Styling, Coloring & Care',
      'Massage',
      'Elderly Care',
      'Child Care',
      'Physical Therapy',
      'Occupational Therapy',
      'Tutorial Services',
      'House Keeping',
      'Pet Grooming',
      'Laundry & Ironing',
    ];
    for (final service in services) {
      final visibleLabel =
          service == 'Occupational Therapy' ? 'Occupational\nTherapy' : service;
      await tester.scrollUntilVisible(
        find.text(visibleLabel),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(visibleLabel), findsOneWidget);
    }
  });

  testWidgets('occupational therapy uses a balanced two-line label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalServicesScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Occupational\nTherapy'));
    expect(label.data, 'Occupational\nTherapy');
    expect(label.maxLines, 2);
    expect(label.softWrap, isFalse);
    expect(label.semanticsLabel, 'Occupational Therapy');
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification bell opens notifications and clears unread badge',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Welcome to ODG'), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long service labels stay complete and naturally wrapped',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PersonalServicesScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );
    final personalLabel = tester.widget<Text>(
      find.text('Hair Styling, Coloring & Care'),
    );
    expect(personalLabel.maxLines, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateJobScreen(
          initialCategory: 'Appliance Repair',
          onJobCreated: () {},
        ),
      ),
    );
    final applianceLabel = tester.widget<Text>(
      find.text('Washer & Dryer'),
    );
    expect(applianceLabel.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long single-word service labels stay on one line',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeRepairScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );
    final landscaping = tester.widget<Text>(
      find.text('Landscaping'),
    );
    expect(landscaping.maxLines, 1);
    expect(landscaping.softWrap, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: ApplianceRepairScreen(
          initialLocation: null,
          onJobCreated: () {},
        ),
      ),
    );
    final refrigerator = tester.widget<Text>(
      find.text('Refrigerator'),
    );
    expect(refrigerator.maxLines, 1);
    expect(refrigerator.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every chosen personal service uses the same booking pattern',
      (tester) async {
    const services = [
      'Barber',
      'Manicure & Pedicure',
      'Hair Styling, Coloring & Care',
      'Massage',
      'Elderly Care',
      'Child Care',
      'Physical Therapy',
      'Occupational Therapy',
      'Tutorial Services',
      'House Keeping',
      'Pet Grooming',
      'Laundry & Ironing',
    ];

    for (final service in services) {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateJobScreen(
            key: ValueKey(service),
            initialCategory: 'Personal Care > $service',
            onJobCreated: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Personal Services'), findsOneWidget);
      expect(find.text(service), findsOneWidget);
      expect(find.text('Home / Building / Unit Number'), findsOneWidget);
      expect(find.text('Contact Number'), findsOneWidget);
      expect(find.text('Set to Immediately'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    }
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
    expect(find.text('Stove & Oven'), findsOneWidget);
    expect(find.text('Electric Fan'), findsOneWidget);
    expect(find.text('Washer & Dryer'), findsOneWidget);
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
    expect(find.text('Stove & Oven'), findsOneWidget);
    expect(find.text('Electric Fan'), findsOneWidget);
    expect(find.text('Washer & Dryer'), findsOneWidget);
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

  testWidgets('redesigned screens do not overflow on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final screens = <Widget>[
      const HomeScreen(),
      HomeRepairScreen(initialLocation: null, onJobCreated: () {}),
      PersonalServicesScreen(initialLocation: null, onJobCreated: () {}),
      ApplianceRepairScreen(initialLocation: null, onJobCreated: () {}),
      DeviceRepairScreen(initialLocation: null, onJobCreated: () {}),
      CreateJobScreen(
        initialCategory: 'Automotive',
        onJobCreated: () {},
      ),
      CreateJobScreen(
        initialCategory: 'Home Repair > Carpentry',
        onJobCreated: () {},
      ),
    ];

    for (var index = 0; index < screens.length; index++) {
      await tester.pumpWidget(
        constrainedApp(
            KeyedSubtree(key: ValueKey(index), child: screens[index])),
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'screen $index overflowed');
    }
  });
}
