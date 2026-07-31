import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_core/shared_core.dart';

const _brandBlue = Color(0xFF006996);
const _brandBlueDark = Color(0xFF00577D);
const _brandRed = Color(0xFFFF403D);
const _pageBackground = Color(0xFFFDFDFD);

class HomeScreen extends StatefulWidget {
  final ValueNotifier<int>? historyRefresh;

  const HomeScreen({super.key, this.historyRefresh});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dispatchService = DispatchService();
  LatLng? _currentLocation;

  static const _services = <_ServiceShortcut>[
    _ServiceShortcut('Home Repair', Icons.home_rounded, 'Home Repair'),
    _ServiceShortcut('Vehicle Repair', Icons.car_repair_rounded, 'Automotive'),
    _ServiceShortcut(
        'Personal Services', Icons.volunteer_activism_rounded, 'Personal Care'),
    _ServiceShortcut('Appliance Repair', Icons.tv_rounded, 'Appliance Repair'),
    _ServiceShortcut(
        'Device Repair', Icons.phone_android_rounded, 'Device Repair'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final position = await _dispatchService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() =>
          _currentLocation = LatLng(position.latitude, position.longitude));
    }
  }

  Future<void> _openJobForm({String? category}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          onJobCreated: () {
            final signal = widget.historyRefresh;
            if (signal != null) signal.value++;
          },
          initialLocation: _currentLocation,
          initialCategory: category,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerHistoryScreen()),
    );
  }

  void _openPromos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPromosScreen(onUsePromo: _openJobForm),
      ),
    );
  }

  void _openHomeRepair() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeRepairScreen(
          initialLocation: _currentLocation,
          onJobCreated: () {
            final signal = widget.historyRefresh;
            if (signal != null) signal.value++;
          },
        ),
      ),
    );
  }

  void _openApplianceRepair() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplianceRepairScreen(
          initialLocation: _currentLocation,
          onJobCreated: () {
            final signal = widget.historyRefresh;
            if (signal != null) signal.value++;
          },
        ),
      ),
    );
  }

  void _openPersonalServices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalServicesScreen(
          initialLocation: _currentLocation,
          onJobCreated: () {
            final signal = widget.historyRefresh;
            if (signal != null) signal.value++;
          },
        ),
      ),
    );
  }

  void _openDeviceRepair() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceRepairScreen(
          initialLocation: _currentLocation,
          onJobCreated: () {
            final signal = widget.historyRefresh;
            if (signal != null) signal.value++;
          },
        ),
      ),
    );
  }

  void _openRewards() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerRewardsScreen()),
    );
  }

  Future<void> _referFriend() async {
    const message =
        'Try ODG for trusted home, vehicle, device, and personal services. '
        'Join using my referral code ODG-FRIEND.';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral message copied. Share it with a friend!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _registerAsProvider() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen(role: 'provider')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: _brandBlue,
          onRefresh: _loadLocation,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 16, horizontalPadding, 28),
                sliver: SliverList.list(
                  children: [
                    _HomeHeader(onNotificationsTap: _openHistory),
                    const SizedBox(height: 34),
                    const Text(
                      'How can we help today?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _brandBlue,
                        fontFamily: 'serif',
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 22),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 9,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: .86,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 14,
                      ),
                      itemBuilder: (context, index) {
                        if (index < _services.length) {
                          final service = _services[index];
                          return _ActionTile(
                            label: service.label,
                            icon: service.icon,
                            onTap: service.category == 'Home Repair'
                                ? _openHomeRepair
                                : service.category == 'Personal Care'
                                    ? _openPersonalServices
                                    : service.category == 'Appliance Repair'
                                        ? _openApplianceRepair
                                        : service.category == 'Device Repair'
                                            ? _openDeviceRepair
                                            : () => _openJobForm(
                                                category: service.category),
                          );
                        }

                        final extras = [
                          _ExtraShortcut(
                            'Job Requests',
                            Icons.handyman_rounded,
                            () => _openJobForm(),
                          ),
                          _ExtraShortcut(
                            'Promos',
                            Icons.percent_rounded,
                            _openPromos,
                          ),
                          _ExtraShortcut(
                            'Refer Us!',
                            Icons.forum_rounded,
                            _referFriend,
                          ),
                          _ExtraShortcut(
                            'Rewards',
                            Icons.diamond_rounded,
                            _openRewards,
                          ),
                        ];
                        final extra = extras[index - _services.length];
                        return _ActionTile(
                          label: extra.label,
                          icon: extra.icon,
                          onTap: extra.onTap,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _AdSpace(onTap: _openPromos),
                    const SizedBox(height: 20),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Skilled Enough? ',
                            style: TextStyle(
                                color: Color(0xFF6666FF), fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _registerAsProvider,
                            child: const Text(
                              'Be a Service Provider!',
                              style: TextStyle(
                                color: _brandBlueDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: _brandBlueDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onNotificationsTap;

  const _HomeHeader({required this.onNotificationsTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'ODG',
          style: TextStyle(
            color: _brandBlue,
            fontFamily: 'serif',
            fontWeight: FontWeight.w900,
            fontSize: 36,
            letterSpacing: -1.5,
          ),
        ),
        Semantics(
          button: true,
          label: 'Notifications, 1 unread',
          child: InkResponse(
            radius: 28,
            onTap: onNotificationsTap,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.notifications_rounded,
                        color: _brandBlue, size: 38),
                  ),
                  Positioned(
                    right: -2,
                    top: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: _brandRed,
                      child: Text('1',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(icon, size: 64, color: _brandBlue),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: _brandBlueDark,
                  fontFamily: 'serif',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdSpace extends StatelessWidget {
  final VoidCallback onTap;

  const _AdSpace({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 126,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF777777), width: 4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Save 10% on your next service',
              style: TextStyle(
                color: Color(0xFF6666FF),
                fontFamily: 'serif',
                fontSize: 20,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'View available promos',
              style: TextStyle(
                color: _brandBlueDark,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerHistoryScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshSignal;

  const CustomerHistoryScreen({super.key, this.refreshSignal});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  final _marketplaceService = MarketplaceService();
  late Future<List<Job>> _jobs;

  @override
  void initState() {
    super.initState();
    _jobs = _marketplaceService.getJobs();
    widget.refreshSignal?.addListener(_handleExternalRefresh);
  }

  @override
  void didUpdateWidget(covariant CustomerHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_handleExternalRefresh);
      widget.refreshSignal?.addListener(_handleExternalRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleExternalRefresh);
    super.dispose();
  }

  void _handleExternalRefresh() {
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _jobs = _marketplaceService.getJobs());
    await _jobs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(title: const Text('Service History')),
      body: FutureBuilder<List<Job>>(
        future: _jobs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.assignment_outlined, size: 64, color: _brandBlue),
                  SizedBox(height: 16),
                  Text('No service requests yet.', textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE4F3F8),
                      child: Icon(Icons.handyman_rounded, color: _brandBlue),
                    ),
                    title: Text(job.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(job.status.name.toUpperCase()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => JobDetailScreen(job: job)),
                      );
                      _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class DeviceRepairScreen extends StatelessWidget {
  final LatLng? initialLocation;
  final VoidCallback onJobCreated;

  const DeviceRepairScreen({
    super.key,
    required this.initialLocation,
    required this.onJobCreated,
  });

  static const _devices = <_RepairType>[
    _RepairType('Mobile Phone', Icons.phone_android_rounded),
    _RepairType('Tablet', Icons.tablet_android_rounded),
    _RepairType('Laptop', Icons.laptop_rounded),
    _RepairType('Computer', Icons.desktop_windows_rounded),
    _RepairType('Sound System', Icons.music_note_rounded),
    _RepairType('Peripherals', Icons.mouse_rounded),
    _RepairType('Digital Camera', Icons.photo_camera_rounded),
    _RepairType('Drone', Icons.flight_rounded),
  ];

  void _openBooking(BuildContext context, String device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          initialLocation: initialLocation,
          initialCategory: 'Device Repair > $device',
          onJobCreated: onJobCreated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 18.0 : 34.0;
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 28, horizontalPadding, 34),
              sliver: SliverList.list(
                children: [
                  const _FiveStepProgress(
                    semanticLabel:
                        'Device booking step 1 of 5: choose a device',
                  ),
                  const SizedBox(height: 46),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_android_rounded,
                          color: _brandBlue, size: 52),
                      SizedBox(width: 12),
                      Text(
                        'Device Repair',
                        style: TextStyle(
                          color: _brandBlueDark,
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 46),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _devices.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: .78,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 22,
                    ),
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _ActionTile(
                        label: device.label,
                        icon: device.icon,
                        onTap: () => _openBooking(context, device.label),
                      );
                    },
                  ),
                  const SizedBox(height: 52),
                  _AdSpace(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerPromosScreen(
                          onUsePromo: () => _openBooking(context, 'Tablet'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      label: const Text(
                        'HOME',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApplianceRepairScreen extends StatelessWidget {
  final LatLng? initialLocation;
  final VoidCallback onJobCreated;

  const ApplianceRepairScreen({
    super.key,
    required this.initialLocation,
    required this.onJobCreated,
  });

  static const _appliances = <_RepairType>[
    _RepairType('HVAC', Icons.ac_unit_rounded),
    _RepairType('Refrigerator', Icons.kitchen_rounded),
    _RepairType('Stove / Oven', Icons.local_fire_department_rounded),
    _RepairType('Electric Fan', Icons.toys_rounded),
    _RepairType('Washing Machine / Dryer', Icons.local_laundry_service_rounded),
    _RepairType('Television', Icons.tv_rounded),
  ];

  void _openBooking(BuildContext context, String appliance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          initialLocation: initialLocation,
          initialCategory: 'Appliance Repair > $appliance',
          onJobCreated: onJobCreated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 18.0 : 34.0;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 28, horizontalPadding, 34),
              sliver: SliverList.list(
                children: [
                  const _FiveStepProgress(
                    semanticLabel:
                        'Appliance booking step 1 of 5: choose an appliance',
                  ),
                  const SizedBox(height: 46),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tv_rounded, color: _brandBlue, size: 52),
                      SizedBox(width: 12),
                      Text(
                        'Appliance Repair',
                        style: TextStyle(
                          color: _brandBlueDark,
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _appliances.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: .8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 24,
                    ),
                    itemBuilder: (context, index) {
                      final appliance = _appliances[index];
                      return _ActionTile(
                        label: appliance.label,
                        icon: appliance.icon,
                        onTap: () => _openBooking(context, appliance.label),
                      );
                    },
                  ),
                  const SizedBox(height: 64),
                  _AdSpace(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerPromosScreen(
                          onUsePromo: () =>
                              _openBooking(context, 'Electric Fan'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      label: const Text(
                        'HOME',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiveStepProgress extends StatelessWidget {
  final String semanticLabel;

  const _FiveStepProgress({required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Row(
        children: List.generate(
          5,
          (index) => Expanded(
            child: Container(
              height: 16,
              margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
              decoration: BoxDecoration(
                color: index == 0 ? _brandBlue : Colors.white,
                border: Border.all(color: _brandBlue, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PersonalServicesScreen extends StatelessWidget {
  final LatLng? initialLocation;
  final VoidCallback onJobCreated;

  const PersonalServicesScreen({
    super.key,
    required this.initialLocation,
    required this.onJobCreated,
  });

  static const _services = <_RepairType>[
    _RepairType('Barber', Icons.content_cut_rounded),
    _RepairType('Manicure / Pedicure', Icons.back_hand_rounded),
    _RepairType('Hair Styling / Coloring / Hair Care',
        Icons.face_retouching_natural_rounded),
    _RepairType('Massage', Icons.spa_rounded),
    _RepairType('Elderly Care', Icons.elderly_rounded),
    _RepairType('Child Care', Icons.child_care_rounded),
    _RepairType('Physical Therapy', Icons.accessibility_new_rounded),
    _RepairType('Occupational Therapy', Icons.health_and_safety_rounded),
    _RepairType('Tutorial Services', Icons.school_rounded),
    _RepairType('House Keeping', Icons.cleaning_services_rounded),
    _RepairType('Dog / Cat Grooming', Icons.pets_rounded),
    _RepairType('Laundry / Ironing', Icons.local_laundry_service_rounded),
  ];

  void _openBooking(BuildContext context, String service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          initialLocation: initialLocation,
          initialCategory: 'Personal Care > $service',
          initialTitle: '$service service',
          onJobCreated: onJobCreated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 18.0 : 32.0;
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 28, horizontalPadding, 34),
              sliver: SliverList.list(
                children: [
                  const _StepProgress(),
                  const SizedBox(height: 28),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volunteer_activism_rounded,
                          color: _brandBlue, size: 52),
                      SizedBox(width: 12),
                      Text(
                        'Personal Services',
                        style: TextStyle(
                          color: _brandBlueDark,
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 42),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _services.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: .72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 20,
                    ),
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      return _ActionTile(
                        label: service.label,
                        icon: service.icon,
                        onTap: () => _openBooking(context, service.label),
                      );
                    },
                  ),
                  const SizedBox(height: 42),
                  _AdSpace(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerPromosScreen(
                          onUsePromo: () => _openBooking(context, 'Massage'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      label: const Text(
                        'HOME',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeRepairScreen extends StatelessWidget {
  final LatLng? initialLocation;
  final VoidCallback onJobCreated;

  const HomeRepairScreen({
    super.key,
    required this.initialLocation,
    required this.onJobCreated,
  });

  static const _repairTypes = <_RepairType>[
    _RepairType('Carpentry', Icons.carpenter_rounded),
    _RepairType('Plumbing', Icons.plumbing_rounded),
    _RepairType('Structural', Icons.foundation_rounded),
    _RepairType('Electrical', Icons.electric_bolt_rounded),
    _RepairType('Flooring', Icons.grid_on_rounded),
    _RepairType('Roofing', Icons.roofing_rounded),
    _RepairType('Metalwork', Icons.hardware_rounded),
    _RepairType('Glasswork', Icons.window_rounded),
    _RepairType('Upholstery', Icons.chair_rounded),
    _RepairType('Painting', Icons.format_paint_rounded),
    _RepairType('Locksmith', Icons.key_rounded),
    _RepairType('Masonry', Icons.foundation_rounded),
    _RepairType('Landscaping', Icons.park_rounded),
  ];

  void _openRepairForm(BuildContext context, String repairType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          initialLocation: initialLocation,
          initialCategory: 'Home Repair > $repairType',
          initialTitle: '$repairType service',
          onJobCreated: onJobCreated,
        ),
      ),
    );
  }

  void _openPromos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPromosScreen(
          onUsePromo: () => _openRepairForm(context, 'Carpentry'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 360 ? 18.0 : 32.0;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 28, horizontalPadding, 34),
              sliver: SliverList.list(
                children: [
                  const _StepProgress(),
                  const SizedBox(height: 28),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_rounded, color: _brandBlue, size: 56),
                      SizedBox(width: 10),
                      Text(
                        'Home Repair',
                        style: TextStyle(
                          color: _brandBlueDark,
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _repairTypes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: .86,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 20,
                    ),
                    itemBuilder: (context, index) {
                      final repair = _repairTypes[index];
                      return _ActionTile(
                        label: repair.label,
                        icon: repair.icon,
                        onTap: () => _openRepairForm(context, repair.label),
                      );
                    },
                  ),
                  const SizedBox(height: 42),
                  InkWell(
                    onTap: () => _openPromos(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 116,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF777777), width: 4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Home Repair Deals',
                            style: TextStyle(
                              color: Color(0xFF6666FF),
                              fontFamily: 'serif',
                              fontSize: 23,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Tap to view promos',
                            style: TextStyle(
                              color: _brandBlueDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 30),
                      label: const Text(
                        'HOME',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Booking step 1 of 4: choose a service',
      child: Row(
        children: List.generate(
          4,
          (index) => Expanded(
            child: Container(
              height: 16,
              margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
              decoration: BoxDecoration(
                color: index == 0 ? _brandBlue : Colors.white,
                border: Border.all(color: _brandBlue, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RepairType {
  final String label;
  final IconData icon;

  const _RepairType(this.label, this.icon);
}

class CustomerPromosScreen extends StatelessWidget {
  final VoidCallback onUsePromo;

  const CustomerPromosScreen({super.key, required this.onUsePromo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(title: const Text('Promos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Offers for you',
            style: TextStyle(
              color: _brandBlueDark,
              fontFamily: 'serif',
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _PromoCard(
            icon: Icons.home_repair_service_rounded,
            title: '10% off your first booking',
            description: 'Valid on any service. Maximum discount of ₱250.',
            code: 'FIRST10',
            onUse: onUsePromo,
          ),
          const SizedBox(height: 12),
          _PromoCard(
            icon: Icons.people_alt_rounded,
            title: 'Refer a friend',
            description:
                'Copy your invite message and earn rewards after their first completed job.',
            code: 'ODG-FRIEND',
            onUse: () async {
              await Clipboard.setData(
                const ClipboardData(
                  text:
                      'Try ODG for trusted local services. Use referral code ODG-FRIEND.',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referral message copied!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String code;
  final VoidCallback onUse;

  const _PromoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.code,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2F8),
                  child: Icon(icon, color: _brandBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CODE: $code',
                    style: const TextStyle(
                      color: _brandBlueDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                FilledButton(onPressed: onUse, child: const Text('Use offer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerRewardsScreen extends StatelessWidget {
  const CustomerRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthService().currentUser;
    final completed = profile?.completedJobsCount ?? 0;
    final points = completed * 100;
    final progress = (completed / 10).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(title: const Text('Rewards')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _brandBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.diamond_rounded,
                    color: Colors.white, size: 64),
                const SizedBox(height: 8),
                Text(
                  '$points points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$completed completed ${completed == 1 ? 'service' : 'services'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your next reward',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress, minHeight: 10),
          const SizedBox(height: 8),
          Text(
              '${10 - completed.clamp(0, 10)} more services to unlock a priority-support reward'),
          const SizedBox(height: 24),
          const Card(
            child: ListTile(
              leading: Icon(Icons.stars_rounded, color: _brandBlue),
              title: Text('How points work'),
              subtitle:
                  Text('Earn 100 points for every completed service request.'),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerHelpScreen extends StatelessWidget {
  const CustomerHelpScreen({super.key});

  void _contactSupport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Contact support',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Tell us what you need help with.'),
            const SizedBox(height: 16),
            TextField(
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe your concern',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support request submitted.')),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFaq(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _FaqScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.help_rounded, size: 72, color: _brandBlue),
          const SizedBox(height: 16),
          const Text(
            'How can we help?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _brandBlueDark,
              fontFamily: 'serif',
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded,
                  color: _brandBlue),
              title: const Text('Contact support'),
              subtitle: const Text('Send a concern to our customer care team'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _contactSupport(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: _brandBlue),
              title: const Text('Frequently asked questions'),
              subtitle: const Text('Quick answers about requests and payments'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showFaq(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqScreen extends StatelessWidget {
  const _FaqScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Frequently Asked Questions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ExpansionTile(
            title: Text('How do I request a service?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                  'Choose a service on Home, complete the job details, and tap Post Job.'),
            ],
          ),
          ExpansionTile(
            title: Text('Where can I check my request?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                  'Open History to view the status and details of every request.'),
            ],
          ),
          ExpansionTile(
            title: Text('How do payments work?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                  'Your payment is held securely and released after the job is completed.'),
            ],
          ),
          ExpansionTile(
            title: Text('Can I become a provider?'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                  'Tap “Be a Service Provider!” on Home and complete provider registration.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceShortcut {
  final String label;
  final IconData icon;
  final String category;

  const _ServiceShortcut(this.label, this.icon, this.category);
}

class _ExtraShortcut {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ExtraShortcut(this.label, this.icon, this.onTap);
}
