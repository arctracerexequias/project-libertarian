import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_core/shared_core.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _marketplaceService = MarketplaceService();
  final _dispatchService = DispatchService();
  final _paymentService = PaymentService();
  final MapController _mapController = MapController();
  List<Job> _activeJobs = [];
  List<Job> _completedJobs = [];
  LatLng _currentLocation = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await _updateCurrentLocation();
    await _refreshJobs();
  }

  Future<void> _updateCurrentLocation() async {
    final pos = await _dispatchService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentLocation, 13.0);
    }
  }

  double _searchRadius = 5000; // Default 5km

  Future<void> _refreshJobs() async {
    final jobs = await _marketplaceService.getJobs(
      lat: _currentLocation.latitude == 0 ? null : _currentLocation.latitude,
      lng: _currentLocation.longitude == 0 ? null : _currentLocation.longitude,
      radius: _searchRadius,
    );

    final List<Job> activeJobs = [];
    final List<Job> completedJobs = [];
    final List<Future<void>> checks = [];

    for (final job in jobs) {
      if (job.status != JobStatus.completed) {
        activeJobs.add(job);
      } else {
        checks.add(() async {
          final escrow = await _paymentService.getEscrowStatus(job.id);
          if (escrow == null || escrow['status'] == 'HELD') {
            completedJobs.add(job);
          }
        }());
      }
    }

    if (checks.isNotEmpty) {
      await Future.wait(checks);
    }

    if (mounted) {
      setState(() {
        activeJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        completedJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _activeJobs = activeJobs;
        _completedJobs = completedJobs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libertarian Marketplace'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAll),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMapSection(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Search Radius: ${(_searchRadius / 1000).toStringAsFixed(1)} km', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: _searchRadius,
                        min: 1000,
                        max: 50000,
                        divisions: 49,
                        onChanged: (val) {
                          setState(() => _searchRadius = val);
                        },
                        onChangeEnd: (val) => _refreshJobs(),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('What do you need?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              _buildCategoryGrid(),
              if (_completedJobs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                  child: Text('Completed Jobs (Pending Settlement)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
                _buildCompletedJobsList(),
              ],
              if (_activeJobs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                  child: Text('Active Jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildActiveJobsList(),
              ],
              if (_activeJobs.isEmpty && _completedJobs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No active or completed jobs.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateJobScreen(
              onJobCreated: _refreshJobs,
              initialLocation: _currentLocation,
            ),
          ),
        ),
        label: const Text('Post a Job'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 13.0,
            onTap: (tapPosition, point) {
              setState(() {
                _currentLocation = point;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.google.gemini.cli',
            ),
            MarkerLayer(
              markers: [
                // User Marker
                Marker(
                  point: _currentLocation,
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildCategoryCard('Home', Icons.home),
        _buildCategoryCard('Care', Icons.spa),
        _buildCategoryCard('Auto', Icons.directions_car),
      ],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    return Card(
      child: InkWell(
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedJobsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _completedJobs.length,
      itemBuilder: (context, index) {
        final job = _completedJobs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.green.shade200, width: 1),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white),
            ),
            title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('COMPLETED - AWAITING SETTLEMENT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
              );
              if (updated == true) {
                _refreshJobs();
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.green),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
                );
                if (updated == true) {
                  _refreshJobs();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveJobsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeJobs.length,
      itemBuilder: (context, index) {
        final job = _activeJobs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(job.title),
            subtitle: Text(job.status.name.toUpperCase()),
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
              );
              if (updated == true) {
                _refreshJobs();
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
                );
                if (updated == true) {
                  _refreshJobs();
                }
              },
            ),
          ),
        );
      },
    );
  }
}
