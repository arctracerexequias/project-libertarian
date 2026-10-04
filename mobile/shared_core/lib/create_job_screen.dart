import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'marketplace_service.dart';
import 'models.dart';
import 'personal_service_form.dart';

const _odgBlue = Color(0xFF006D99);
const _odgPale = Color(0xFFB5CCDA);
const _odgRed = Color(0xFFFF3438);

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
  final _marketplace = MarketplaceService();
  final _picker = ImagePicker();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _workers = TextEditingController(text: '1');
  final _vehicleBrand = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _vehicleYear = TextEditingController();
  final _applianceBrand = TextEditingController();
  final _applianceModel = TextEditingController();

  int _step = 0;
  bool _immediate = true;
  bool _asap = true;
  bool _isSubmitting = false;
  bool? _postSucceeded;
  Job? _createdJob;
  DateTime? _start;
  DateTime? _end;
  String? _barangay;
  String? _city;
  String? _payment;
  String? _vehicleType;
  bool? _canBringToShop;
  bool? _needsTowing;
  bool? _isRegisteredOwner;
  String? _applianceType;
  String? _deviceType;
  bool? _requiresHomeService;
  bool? _requiresPickup;
  LatLng? _location;
  final List<({String name, Uint8List bytes})> _photos = [];
  final Map<String, dynamic> _answers = {};
  String? _requestID;
  String? _submissionFingerprint;
  DateTime? _submittedAt;
  String? _submissionError;
  final _scroll = ScrollController();

  String _category = 'Home Repair';
  String _subcategory = 'Carpentry';

  bool get _isVehicleRepair => _category == 'Automotive';
  bool get _isApplianceRepair => _category == 'Appliance Repair';
  bool get _isDeviceRepair => _category == 'Device Repair';
  bool get _isChosenHomeRepair =>
      _category == 'Home Repair' &&
      (widget.initialCategory?.contains(' > ') ?? false);
  bool get _isChosenPersonalCare =>
      _category == 'Personal Care' &&
      (widget.initialCategory?.contains(' > ') ?? false);
  bool get _isSpecialized =>
      _isVehicleRepair || _isApplianceRepair || _isDeviceRepair;
  bool get _isPersonal =>
      _category == 'Personal Care' &&
      personalServices.containsKey(_subcategory);
  int get _locationStep => _isPersonal ? 1 : (_isSpecialized ? 2 : 0);
  int get _detailsStep => _locationStep + 1;
  int get _reviewStep => _locationStep + 2;
  int get _resultStep => _reviewStep + 1;
  bool get _perWorker =>
      !_isSpecialized && !_isPersonal ||
      _isPersonal && _subcategory == 'Landscaping';
  int get _effectiveWorkers => _isPersonal
      ? (_subcategory == 'Landscaping'
          ? int.tryParse('${_answers['providers']}') ?? 1
          : 1)
      : (_isSpecialized ? 1 : _workerCount ?? 1);
  String get _schedule =>
      '${_immediate ? 'Immediately' : _start == null ? 'Not selected' : _formatDate(_start!)} to ${_asap ? 'ASAP' : _end == null ? 'Not selected' : _formatDate(_end!)}';

  void _toStep(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  double? get _offerAmount => double.tryParse(
        _budget.text.replaceAll('₱', '').replaceAll(',', '').trim(),
      );

  int? get _workerCount => int.tryParse(_workers.text.trim());

  static const _subcategories = <String, List<String>>{
    'Home Repair': [
      'Carpentry',
      'Plumbing',
      'Electrical',
      'Painting',
      'Roofing',
      'Locksmith',
      'Masonry',
      'Landscaping',
      'Structural',
      'Flooring',
      'Metalwork',
      'Glasswork',
      'Upholstery',
    ],
    'Automotive': [
      'Engine Repair',
      'Tire Repair',
      'Electrical Repair',
      'Car Wash',
      'Detailing',
    ],
    'Personal Care': [
      'Massage',
      'Nail Care',
      'Tailoring',
      'Housekeeping',
      'Landscaping',
      'Babysitting',
      'Caregiving / Nursing',
      'Pet Care',
      'Tutorial',
      'Barber',
      'Hair Styling, Coloring & Care',
      'Physical Therapy',
      'Occupational Therapy',
      'Laundry & Ironing',
    ],
    'Device Repair': [
      'Mobile Phone',
      'Tablet',
      'Laptop',
      'Computer',
      'Sound System',
      'Peripherals',
      'Digital Camera',
      'Drone',
    ],
    'Appliance Repair': [
      'HVAC',
      'Refrigerator',
      'Stove & Oven',
      'Electric Fan',
      'Washer & Dryer',
      'Television',
    ],
  };

  @override
  void initState() {
    super.initState();
    // A booking may be for a different address than the customer’s current GPS position.
    _location = null;
    _title.text = widget.initialTitle ?? '';
    _description.text = widget.initialDescription ?? '';
    final parts = widget.initialCategory?.split(' > ') ?? <String>[];
    if (parts.length > 1 && parts.first == 'Personal Care')
      parts[1] = canonicalPersonalService(parts[1]);
    if (parts.isNotEmpty && _subcategories.containsKey(parts.first)) {
      _category = parts.first;
      _subcategory =
          parts.length > 1 && _subcategories[_category]!.contains(parts[1])
              ? parts[1]
              : _subcategories[_category]!.first;
      if ((_category == 'Appliance Repair' || _category == 'Device Repair') &&
          parts.length > 1 &&
          _subcategories[_category]!.contains(parts[1])) {
        if (_category == 'Appliance Repair') {
          _applianceType = parts[1];
        } else {
          _deviceType = parts[1];
        }
        _step = 1;
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _address.dispose();
    _contact.dispose();
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    _workers.dispose();
    _vehicleBrand.dispose();
    _vehicleModel.dispose();
    _vehicleYear.dispose();
    _applianceBrand.dispose();
    _applianceModel.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute);
      if (start) {
        _start = value;
        _immediate = false;
      } else {
        _end = value;
        _asap = false;
      }
    });
  }

  Future<void> _attachPhotos() async {
    try {
      final files = await _picker.pickMultiImage(
          imageQuality: 80, maxWidth: 1920, maxHeight: 1920);
      for (final file in files) {
        if (_photos.length >= 5) {
          if (mounted) _message('Attach up to five photos.');
          break;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
        final png = bytes.length > 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47;
        if (bytes.length > 2 * 1024 * 1024 || (!jpeg && !png)) {
          _message('Use JPEG or PNG photos up to 2 MB each.');
          continue;
        }
        setState(() => _photos.add((name: file.name, bytes: bytes)));
      }
    } catch (_) {
      if (mounted)
        _message(
            'Could not read photos. Check photo permissions and try again.');
    }
  }

  Widget _photoPreview({bool editable = false}) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _photos.length; i++)
            SizedBox(
                width: 100,
                child: Column(children: [
                  Image.memory(_photos[i].bytes,
                      width: 100,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image)),
                  if (editable)
                    TextButton(
                        onPressed: () => setState(() => _photos.removeAt(i)),
                        child: const Text('Remove photo')),
                ])),
        ],
      );

  Future<void> _useCurrentLocation() async {
    final location = await _resolveLocation();
    if (!mounted) return;
    if (location == null) {
      _message('Could not access your current location.');
      return;
    }
    setState(() {
      _location = location;
      if (_address.text.trim().isEmpty) {
        _message('Location pinned. Enter the complete service address below.');
      }
    });
    _message('Current location added to this request.');
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  bool _validateStep() {
    if (_isVehicleRepair) {
      if (_step == 0 && _vehicleType == null) {
        _message('Select a vehicle type.');
        return false;
      }
      if (_step == 1 &&
          (_vehicleBrand.text.trim().isEmpty ||
              _vehicleModel.text.trim().isEmpty ||
              (int.tryParse(_vehicleYear.text) ?? 0) < 1900 ||
              (int.tryParse(_vehicleYear.text) ?? 0) >
                  DateTime.now().year + 1 ||
              _canBringToShop == null ||
              (_canBringToShop == true && _needsTowing == null) ||
              _isRegisteredOwner == null)) {
        _message('Complete the vehicle details and service questions.');
        return false;
      }
    }
    if (_isApplianceRepair) {
      if (_step == 0 && _applianceType == null) {
        _message('Select an appliance type.');
        return false;
      }
      if (_step == 1 &&
          (_applianceBrand.text.trim().isEmpty ||
              _requiresHomeService == null ||
              (_requiresHomeService == false && _requiresPickup == null))) {
        _message('Complete the appliance and service details.');
        return false;
      }
    }
    if (_isDeviceRepair) {
      if (_step == 0 && _deviceType == null) {
        _message('Select a device type.');
        return false;
      }
      if (_step == 1 &&
          (_applianceBrand.text.trim().isEmpty ||
              _applianceModel.text.trim().isEmpty ||
              _requiresHomeService == null ||
              (_requiresHomeService == false && _requiresPickup == null))) {
        _message('Complete the device and service details.');
        return false;
      }
    }
    if (_isPersonal && _step == 0) {
      final error = validatePersonalAnswers(_subcategory, _answers);
      if (error != null) {
        _message(error);
        return false;
      }
    }
    final locationStep = _locationStep;
    final detailsStep = _detailsStep;
    if (_step == locationStep) {
      if (_address.text.trim().isEmpty ||
          (_barangay ?? '').trim().isEmpty ||
          (_city ?? '').trim().isEmpty ||
          !RegExp(r'^\+?[0-9 ()-]{7,25}$').hasMatch(_contact.text.trim()) ||
          _contact.text.replaceAll(RegExp(r'\D'), '').length < 7) {
        _message('Complete the address and contact information.');
        return false;
      }
      if ((!_immediate && _start == null) || (!_asap && _end == null)) {
        _message('Select the service dates.');
        return false;
      }
      final now = DateTime.now();
      if (!_immediate && !_start!.isAfter(now)) {
        _message('Choose a future service start.');
        return false;
      }
      if (!_asap && !_end!.isAfter(_immediate ? now : _start!)) {
        _message('Service end must be after the start.');
        return false;
      }
    }
    if (_step == detailsStep) {
      if (_title.text.trim().isEmpty) {
        _message('Enter a title for the job.');
        return false;
      }
      if (_description.text.trim().length < 10) {
        _message('Describe the job using at least 10 characters.');
        return false;
      }
      if ((_offerAmount ?? 0) <= 0 ||
          !(_offerAmount ?? 0).isFinite ||
          (_offerAmount ?? 0) > 10000000) {
        _message('Enter an offer greater than zero, up to ₱10,000,000.');
        return false;
      }
      if (((_offerAmount! * 100) - (_offerAmount! * 100).round()).abs() >
          0.00001) {
        _message('Use no more than two decimal places for the offer.');
        return false;
      }
      if (_perWorker && (_effectiveWorkers <= 0 || _effectiveWorkers > 120)) {
        _message('Enter a valid number of workers.');
        return false;
      }
    }
    if (_step == _reviewStep && _payment == null) {
      _message('Select a payment option.');
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step == _reviewStep) {
      _submit();
    } else {
      _toStep(_step + 1);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _toStep(_step - 1);
    }
  }

  Future<LatLng?> _resolveLocation() async {
    if (_location != null) return _location;
    if (widget.initialLocation != null) return widget.initialLocation;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 10));
        return LatLng(position.latitude, position.longitude);
      }
    } catch (_) {
      // The request remains valid without precise coordinates.
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    Job? job;
    try {
      final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _requestID ??=
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      _submittedAt ??= _immediate ? DateTime.now() : _start;
      final publicAnswers = <String, String>{
        ...personalAnswerSummary(_subcategory, _answers, private: false),
        if (_isVehicleRepair) ...{
          'Vehicle':
              '${_vehicleYear.text} ${_vehicleBrand.text.trim()} ${_vehicleModel.text.trim()}',
          'Can bring to shop': _yesNo(_canBringToShop),
          if (_canBringToShop == true) 'Needs towing': _yesNo(_needsTowing),
          'Registered owner': _yesNo(_isRegisteredOwner),
        },
        if (_isApplianceRepair || _isDeviceRepair) ...{
          'Brand': _applianceBrand.text.trim(),
          'Model': _applianceModel.text.trim().isEmpty
              ? 'N/A'
              : _applianceModel.text.trim(),
          'Requires home service': _yesNo(_requiresHomeService),
          if (_requiresHomeService == false)
            'Requires pickup / delivery': _yesNo(_requiresPickup),
        },
      };
      // Returning to review without edits is still the same submission.
      final fingerprint = jsonEncode({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': [
          _category,
          _subcategory,
          _vehicleType,
          _applianceType,
          _deviceType
        ],
        'address': [
          _address.text.trim(),
          _barangay,
          _city,
          _contact.text.trim()
        ],
        'schedule': [
          _immediate,
          _start?.toIso8601String(),
          _asap,
          _end?.toIso8601String()
        ],
        'offer': [_offerAmount, _effectiveWorkers, _payment],
        'location': [_location?.latitude, _location?.longitude],
        'answers': publicAnswers,
        'private': personalAnswerSummary(_subcategory, _answers, private: true),
        'photos': [for (final photo in _photos) base64Encode(photo.bytes)],
      });
      if (_submissionFingerprint != null &&
          _submissionFingerprint != fingerprint) {
        _requestID =
            '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
        _submittedAt = _immediate ? DateTime.now() : _start;
      }
      _submissionFingerprint = fingerprint;
      job = await _marketplace.createJob(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category:
            '$_category > ${_isVehicleRepair ? _vehicleType : _isApplianceRepair ? _applianceType : _isDeviceRepair ? _deviceType : _subcategory}',
        maxBudget: (_offerAmount ?? 0) * _effectiveWorkers,
        paymentMethod: _payment!.startsWith('Cash') ? 'CASH' : 'ONLINE',
        location: _location,
        recurrenceType: RecurrenceType.once,
        parentJobId: widget.parentJobId,
        scheduledAt: _submittedAt,
        isEmergency: _immediate,
        requestId: _requestID,
        booking: {
          'area': '${_barangay!.trim()}, ${_city!.trim()}',
          'workers': _effectiveWorkers,
          'unit_offer': _offerAmount,
          'end_asap': _asap,
          'end_at': _asap ? null : _end?.toUtc().toIso8601String(),
          'answers': publicAnswers,
          'private': {
            'address':
                '${_address.text.trim()}, ${_barangay!.trim()}, ${_city!.trim()}',
            'contact': _contact.text.trim(),
            'answers':
                personalAnswerSummary(_subcategory, _answers, private: true),
            'photos': [
              for (final photo in _photos)
                {'name': photo.name, 'data': base64Encode(photo.bytes)}
            ],
          },
        },
      );
      _submissionError = _marketplace.lastCreateError;
    } catch (_) {
      _submissionError =
          'Could not confirm your request. Your details are still here; retry to check or submit it.';
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _createdJob = job;
      _postSucceeded = job != null;
    });
    _toStep(_resultStep);
    if (job != null) widget.onJobCreated();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding =
        MediaQuery.sizeOf(context).width < 360 ? 16.0 : 28.0;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _odgBlue),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle:
              const TextStyle(color: _odgPale, fontWeight: FontWeight.w700),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _odgBlue, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _odgBlue, width: 2.5),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 32, horizontalPadding, 40),
                  child: _step == _resultStep ? _buildResult() : _buildForm(),
                ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _ProgressHeader(
          step: _isSpecialized ? _step : _step + 1,
          count: _isSpecialized || _isPersonal ? 5 : 4,
        ),
        const SizedBox(height: 28),
        if (_isVehicleRepair)
          _VehicleHeader(vehicleType: _vehicleType)
        else if (_isApplianceRepair)
          _ApplianceHeader(applianceType: _applianceType)
        else if (_isDeviceRepair)
          _DeviceHeader(deviceType: _deviceType)
        else if (_isChosenHomeRepair)
          _ChosenHomeRepairHeader(subcategory: _subcategory)
        else if (_isChosenPersonalCare)
          _ChosenPersonalCareHeader(subcategory: _subcategory)
        else
          _ServiceHeader(
            category: _category,
            subcategory: _subcategory,
            onCategoryChanged: (value) => setState(() {
              _category = value;
              _subcategory = _subcategories[value]!.first;
              _answers.clear();
              _step = 0;
            }),
            onSubcategoryChanged: (value) => setState(() {
              _subcategory = value;
              _answers.clear();
              _step = 0;
            }),
            categories: _subcategories,
          ),
        const SizedBox(height: 28),
        if (_isVehicleRepair && _step == 0) _buildVehicleTypeStep(),
        if (_isVehicleRepair && _step == 1) _buildVehicleDetailsStep(),
        if (_isApplianceRepair && _step == 0) _buildApplianceTypeStep(),
        if (_isApplianceRepair && _step == 1) _buildApplianceDetailsStep(),
        if (_isDeviceRepair && _step == 0) _buildDeviceTypeStep(),
        if (_isDeviceRepair && _step == 1) _buildDeviceDetailsStep(),
        if (_isPersonal && _step == 0)
          PersonalServiceForm(
            service: _subcategory,
            answers: _answers,
            onChanged: (key, value) => setState(() => _answers[key] = value),
          ),
        if (_step == _locationStep) _buildLocationStep(),
        if (_step == _detailsStep) _buildDetailsStep(),
        if (_step == _reviewStep) _buildReviewStep(),
        const SizedBox(height: 28),
        _NavigationButtons(
          nextLabel: _step == _reviewStep ? 'GRIND!' : 'NEXT',
          onBack: _back,
          onNext: _next,
        ),
      ],
    );
  }

  Widget _buildVehicleTypeStep() {
    const vehicles = <(String, IconData)>[
      ('4 Wheels', Icons.directions_car_rounded),
      ('Motorcycle', Icons.two_wheeler_rounded),
      ('EV', Icons.electric_car_rounded),
      ('Trucks', Icons.local_shipping_rounded),
      ('Bike', Icons.pedal_bike_rounded),
      ('e-Bike', Icons.electric_bike_rounded),
    ];
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vehicles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _responsiveColumnCount(context),
            childAspectRatio: .9,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            final selected = _vehicleType == vehicle.$1;
            return InkWell(
              onTap: () => setState(() => _vehicleType = vehicle.$1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE3F3F8) : Colors.white,
                  border:
                      selected ? Border.all(color: _odgBlue, width: 2) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(vehicle.$2, size: 58, color: _odgBlue),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(child: _AdaptiveChoiceLabel(vehicle.$1)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 26),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildVehicleDetailsStep() {
    return Column(
      children: [
        TextField(
          controller: _vehicleBrand,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Brand'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _vehicleModel,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Model'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _vehicleYear,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration:
                    const InputDecoration(hintText: 'Year', counterText: ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _YesNoQuestion(
          label: 'Willing to bring car to shop if needed?',
          value: _canBringToShop,
          onChanged: (value) => setState(() {
            _canBringToShop = value;
            if (!value) _needsTowing = null;
          }),
        ),
        if (_canBringToShop == true)
          _YesNoQuestion(
            label: 'If Yes, do you require towing service?',
            value: _needsTowing,
            onChanged: (value) => setState(() => _needsTowing = value),
          ),
        _YesNoQuestion(
          label: 'Are you the registered vehicle owner?',
          value: _isRegisteredOwner,
          onChanged: (value) => setState(() => _isRegisteredOwner = value),
        ),
        const SizedBox(height: 24),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildApplianceTypeStep() {
    const appliances = <(String, IconData)>[
      ('HVAC', Icons.ac_unit_rounded),
      ('Refrigerator', Icons.kitchen_rounded),
      ('Stove & Oven', Icons.local_fire_department_rounded),
      ('Electric Fan', Icons.mode_fan_off_rounded),
      ('Washer & Dryer', Icons.local_laundry_service_rounded),
      ('Television', Icons.tv_rounded),
    ];
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appliances.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _responsiveColumnCount(context),
            childAspectRatio: .82,
            crossAxisSpacing: 8,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final appliance = appliances[index];
            final selected = _applianceType == appliance.$1;
            return InkWell(
              onTap: () => setState(() => _applianceType = appliance.$1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE3F3F8) : Colors.white,
                  border:
                      selected ? Border.all(color: _odgBlue, width: 2) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(appliance.$2, size: 54, color: _odgBlue),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(child: _AdaptiveChoiceLabel(appliance.$1)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 26),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildApplianceDetailsStep() {
    const brands = [
      'Asahi',
      'Carrier',
      'Condura',
      'Hanabishi',
      'LG',
      'Panasonic',
      'Samsung',
      'Sharp',
      'Whirlpool',
      'Other',
    ];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _applianceBrand.text.isEmpty ? null : _applianceBrand.text,
          isExpanded: true,
          hint: const Text('Brand'),
          items: brands
              .map(
                  (brand) => DropdownMenuItem(value: brand, child: Text(brand)))
              .toList(),
          onChanged: (value) =>
              setState(() => _applianceBrand.text = value ?? ''),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _applianceModel,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Model (optional)'),
        ),
        const SizedBox(height: 18),
        _YesNoQuestion(
          label: 'Do you require Home Service?',
          value: _requiresHomeService,
          onChanged: (value) => setState(() {
            _requiresHomeService = value;
            if (value) _requiresPickup = false;
          }),
        ),
        if (_requiresHomeService == false)
          _YesNoQuestion(
            label:
                'Service Provider may bring your unit to their shop. Do you require pickup / delivery service?',
            value: _requiresPickup,
            onChanged: (value) => setState(() => _requiresPickup = value),
          ),
        if (_requiresHomeService == false)
          const Text(
            'By selecting No, you understand that you are responsible for '
            'delivering the unit to the Service Provider’s shop unless pickup '
            'or delivery is requested.',
            style: TextStyle(
              color: _odgBlue,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: 24),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildDeviceTypeStep() {
    const devices = <(String, IconData)>[
      ('Mobile Phone', Icons.phone_android_rounded),
      ('Tablet', Icons.tablet_android_rounded),
      ('Laptop', Icons.laptop_rounded),
      ('Computer', Icons.desktop_windows_rounded),
      ('Sound System', Icons.music_note_rounded),
      ('Peripherals', Icons.mouse_rounded),
      ('Digital Camera', Icons.photo_camera_rounded),
      ('Drone', Icons.flight_rounded),
    ];
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: devices.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _responsiveColumnCount(context),
            childAspectRatio: .84,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final device = devices[index];
            final selected = _deviceType == device.$1;
            return InkWell(
              onTap: () => setState(() => _deviceType = device.$1),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE3F3F8) : Colors.white,
                  border:
                      selected ? Border.all(color: _odgBlue, width: 2) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(device.$2, size: 52, color: _odgBlue),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Flexible(child: _AdaptiveChoiceLabel(device.$1)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildDeviceDetailsStep() {
    const brands = [
      'Apple',
      'Acer',
      'Asus',
      'Canon',
      'Dell',
      'DJI',
      'HP',
      'Huawei',
      'Lenovo',
      'Logitech',
      'Samsung',
      'Sony',
      'Other',
    ];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _applianceBrand.text.isEmpty ? null : _applianceBrand.text,
          isExpanded: true,
          hint: const Text('Brand'),
          items: brands
              .map(
                  (brand) => DropdownMenuItem(value: brand, child: Text(brand)))
              .toList(),
          onChanged: (value) =>
              setState(() => _applianceBrand.text = value ?? ''),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _applianceModel,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Model'),
        ),
        const SizedBox(height: 18),
        _YesNoQuestion(
          label: 'Do you require Home Service?',
          value: _requiresHomeService,
          onChanged: (value) => setState(() {
            _requiresHomeService = value;
            if (value) _requiresPickup = false;
          }),
        ),
        if (_requiresHomeService == false)
          _YesNoQuestion(
            label:
                'Service Provider may bring your unit to their shop. Do you require pickup / delivery service?',
            value: _requiresPickup,
            onChanged: (value) => setState(() => _requiresPickup = value),
          ),
        if (_requiresHomeService == false)
          const Text(
            'By selecting No, you understand that you are responsible for '
            'delivering the device to the Service Provider’s shop unless '
            'pickup or delivery is requested.',
            style: TextStyle(
              color: _odgBlue,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: 24),
        const _AdPanel(),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      children: [
        TextField(
          controller: _address,
          decoration: InputDecoration(
            hintText: 'Home / Building / Unit Number',
            suffixIcon: IconButton(
              tooltip: 'Use current location',
              onPressed: _useCurrentLocation,
              icon: const Icon(Icons.location_on, color: _odgBlue),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackFields = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final barangay = TextFormField(
              key: const ValueKey('barangay'),
              initialValue: _barangay,
              decoration: const InputDecoration(labelText: 'Barangay'),
              maxLength: 80,
              onChanged: (value) => _barangay = value,
            );
            final city = TextFormField(
              key: const ValueKey('city'),
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'City / Town'),
              maxLength: 80,
              onChanged: (value) => _city = value,
            );
            if (stackFields) {
              return Column(
                children: [barangay, const SizedBox(height: 14), city],
              );
            }
            return Row(
              children: [
                Expanded(child: barangay),
                const SizedBox(width: 12),
                Expanded(child: city),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _contact,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Contact Number',
            suffixIcon: Icon(Icons.phone, color: _odgBlue),
          ),
        ),
        const SizedBox(height: 14),
        _DateField(
          label: _start == null ? 'Service Date Start' : _formatDate(_start!),
          onTap: () => _pickDate(true),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.trailing,
          title: const Text('Set to Immediately',
              textAlign: TextAlign.right,
              style: TextStyle(color: _odgBlue, fontWeight: FontWeight.w700)),
          value: _immediate,
          onChanged: (value) => setState(() {
            _immediate = value ?? false;
            if (_immediate) _start = null;
          }),
        ),
        _DateField(
          label: _end == null ? 'Service Date End' : _formatDate(_end!),
          onTap: () => _pickDate(false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.trailing,
          title: const Text('Set to ASAP',
              textAlign: TextAlign.right,
              style: TextStyle(color: _odgBlue, fontWeight: FontWeight.w700)),
          value: _asap,
          onChanged: (value) => setState(() {
            _asap = value ?? false;
            if (_asap) _end = null;
          }),
        ),
        const SizedBox(height: 12),
        const _AdPanel(),
      ],
    );
  }

  int _responsiveColumnCount(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width < 360 || media.textScaler.scale(14) > 18 ? 2 : 3;
  }

  Widget _buildDetailsStep() {
    return Column(
      children: [
        _ClientSummary(
          address: '${_address.text}, $_barangay, $_city',
          contact: _contact.text,
          date: _schedule,
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _title,
          decoration: InputDecoration(
              labelText: _isPersonal
                  ? 'Service request title'
                  : 'What do you need fixed?'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 6,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Describe what you need done...',
            helperText:
                'These notes are public. Keep contact and health details in the private fields.',
            helperMaxLines: 3,
            alignLabelWithHint: true,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _attachPhotos,
            icon: const Icon(Icons.photo_outlined),
            label: Text(_photos.isEmpty
                ? 'Attach Photos'
                : '${_photos.length} photo(s) selected'),
          ),
        ),
        _photoPreview(editable: true),
        const SizedBox(height: 8),
        TextField(
          controller: _budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              hintText: _perWorker
                  ? 'Your offer amount (₱) for each worker'
                  : 'Your offer amount (₱)'),
        ),
        const SizedBox(height: 12),
        if (!_isSpecialized && !_isPersonal)
          TextField(
            controller: _workers,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Number of workers'),
          ),
        const SizedBox(height: 12),
        _TermsNotice(
            personal: _isPersonal,
            pickup: _isApplianceRepair || _isDeviceRepair),
      ],
    );
  }

  Widget _buildReviewStep() {
    final workers = _effectiveWorkers;
    final each = _offerAmount ?? 0;
    return Column(
      children: [
        _ClientSummary(
          address: '${_address.text}, $_barangay, $_city',
          contact: _contact.text,
          date: _schedule,
        ),
        if (_perWorker) ...[
          const SizedBox(height: 8),
          Text(
            '${_effectiveWorkers} worker(s) • '
            '₱${(_offerAmount ?? 0).toStringAsFixed(2)} each • '
            '₱${(_effectiveWorkers * (_offerAmount ?? 0)).toStringAsFixed(2)} ${_payment == null ? '' : 'via $_payment'}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _odgBlue, fontWeight: FontWeight.w800),
          ),
        ],
        if (_isVehicleRepair) ...[
          const SizedBox(height: 10),
          _VehicleSummary(
            type: _vehicleType!,
            brand: _vehicleBrand.text,
            model: _vehicleModel.text,
            year: _vehicleYear.text,
            canBringToShop: _canBringToShop!,
            needsTowing: _needsTowing ?? false,
            isRegisteredOwner: _isRegisteredOwner!,
          ),
        ],
        if (_isApplianceRepair) ...[
          const SizedBox(height: 10),
          _ApplianceSummary(
            type: _applianceType!,
            brand: _applianceBrand.text,
            model: _applianceModel.text,
            requiresHomeService: _requiresHomeService!,
            requiresPickup:
                _requiresHomeService == false && _requiresPickup == true,
          ),
        ],
        if (_isDeviceRepair) ...[
          const SizedBox(height: 10),
          _DeviceSummary(
            type: _deviceType!,
            brand: _applianceBrand.text,
            model: _applianceModel.text,
            requiresHomeService: _requiresHomeService!,
            requiresPickup:
                _requiresHomeService == false && _requiresPickup == true,
          ),
        ],
        if (_isPersonal) _personalSummary(),
        const SizedBox(height: 20),
        Text(_title.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _odgBlue, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(_description.text,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _odgBlue, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Text(_photos.isEmpty
            ? 'No Photos Attached'
            : '${_photos.length} Photo(s) Attached'),
        _photoPreview(),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _payment,
          isExpanded: true,
          hint: const Text('Select Payment Option'),
          items: const [
            'Card (secure checkout)',
            'Cash on Delivery (after service)',
          ]
              .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (value) => setState(() => _payment = value),
        ),
        const SizedBox(height: 12),
        Text(
          !_perWorker
              ? 'Offer amount: ₱${each.toStringAsFixed(2)}'
              : '$workers worker(s) • ₱${each.toStringAsFixed(2)} each • '
                  '₱${(workers * each).toStringAsFixed(2)} total offer',
          style: const TextStyle(color: _odgBlue, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _TermsNotice(
            personal: _isPersonal,
            pickup: _isApplianceRepair || _isDeviceRepair),
      ],
    );
  }

  Widget _buildResult() {
    final success = _postSucceeded == true;
    return Column(
      children: [
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: success ? _odgBlue : _odgRed,
              size: 88,
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                success
                    ? 'JOB REQUEST\nSUCCESSFULLY\nPOSTED!'
                    : 'JOB REQUEST\nPOST FAILED!',
                style: const TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 24,
                  height: .95,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Address, contact details, private answers and photos are shared only with your accepted provider.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _odgBlue, fontSize: 12),
        ),
        const SizedBox(height: 20),
        if (success)
          Text('Reference #: ${_shortReference(_createdJob!.id)}',
              style: const TextStyle(
                  color: _odgBlue, fontWeight: FontWeight.w800)),
        Text.rich(
          TextSpan(
            text: 'Status : ',
            children: [
              TextSpan(
                text: success ? 'Pending' : 'Failed',
                style: TextStyle(color: success ? Colors.orange : _odgRed),
              ),
            ],
          ),
          style: const TextStyle(color: _odgBlue, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 26),
        Icon(_categoryIcon, color: _odgBlue, size: 48),
        Text(
            _isVehicleRepair
                ? _vehicleType!
                : _isApplianceRepair
                    ? _applianceType!
                    : _isDeviceRepair
                        ? _deviceType!
                        : _subcategory,
            style: const TextStyle(
                color: _odgBlue, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 22),
        _ClientSummary(
          address: '******** ${_city ?? ''}',
          contact: _maskContact(_contact.text),
          date: _schedule,
        ),
        if (_perWorker) ...[
          const SizedBox(height: 8),
          Text(
            '${_effectiveWorkers} worker(s) • '
            '₱${(_offerAmount ?? 0).toStringAsFixed(2)} each • '
            '₱${(_effectiveWorkers * (_offerAmount ?? 0)).toStringAsFixed(2)} ${_payment == null ? '' : 'via $_payment'}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _odgBlue, fontWeight: FontWeight.w800),
          ),
        ],
        if (!_perWorker) ...[
          const SizedBox(height: 8),
          Text(
            'Offer Amount: ₱${(_offerAmount ?? 0).toStringAsFixed(2)} ${_payment == null ? '' : 'via $_payment'}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _odgBlue, fontWeight: FontWeight.w800),
          ),
        ],
        if (_isDeviceRepair) ...[
          const SizedBox(height: 10),
          _DeviceSummary(
            type: _deviceType!,
            brand: _applianceBrand.text,
            model: _applianceModel.text,
            requiresHomeService: _requiresHomeService!,
            requiresPickup:
                _requiresHomeService == false && _requiresPickup == true,
          ),
        ],
        if (_isVehicleRepair) ...[
          const SizedBox(height: 10),
          _VehicleSummary(
            type: _vehicleType!,
            brand: _vehicleBrand.text,
            model: _vehicleModel.text,
            year: _vehicleYear.text,
            canBringToShop: _canBringToShop!,
            needsTowing: _needsTowing ?? false,
            isRegisteredOwner: _isRegisteredOwner!,
          ),
        ],
        if (_isApplianceRepair) ...[
          const SizedBox(height: 10),
          _ApplianceSummary(
            type: _applianceType!,
            brand: _applianceBrand.text,
            model: _applianceModel.text,
            requiresHomeService: _requiresHomeService!,
            requiresPickup:
                _requiresHomeService == false && _requiresPickup == true,
          ),
        ],
        if (_isPersonal) _personalSummary(),
        const SizedBox(height: 20),
        Text(_title.text,
            style: const TextStyle(
                color: _odgBlue, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(_description.text,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: _odgBlue, fontWeight: FontWeight.w600)),
        const SizedBox(height: 22),
        Text(_photos.isEmpty
            ? 'No Photos Attached'
            : '${_photos.length} Photo(s) Attached'),
        _photoPreview(),
        const SizedBox(height: 28),
        if (!success && _submissionError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_submissionError!, textAlign: TextAlign.center),
          ),
        if (!success)
          _OdgButton(
              label: 'RETRY',
              icon: Icons.refresh,
              onPressed: () {
                _submit();
              }),
        if (!success) const SizedBox(height: 10),
        _OdgButton(
          label: success ? 'HOME' : 'BACK',
          icon: Icons.arrow_back,
          onPressed: success
              ? () => Navigator.popUntil(context, (route) => route.isFirst)
              : () => setState(() {
                    _postSucceeded = null;
                    _step = _reviewStep;
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                  }),
        ),
      ],
    );
  }

  Widget _personalSummary() => Column(children: [
        for (final entry
            in personalAnswerSummary(_subcategory, _answers).entries)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${entry.key}: ${entry.value}',
                    style: const TextStyle(color: _odgBlue)),
              )),
      ]);

  IconData get _categoryIcon {
    switch (_category) {
      case 'Automotive':
        return Icons.car_repair;
      case 'Personal Care':
        return Icons.volunteer_activism;
      case 'Device Repair':
        return Icons.phone_android;
      case 'Appliance Repair':
        return Icons.tv;
      default:
        return Icons.home_repair_service;
    }
  }

  static String _formatDate(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
            ? value.hour - 12
            : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day}/${value.year} $hour:$minute $period';
  }

  static String _maskContact(String value) {
    if (value.length < 5) return '*******';
    return '${value.substring(0, value.length - 4)} ****';
  }

  static String _shortReference(String id) =>
      id.length <= 12 ? id.toUpperCase() : id.substring(0, 12).toUpperCase();

  static String _yesNo(bool? value) => value == true ? 'Yes' : 'No';
}

class _AdaptiveChoiceLabel extends StatelessWidget {
  final String label;

  const _AdaptiveChoiceLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const style = TextStyle(
          color: _odgBlue,
          fontFamily: 'serif',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.08,
        );
        if (!label.contains(' ')) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: style,
            ),
          );
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Text(
              label,
              textAlign: TextAlign.center,
              softWrap: true,
              textWidthBasis: TextWidthBasis.longestLine,
              style: style,
            ),
          ),
        );
      },
    );
  }
}

class _ChosenHomeRepairHeader extends StatelessWidget {
  final String subcategory;

  const _ChosenHomeRepairHeader({required this.subcategory});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_rounded, color: _odgBlue, size: 45),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Home Repair',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(subcategory), color: _odgBlue, size: 45),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                subcategory,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(String service) {
    switch (service) {
      case 'Carpentry':
        return Icons.carpenter_rounded;
      case 'Plumbing':
        return Icons.plumbing_rounded;
      case 'Structural':
      case 'Masonry':
        return Icons.foundation_rounded;
      case 'Electrical':
        return Icons.electric_bolt_rounded;
      case 'Flooring':
      case 'Tile Setting':
        return Icons.grid_on_rounded;
      case 'Roofing':
        return Icons.roofing_rounded;
      case 'Metalwork':
      case 'Metal Fabrication':
        return Icons.hardware_rounded;
      case 'Glasswork':
        return Icons.window_rounded;
      case 'Upholstery':
        return Icons.chair_rounded;
      case 'Painting':
        return Icons.format_paint_rounded;
      case 'Locksmith':
        return Icons.key_rounded;
      case 'Landscaping':
        return Icons.park_rounded;
      default:
        return Icons.home_repair_service_rounded;
    }
  }
}

class _ChosenPersonalCareHeader extends StatelessWidget {
  final String subcategory;

  const _ChosenPersonalCareHeader({required this.subcategory});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism_rounded, color: _odgBlue, size: 45),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Personal Services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(subcategory), color: _odgBlue, size: 45),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                subcategory,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(String service) {
    switch (service) {
      case 'Barber':
        return Icons.content_cut_rounded;
      case 'Nail Care':
      case 'Manicure & Pedicure':
        return Icons.back_hand_rounded;
      case 'Hair Styling, Coloring & Care':
        return Icons.face_retouching_natural_rounded;
      case 'Massage':
        return Icons.spa_rounded;
      case 'Caregiving / Nursing':
      case 'Elderly Care':
        return Icons.elderly_rounded;
      case 'Babysitting':
      case 'Child Care':
        return Icons.child_care_rounded;
      case 'Physical Therapy':
        return Icons.accessibility_new_rounded;
      case 'Occupational Therapy':
        return Icons.health_and_safety_rounded;
      case 'Tutorial':
      case 'Tutorial Services':
        return Icons.school_rounded;
      case 'Housekeeping':
      case 'House Keeping':
        return Icons.cleaning_services_rounded;
      case 'Pet Care':
      case 'Pet Grooming':
        return Icons.pets_rounded;
      case 'Tailoring':
        return Icons.content_cut_rounded;
      case 'Landscaping':
        return Icons.park_rounded;
      case 'Laundry & Ironing':
        return Icons.local_laundry_service_rounded;
      default:
        return Icons.volunteer_activism_rounded;
    }
  }
}

