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
  final MapController _mapController = MapController();
  List<Job> _availableJobs = [];
  bool _isTracking = false;
  UserProfile? _profile;
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);
  Timer? _trackingTimer;

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

    final jobs = await _marketplaceService.getJobs(
      lat: lat,
      lng: lng,
      radius: _serviceRadius,
    );
    
    if (mounted) {
      setState(() {
        _profile = p;
        _currentLocation = LatLng(lat, lng);
        
        if (_profile != null && _profile!.skills.isNotEmpty) {
          _availableJobs = jobs.where((j) {
            final mainCat = j.category.split(' > ')[0];
            return _profile!.skills.contains(mainCat) && 
                   (j.status == JobStatus.published || j.status == JobStatus.bidding);
          }).toList();
        } else {
          _availableJobs = jobs.where((j) => j.status == JobStatus.published || j.status == JobStatus.bidding).toList();
        }
      });
      _mapController.move(_currentLocation, 14.0);
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
    final double cost = extra2KmSteps.ceil() * 2.0;

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
                '• Cost: \$${cost.toStringAsFixed(2)} (\$2.00 per 2 km)',
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
              child: Text('Pay \$${cost.toStringAsFixed(2)}'),
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
          Text('\$0.00', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                      trailing: Text('\$${job.maxBudget?.toStringAsFixed(2) ?? "N/A"}', 
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => JobDetailScreen(job: job))),
                    ),
                  );
                },
              ),
      ],
    );
  }
}
