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
  final MapController _mapController = MapController();
  List<Job> _jobs = [];
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
    if (mounted) {
      setState(() => _jobs = jobs.where((j) => j.status != JobStatus.completed).toList());
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Active Jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildActiveJobsList(),
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

  Widget _buildActiveJobsList() {
    if (_jobs.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No active jobs.')));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(job.title),
            subtitle: Text(job.status.name.toUpperCase()),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailScreen(job: job))),
            trailing: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailScreen(job: job))),
            ),
          ),
        );
      },
    );
  }
}
