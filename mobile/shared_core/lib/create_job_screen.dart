import 'package:flutter/material.dart';
import 'marketplace_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CreateJobScreen extends StatefulWidget {
  final VoidCallback onJobCreated;
  final LatLng? initialLocation;

  const CreateJobScreen({super.key, required this.onJobCreated, this.initialLocation});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  String _category = 'Home Repair';
  String _subcategory = 'Plumbing';
  bool _isEmergency = false;
  final _marketplaceService = MarketplaceService();
  bool _isLoading = false;
  Map<String, dynamic>? _insights;

  final Map<String, List<String>> _categories = {
    'Home Repair': ['Plumbing', 'Electrical', 'Carpentry', 'Painting'],
    'Personal Care': ['Barber', 'Massage', 'Manicure', 'Hair Styling'],
    'Automotive': ['Oil Change', 'Tire Repair', 'Engine Check', 'Car Wash'],
    'Cleaning': ['House Cleaning', 'Deep Clean', 'Office Cleaning'],
    'Device Repair': ['Smartphone', 'Laptop', 'Tablet', 'Console'],
    'Appliance Repair': ['Refrigerator', 'Washing Machine', 'Aircon', 'Oven'],
  };

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final insights = await _marketplaceService.getInsights('$_category > $_subcategory');
    if (mounted) {
      setState(() => _insights = insights);
    }
  }

  void _submit() async {
    setState(() => _isLoading = true);

    // Fetch current location
    LatLng? location = widget.initialLocation;
    if (location == null) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition();
          location = LatLng(pos.latitude, pos.longitude);
        }
      } catch (e) {
        print('Error getting location: $e');
      }
    }

    final job = await _marketplaceService.createJob(
      title: _titleController.text,
      description: _descController.text,
      category: '$_category > $_subcategory',
      maxBudget: double.tryParse(_budgetController.text),
      isEmergency: _isEmergency,
      location: location,
    );
    setState(() => _isLoading = false);

    if (job != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted successfully!')),
        );
        widget.onJobCreated();
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post job. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a New Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Emergency / Urgent Request'),
              subtitle: const Text('This will flag your job as a priority.'),
              value: _isEmergency,
              activeColor: Colors.red,
              onChanged: (val) => setState(() => _isEmergency = val),
            ),
            const Divider(),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categories.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _category = val!;
                  _subcategory = _categories[_category]![0];
                });
                _fetchInsights();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _subcategory,
              decoration: const InputDecoration(labelText: 'Sub-category', border: OutlineInputBorder()),
              items: _categories[_category]!
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                setState(() => _subcategory = val!);
                _fetchInsights();
              },
            ),
            if (_insights != null && _insights!['count'] > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Suggested Budget: ₱${_insights!['average'].toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetController,
              decoration: const InputDecoration(labelText: 'Max Budget (₱)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Post Job'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
