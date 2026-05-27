import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_core/shared_core.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _marketplaceService = MarketplaceService();
  final _authService = AuthService();
  final _dispatchService = DispatchService();
  final _boostService = BoostService();
  final MapController _mapController = MapController();
  List<Job> _availableJobs = [];
  List<Job> _activeJobs = [];
  bool _isTracking = false;
  UserProfile? _profile;
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  Timer? _trackingTimer;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  double _serviceRadius = 3000.0; // Default 3km (3000m)
  double _sliderRadius = 3000.0; // Slider visual value

  Future<void> _loadAll() async {
    final p = await _authService.getProfile();
    final pos = await _dispatchService.getCurrentPosition();
    
    final lat = pos?.latitude ?? 37.7749;
    final lng = pos?.longitude ?? -122.4194;

    List<Job> allJobs = [];

    if (p != null) {
      bool searchConducted = false;
      if (p.isRoamBoostActive) {
        // Roam active: search around current location (real-time)
        final jobs = await _marketplaceService.getJobs(
          lat: lat,
          lng: lng,
          radius: 2000.0, // Fixed 2km radius for Roam
        );
        allJobs.addAll(jobs);
        searchConducted = true;
      } else {
        // Static coverage
        final baseRadius = 3000.0;
        final expandedRadius = p.isCoverageBoostActive ? baseRadius + 2000.0 : baseRadius;
        
        // Search primary
        if (p.primaryLocation != null) {
          final jobs = await _marketplaceService.getJobs(
            lat: p.primaryLocation!.latitude,
            lng: p.primaryLocation!.longitude,
            radius: expandedRadius,
          );
          allJobs.addAll(jobs);
          searchConducted = true;
        }

        // Search secondary if active
        if (p.secondaryLocation != null && p.isCoverageBoostActive) {
          final jobs = await _marketplaceService.getJobs(
            lat: p.secondaryLocation!.latitude,
            lng: p.secondaryLocation!.longitude,
            radius: expandedRadius,
          );
          // Deduplicate
          for (var j in jobs) {
            if (!allJobs.any((existing) => existing.id == j.id)) {
              allJobs.add(j);
            }
          }
          searchConducted = true;
        }
      }

      // Fallback if no boost-specific searches were successful/possible
      if (!searchConducted) {
        final jobs = await _marketplaceService.getJobs(
          lat: lat,
          lng: lng,
          radius: _serviceRadius,
        );
        allJobs.addAll(jobs);
      }
    } else {
      // Fallback for non-profile states
      allJobs = await _marketplaceService.getJobs(
        lat: lat,
        lng: lng,
        radius: _serviceRadius,
      );
    }

    final providerJobs = await _marketplaceService.getProviderJobs();
    
    if (mounted) {
      setState(() {
        _profile = p;
        _currentLocation = LatLng(lat, lng);
        
        if (_profile != null && _profile!.skills.isNotEmpty) {
          _availableJobs = allJobs.where((j) {
            final mainCat = j.category.split(' > ')[0];
            return _profile!.skills.contains(mainCat) && 
                   (j.status == JobStatus.published || j.status == JobStatus.bidding);
          }).toList();
        } else {
          _availableJobs = allJobs.where((j) => j.status == JobStatus.published || j.status == JobStatus.bidding).toList();
        }

        _activeJobs = providerJobs.where((j) => 
          j.status == JobStatus.accepted || 
          j.status == JobStatus.enRoute || 
          j.status == JobStatus.inProgress
        ).toList();
      });
      _mapController.move(_currentLocation, 14.0);
    }
  }

  void _showBoostDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider Boosts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Supercharge your reach and find more jobs.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            _buildBoostOption(
              icon: Icons.map,
              title: 'Expand Coverage Area',
              subtitle: 'Adds 2km to your primary & secondary locations.',
              price: '₱199/week',
              isActive: _profile?.isCoverageBoostActive ?? false,
              onTap: () => _purchaseBoost('coverage'),
            ),
            const SizedBox(height: 16),
            _buildBoostOption(
              icon: Icons.directions_run,
              title: 'Roam Mode',
              subtitle: 'Find jobs within 2km of your real-time location.',
              price: '₱299/week',
              isActive: _profile?.isRoamBoostActive ?? false,
              onTap: () => _purchaseBoost('roam'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBoostOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isActive ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isActive ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: isActive ? Colors.green.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.blue.shade100,
              child: Icon(icon, color: isActive ? Colors.white : Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: Colors.green)
            else
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      ),
    );
  }

  void _purchaseBoost(String type) async {
    Navigator.pop(context); // Close sheet
    setState(() => _isActionLoading = true);
    
    bool success = false;
    if (type == 'coverage') {
      success = await _boostService.purchaseCoverageBoost();
    } else {
      success = await _boostService.purchaseRoamBoost();
    }

    setState(() => _isActionLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type == 'coverage' ? 'Coverage' : 'Roam'} boost activated!'), backgroundColor: Colors.green),
      );
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to activate boost. Please try again.')),
      );
    }
  }

  void _handleRadiusChange(double val) {
    if (val <= 3000.0) {
      setState(() {
        _serviceRadius = val;
        _sliderRadius = val;
      });
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coverage radius updated to ${(val / 1000).toStringAsFixed(1)} km (Free Range).'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (val <= _serviceRadius) {
      // Shrinking radius doesn't require top-up
      setState(() {
        _serviceRadius = val;
        _sliderRadius = val;
      });
      _loadAll();
      return;
    }

    // Calculating top-up cost
    final currentPaidLimit = _serviceRadius > 3000.0 ? _serviceRadius : 3000.0;
    final expansionDistance = val - currentPaidLimit;
    
    if (expansionDistance <= 0) {
      setState(() {
        _serviceRadius = val;
        _sliderRadius = val;
      });
      _loadAll();
      return;
    }

    final double extra2KmSteps = expansionDistance / 2000.0;
    final double cost = extra2KmSteps.ceil() * 100.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payment, color: Colors.blue),
              SizedBox(width: 8),
              Text('Coverage Expansion'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are expanding your service range to ${(val / 1000).toStringAsFixed(1)} km.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'A top-up is required for this expansion:\n'
                '• Free Limit: 3.0 km\n'
                '• Expansion: +${(expansionDistance / 1000).toStringAsFixed(1)} km\n'
                '• Cost: ₱${cost.toStringAsFixed(2)} (₱100.00 per 2 km)',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset slider visual to previous service radius
                setState(() {
                  _sliderRadius = _serviceRadius;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processMockPayment(val, cost);
              },
              child: Text('Pay ₱${cost.toStringAsFixed(2)}'),
            ),
          ],
        );
      },
    );
  }

  void _processMockPayment(double val, double cost) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing top-up payment...'),
            ],
          ),
        );
      },
    );

    Timer(const Duration(milliseconds: 1500), () {
      Navigator.of(context).pop(); // Dismiss processing dialog
      setState(() {
        _serviceRadius = val;
        _sliderRadius = val;
      });
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top-up successful! Service range expanded to ${(_serviceRadius / 1000).toStringAsFixed(1)} km.'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _toggleTracking() async {
    if (!_isTracking) {
      final pos = await _dispatchService.getCurrentPosition();
      if (pos != null) {
        setState(() {
          _isTracking = true;
          _currentLocation = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_currentLocation, 14.0);
        _startLocationReporting();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot enable tracking: Location permission denied or unavailable.')),
          );
        }
      }
    } else {
      setState(() => _isTracking = false);
      _trackingTimer?.cancel();
    }
  }

  void _startLocationReporting() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isTracking) return;
      final pos = await _dispatchService.getCurrentPosition();
      if (pos != null && _profile != null) {
        await _dispatchService.updateLocation(_profile!.id, pos);
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
          _mapController.move(_currentLocation, 14.0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.rocket_launch, color: Colors.orange),
            onPressed: _showBoostDialog,
          ),
          IconButton(
            icon: Icon(_isTracking ? Icons.location_on : Icons.location_off,
                color: _isTracking ? Colors.green : Colors.red),
            onPressed: _toggleTracking,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildEarningsCard(context),
              if (_profile?.isCoverageBoostActive == true)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SwitchListTile(
                    title: const Text('Expand Coverage Area', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Search +2km around fixed locations', style: TextStyle(fontSize: 12)),
                    value: _profile!.coverageBoostEnabled,
                    activeColor: Colors.orange,
                    onChanged: (val) async {
                      await _boostService.toggleCoverageBoost(val);
                      _loadAll();
                    },
                  ),
                ),
              if (_profile?.isRoamBoostActive == true)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_run, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Roam Mode Active: Searching 2km around your real-time location.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildActiveJobsSection(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Service Range: ${(_sliderRadius / 1000).toStringAsFixed(1)} km', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: _sliderRadius,
                        min: 1000,
                        max: 25000,
                        divisions: 24,
                        onChanged: (val) {
                          setState(() => _sliderRadius = val);
                        },
                        onChangeEnd: (val) => _handleRadiusChange(val),
                      ),
                    ),
                  ],
                ),
              ),
              _buildMapSection(),
              _buildJobsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isTracking ? Colors.green : Colors.grey, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.google.gemini.cli',
            ),
            CircleLayer<Object>(
              circles: [
                CircleMarker<Object>(
                  point: _currentLocation,
                  radius: _serviceRadius,
                  useRadiusInMeter: true,
                  color: Colors.blue.withOpacity(0.15),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  child: const Icon(Icons.navigation, color: Colors.blue, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Colors.blueAccent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Earnings', style: TextStyle(color: Colors.white70)),
          Text('₱0.00', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jobs: 0', style: TextStyle(color: Colors.white)),
              Text('Rating: 5.0 ★', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Opportunities Near You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        _availableJobs.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No matching jobs found.')))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableJobs.length,
                itemBuilder: (context, index) {
                  final job = _availableJobs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(job.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.category),
                          if (job.status == JobStatus.accepted)
                            const Text('Funds Secured in Escrow ✅', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      trailing: Text('₱${job.maxBudget?.toStringAsFixed(2) ?? "N/A"}', 
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final refresh = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
                        );
                        if (refresh == true) {
                          _loadAll();
                        }
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.accepted:
        return Colors.green;
      case JobStatus.enRoute:
        return Colors.blue;
      case JobStatus.inProgress:
        return Colors.orange.shade800;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(JobStatus status) {
    switch (status) {
      case JobStatus.accepted:
        return Icons.handshake;
      case JobStatus.enRoute:
        return Icons.directions_run;
      case JobStatus.inProgress:
        return Icons.engineering;
      default:
        return Icons.work_outline;
    }
  }

  String _getStatusText(JobStatus status) {
    switch (status) {
      case JobStatus.accepted:
        return 'Accepted - Escrow Funded';
      case JobStatus.enRoute:
        return 'En Route';
      case JobStatus.inProgress:
        return 'In Progress';
      default:
        return status.name.toUpperCase();
    }
  }

  Widget _buildActiveJobsSection() {
    if (_activeJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
          child: Text(
            'My Active Jobs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _activeJobs.length,
          itemBuilder: (context, index) {
            final job = _activeJobs[index];
            final statusColor = _getStatusColor(job.status);
            final statusIcon = _getStatusIcon(job.status);
            final statusText = _getStatusText(job.status);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () async {
                    final refresh = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailScreen(job: job),
                      ),
                    );
                    if (refresh == true) {
                      _loadAll();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: statusColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₱${job.maxBudget?.toStringAsFixed(2) ?? "N/A"}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.category,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                job.status == JobStatus.accepted
                                    ? 'Funded & ready! Tap to update status and view location.'
                                    : 'Active job. Tap to update status or open chat.',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
