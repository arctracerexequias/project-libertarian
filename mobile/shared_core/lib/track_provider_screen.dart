import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dispatch_service.dart';

class TrackProviderScreen extends StatefulWidget {
  final String providerId;

  const TrackProviderScreen({super.key, required this.providerId});

  @override
  State<TrackProviderScreen> createState() => _TrackProviderScreenState();
}

class _TrackProviderScreenState extends State<TrackProviderScreen> {
  final _dispatchService = DispatchService();
  final MapController _mapController = MapController();
  LatLng? _providerLocation;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    // Poll every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchLocation());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final data = await _dispatchService.getProviderLocation(widget.providerId);
    if (data != null && mounted) {
      final newLoc = LatLng(data['lat'], data['lng']);
      final wasLoading = _isLoading;
      setState(() {
        _providerLocation = newLoc;
        _isLoading = false;
      });
      if (!wasLoading) {
        try {
          _mapController.move(newLoc, 15.0);
        } catch (e) {
          print('MapController move error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track Provider')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providerLocation == null
              ? const Center(child: Text('Provider location unavailable.'))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _providerLocation!,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.google.gemini.cli',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _providerLocation!,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