class _VehicleHeader extends StatelessWidget {
  final String? vehicleType;

  const _VehicleHeader({required this.vehicleType});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_input_component_rounded,
                color: _odgBlue, size: 45),
            SizedBox(width: 10),
            Flexible(
              child: Text('Vehicle Repair',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _odgBlue,
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (vehicleType != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_vehicleIcon(vehicleType!), color: _odgBlue, size: 48),
              const SizedBox(width: 12),
              Flexible(
                child: Text(vehicleType!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _odgBlue,
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static IconData _vehicleIcon(String type) {
    switch (type) {
      case 'Motorcycle':
        return Icons.two_wheeler;
      case 'EV':
        return Icons.electric_car;
      case 'Trucks':
        return Icons.local_shipping;
      case 'Bike':
        return Icons.pedal_bike;
      case 'e-Bike':
        return Icons.electric_bike;
      default:
        return Icons.directions_car;
    }
  }
}

class _ApplianceHeader extends StatelessWidget {
  final String? applianceType;

  const _ApplianceHeader({required this.applianceType});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_rounded, color: _odgBlue, size: 45),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Appliance Repair',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (applianceType != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_applianceIcon(applianceType!), color: _odgBlue, size: 45),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  applianceType!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _odgBlue,
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static IconData _applianceIcon(String type) {
    switch (type) {
      case 'HVAC':
        return Icons.ac_unit;
      case 'Refrigerator':
        return Icons.kitchen;
      case 'Stove & Oven':
        return Icons.local_fire_department;
      case 'Electric Fan':
        return Icons.mode_fan_off;
      case 'Washer & Dryer':
        return Icons.local_laundry_service;
      default:
        return Icons.tv;
    }
  }
}

class _DeviceHeader extends StatelessWidget {
  final String? deviceType;

  const _DeviceHeader({required this.deviceType});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android_rounded, color: _odgBlue, size: 45),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Device Repair',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (deviceType != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_deviceIcon(deviceType!), color: _odgBlue, size: 45),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  deviceType!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _odgBlue,
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static IconData _deviceIcon(String type) {
    switch (type) {
      case 'Tablet':
        return Icons.tablet_android;
      case 'Laptop':
        return Icons.laptop;
      case 'Computer':
        return Icons.desktop_windows;
      case 'Sound System':
        return Icons.music_note;
      case 'Peripherals':
        return Icons.mouse;
      case 'Digital Camera':
        return Icons.photo_camera;
      case 'Drone':
        return Icons.flight;
      default:
        return Icons.phone_android;
    }
  }
}

class _YesNoQuestion extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _YesNoQuestion({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _odgBlue,
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Yes'),
                  value: true,
                  groupValue: value,
                  onChanged: (answer) {
                    if (answer != null) onChanged(answer);
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('No'),
                  value: false,
                  groupValue: value,
                  onChanged: (answer) {
                    if (answer != null) onChanged(answer);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplianceSummary extends StatelessWidget {
  final String type;
  final String brand;
  final String model;
  final bool requiresHomeService;
  final bool requiresPickup;

  const _ApplianceSummary({
    required this.type,
    required this.brand,
    required this.model,
    required this.requiresHomeService,
    required this.requiresPickup,
  });

  @override
  Widget build(BuildContext context) {
    String answer(bool value) => value ? 'Yes' : 'No';
    return DefaultTextStyle(
      style: const TextStyle(color: _odgBlue, fontSize: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appliance:  $type'),
          Text(
              'Brand:  $brand    Model:  ${model.trim().isEmpty ? 'N/A' : model}'),
          Text('Requires Home Service:  ${answer(requiresHomeService)}'),
          if (!requiresHomeService)
            Text('Requires pickup / delivery:  ${answer(requiresPickup)}'),
        ],
      ),
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  final String type;
  final String brand;
  final String model;
  final bool requiresHomeService;
  final bool requiresPickup;

  const _DeviceSummary({
    required this.type,
    required this.brand,
    required this.model,
    required this.requiresHomeService,
    required this.requiresPickup,
  });

  @override
  Widget build(BuildContext context) {
    String answer(bool value) => value ? 'Yes' : 'No';
    return DefaultTextStyle(
      style: const TextStyle(color: _odgBlue, fontSize: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device:  $type'),
          Text(
              'Brand:  $brand    Model:  ${model.trim().isEmpty ? 'N/A' : model}'),
          Text('Requires Home Service:  ${answer(requiresHomeService)}'),
          if (!requiresHomeService)
            Text('Requires pickup / delivery:  ${answer(requiresPickup)}'),
        ],
      ),
    );
  }
}

class _VehicleSummary extends StatelessWidget {
  final String type;
  final String brand;
  final String model;
  final String year;
  final bool canBringToShop;
  final bool needsTowing;
  final bool isRegisteredOwner;

  const _VehicleSummary({
    required this.type,
    required this.brand,
    required this.model,
    required this.year,
    required this.canBringToShop,
    required this.needsTowing,
    required this.isRegisteredOwner,
  });

  @override
  Widget build(BuildContext context) {
    String answer(bool value) => value ? 'Yes' : 'No';
    return DefaultTextStyle(
      style: const TextStyle(color: _odgBlue, fontSize: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vehicle:  $type'),
          Text('Brand:  $brand    Model:  $model'),
          Text('Year:  $year'),
          Text('Willing to bring to shop:  ${answer(canBringToShop)}'),
          Text('Requires towing:  ${answer(needsTowing)}'),
          Text('Registered owner:  ${answer(isRegisteredOwner)}'),
        ],
      ),
    );
  }
}

class _AdPanel extends StatelessWidget {
  const _AdPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('Ad space',
          style: TextStyle(color: Color(0xFF6666FF), fontSize: 22)),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;
  final int count;

  const _ProgressHeader({required this.step, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (index) => Expanded(
          child: Container(
            height: 24,
            margin: EdgeInsets.only(right: index == count - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: index == step ? _odgBlue : Colors.white,
              border: Border.all(color: _odgBlue, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceHeader extends StatelessWidget {
  final String category;
  final String subcategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSubcategoryChanged;
  final Map<String, List<String>> categories;

  const _ServiceHeader({
    required this.category,
    required this.subcategory,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_rounded, color: _odgBlue, size: 45),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: category,
              underline: const SizedBox(),
              style: const TextStyle(
                  color: _odgBlue, fontSize: 18, fontWeight: FontWeight.w800),
              items: categories.keys
                  .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onCategoryChanged(value);
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handyman_rounded, color: _odgBlue, size: 44),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: subcategory,
              underline: const SizedBox(),
              style: const TextStyle(
                  color: _odgBlue, fontSize: 18, fontWeight: FontWeight.w800),
              items: categories[category]!
                  .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onSubcategoryChanged(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ClientSummary extends StatelessWidget {
  final String address;
  final String contact;
  final String date;

  const _ClientSummary({
    required this.address,
    required this.contact,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(color: _odgBlue, fontSize: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address:  $address'),
          Text('Contact Number:  $contact'),
          Text('Service Date:  $date'),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_month, color: _odgBlue),
        ),
        child: Text(label,
            style:
                const TextStyle(color: _odgPale, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _TermsNotice extends StatelessWidget {
  final bool personal;
  final bool pickup;
  const _TermsNotice({this.personal = false, this.pickup = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${personal ? 'Offer includes labor, travel and essentials.' : pickup ? 'Offer covers labor and requested pickup. Parts are separate unless agreed with the provider.' : 'Offer covers labor only. Materials are separate unless agreed with the provider.'}\n'
      'Providers may propose a different amount. You choose whether to accept their offer. Payment is arranged after a provider is selected.',
      textAlign: TextAlign.center,
      style: TextStyle(color: _odgBlue, fontSize: 11),
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  final String nextLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _NavigationButtons({
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OdgButton(
              label: 'BACK', icon: Icons.arrow_back, onPressed: onBack),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: _OdgButton(
              label: nextLabel, icon: Icons.arrow_forward, onPressed: onNext),
        ),
      ],
    );
  }
}

class _OdgButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _OdgButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              maxLines: 1,
              style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _odgBlue,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
