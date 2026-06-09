import 'package:flutter/material.dart';
import 'marketplace_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';

class CreateJobScreen extends StatefulWidget {
  final VoidCallback onJobCreated;
  final LatLng? initialLocation;
  final String? parentJobId;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialDescription;

  const CreateJobScreen({
    super.key, 
    required this.onJobCreated, 
    this.initialLocation,
    this.parentJobId,
    this.initialCategory,
    this.initialTitle,
    this.initialDescription,
  });

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _occurrencesController = TextEditingController(text: '1');
  
  String _category = 'Home Repair';
  String _subcategory = 'Plumbing';
  bool _isEmergency = false;
  RecurrenceType _recurrence = RecurrenceType.once;
  DateTime? _scheduledAt;
  
  final _marketplaceService = MarketplaceService();
  bool _isLoading = false;
  Map<String, dynamic>? _insights;

  final Map<String, List<String>> _categories = {
    'Home Repair': [
      'Plumbing',
      'Electrical',
      'Carpentry',
      'Painting',
      'Roofing',
      'Tile Setting',
      'Locksmith',
      'Metal Fabrication',
      'Upholstery',
      'Masonry',
      'Landscaping'
    ],
    'Personal Care': [
      'Barber',
      'Manicure/Pedicure',
      'Hair Styling/Coloring/ Hair Care',
      'Massage',
      'Elderly Care',
      'Child Care',
      'Physical Therapy',
      'Occupational Therapy',
      'Tutorial Services',
      'House Keeping',
      'Dog/Cat Grooming',
      'Laundry/Ironing'
    ],
    'Automotive': [
      'Tire Repair',
      'Tuning',
      'Engine Check/Repair',
      'Car wash',
      'Detailing',
      'Electrical Repair',
      'Tinting',
      'Body Repair/Painting'
    ],
    'Device Repair': ['Smartphone', 'Laptop', 'Tablet', 'Console', 'CCTV'],
    'Appliance Repair': [
      'Refrigerator',
      'Washing Machine',
      'HVAC',
      'Stove/Oven',
      'Television'
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
    if (widget.initialDescription != null) _descController.text = widget.initialDescription!;
    
    if (widget.initialCategory != null) {
      final parts = widget.initialCategory!.split(' > ');
      if (parts.length == 2) {
        _category = parts[0];
        _subcategory = parts[1];
      }
    }
    
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final insights = await _marketplaceService.getInsights('$_category > $_subcategory');
    if (mounted) {
      setState(() => _insights = insights);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _scheduledAt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
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
      recurrenceType: _recurrence,
      totalOccurrences: int.tryParse(_occurrencesController.text) ?? 1,
      parentJobId: widget.parentJobId,
      scheduledAt: _scheduledAt,
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
      appBar: AppBar(title: Text(widget.parentJobId != null ? 'Rebook Service' : 'Post a New Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.parentJobId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue)),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(child: Text('Rebooking: Same provider and service will be prioritized.', style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
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
            const SizedBox(height: 16),
            const Text('Booking Type & Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceType>(
              value: _recurrence,
              decoration: const InputDecoration(labelText: 'Recurrence', border: OutlineInputBorder()),
              items: RecurrenceType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _recurrence = val!),
            ),
            if (_recurrence != RecurrenceType.once) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _occurrencesController,
                decoration: const InputDecoration(labelText: 'Number of Occurrences (e.g. 15 days)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Scheduled Start Time'),
              subtitle: Text(_scheduledAt == null ? 'Immediate / As soon as possible' : _scheduledAt.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 24),
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
              decoration: const InputDecoration(labelText: 'Budget per Session (₱)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(widget.parentJobId != null ? 'Confirm Rebooking' : 'Post Job'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
