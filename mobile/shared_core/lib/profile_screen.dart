import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'models.dart';
import 'biometric_service.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _biometricService = BiometricService();
  UserProfile? _profile;
  bool _isLoading = false;
  bool _biometricsSupported = false;
  bool _biometricsEnabled = false;
  StreamSubscription<UserProfile?>? _userSubscription;

  // Controllers for Establishment
  final _estNameController = TextEditingController();
  final _estTypeController = TextEditingController();
  final _estRegController = TextEditingController();
  final _estAddrController = TextEditingController();

  final List<String> _allCategories = [
    'Home Repair',
    'Personal Care',
    'Automotive',
    'Device Repair',
    'Appliance Repair'
  ];

  @override
  void initState() {
    super.initState();
    _profile = _authService.currentUser;
    _syncControllers();
    if (_profile == null) {
      _loadProfile();
    } else {
      _fetchBiometricStatus();
    }
    _userSubscription = _authService.userStream.listen((user) {
      if (mounted) {
        setState(() {
          _profile = user;
          _syncControllers();
        });
      }
    });
  }

  void _syncControllers() {
    if (_profile?.establishment != null) {
      _estNameController.text = _profile!.establishment!.name;
      _estTypeController.text = _profile!.establishment!.businessType;
      _estRegController.text = _profile!.establishment!.registrationNumber;
      _estAddrController.text = _profile!.establishment!.address;
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _estNameController.dispose();
    _estTypeController.dispose();
    _estRegController.dispose();
    _estAddrController.dispose();
    super.dispose();
  }

  Future<void> _fetchBiometricStatus() async {
    final supported = await _biometricService.isBiometricsSupported();
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _biometricsSupported = supported;
        _biometricsEnabled = enabled;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final p = await _authService.getProfile();
    await _fetchBiometricStatus();
    if (mounted) {
      setState(() {
        _profile = p;
        _syncControllers();
        _isLoading = false;
      });
    }
  }

  void _saveProfile() async {
    if (_profile == null) return;
    setState(() => _isLoading = true);
    
    // Update logic would need to handle establishment in a real app
    await _authService.updateProfile(_profile!.fullName, _profile!.bio, _profile!.skills);
    await _loadProfile();
  }

  void _topUpWallet() async {
    // Placeholder for Gcash/Maya Topup
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: const Text('Connect your GCash or Maya to ensure daily commissions are covered for long-term bookings.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Link GCash')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading profile.', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final bool isProvider = _profile!.role == 'provider';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (isProvider) _buildStatsCard(),
            const SizedBox(height: 24),
            _buildWalletCard(),
            const SizedBox(height: 24),
            _buildGeneralInfo(),
            if (isProvider) ...[
              const SizedBox(height: 24),
              _buildEstablishmentSection(),
              const SizedBox(height: 24),
              _buildServiceCategories(),
            ],
            const SizedBox(height: 24),
            _buildSecuritySettings(),
            const SizedBox(height: 40),
            _buildSignOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.indigo,
              child: Text(_profile!.fullName.substring(0, 1), style: const TextStyle(fontSize: 40, color: Colors.white)),
            ),
            if (_profile!.isVerified)
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.verified, color: Colors.blue, size: 20),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(_profile!.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(_profile!.email, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade100)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Jobs', _profile!.completedJobsCount.toString()),
          _buildStatItem('Rating', '${_profile!.averageRating.toStringAsFixed(1)} ★'),
          _buildStatItem('Rebooks', _profile!.rebookCount.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWalletCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Platform Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('₱${_profile!.walletBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(onPressed: _topUpWallet, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Top Up')),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('General Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _profile!.fullName,
          decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
          onChanged: (val) => _profile = UserProfile(
            id: _profile!.id, fullName: val, email: _profile!.email, role: _profile!.role,
            isVerified: _profile!.isVerified, bio: _profile!.bio, skills: _profile!.skills,
            completedJobsCount: _profile!.completedJobsCount, averageRating: _profile!.averageRating,
            rebookCount: _profile!.rebookCount, walletBalance: _profile!.walletBalance,
            establishment: _profile!.establishment
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _profile!.bio,
          decoration: const InputDecoration(labelText: 'Bio / Description', border: OutlineInputBorder()),
          maxLines: 3,
          onChanged: (val) => _profile = UserProfile(
            id: _profile!.id, fullName: _profile!.fullName, email: _profile!.email, role: _profile!.role,
            isVerified: _profile!.isVerified, bio: val, skills: _profile!.skills,
            completedJobsCount: _profile!.completedJobsCount, averageRating: _profile!.averageRating,
            rebookCount: _profile!.rebookCount, walletBalance: _profile!.walletBalance,
            establishment: _profile!.establishment
          ),
        ),
      ],
    );
  }

  Widget _buildEstablishmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business Establishment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _estNameController, decoration: const InputDecoration(labelText: 'Shop Name (e.g. Juan Repair Shop)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _estTypeController, decoration: const InputDecoration(labelText: 'Business Type (e.g. Automotive, Salon)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _estRegController, decoration: const InputDecoration(labelText: 'Registration Number', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _estAddrController, decoration: const InputDecoration(labelText: 'Physical Address', border: OutlineInputBorder())),
      ],
    );
  }

  Widget _buildServiceCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Service Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _allCategories.map((cat) {
            final isSelected = _profile!.skills.contains(cat);
            return FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _profile!.skills.add(cat);
                  } else {
                    _profile!.skills.remove(cat);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Security Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_biometricsSupported) ...[
          if (_profile!.role == 'customer') ...[
            if (_profile!.isVerified)
              SwitchListTile(
                title: const Text('Biometric Login'),
                value: _biometricsEnabled,
                onChanged: (bool value) async {
                  await _biometricService.setBiometricsEnabled(value);
                  setState(() => _biometricsEnabled = value);
                },
              )
            else
              const ListTile(title: Text('Biometric Login'), subtitle: Text('Verification required'), trailing: Icon(Icons.lock_outline, color: Colors.grey)),
          ] else ...[
            const ListTile(title: Text('Biometric Security'), subtitle: Text('Mandatory Lock Enabled'), trailing: Icon(Icons.lock, color: Colors.green)),
          ],
        ],
        if (!_profile!.isVerified) ...[
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.verified_user), label: const Text('Request Verification'), onPressed: _requestVerification, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white))),
        ],
      ],
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        onPressed: () async {
          await _biometricService.clearSettings();
          await _authService.logout();
          if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        },
      ),
    );
  }

  void _requestVerification() async {
    setState(() => _isLoading = true);
    final success = await _authService.verifyMe();
    if (success) {
      await _loadProfile();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification approved!')));
    }
  }
}
