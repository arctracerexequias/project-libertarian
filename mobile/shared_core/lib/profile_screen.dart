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
  bool _isLoading = true;
  bool _biometricsSupported = false;
  bool _biometricsEnabled = false;


  final List<String> _allCategories = [
    'Home Repair', 'Personal Care', 'Automotive', 'Cleaning', 'Device Repair', 'Appliance Repair'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await _authService.getProfile();
    final supported = await _biometricService.isBiometricsSupported();
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _profile = p;
        _biometricsSupported = supported;
        _biometricsEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  void _saveProfile() async {
    if (_profile == null) return;
    setState(() => _isLoading = true);
    await _authService.updateProfile(_profile!.fullName, _profile!.bio, _profile!.skills);
    await _loadProfile();
  }

  void _requestVerification() async {
    setState(() => _isLoading = true);
    final success = await _authService.verifyMe();
    if (success) {
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification approved! (Prototype Mode)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text('Error loading profile.')));

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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_profile!.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                if (_profile!.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.verified, color: Colors.blue, size: 24),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _profile!.fullName,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              onChanged: (val) => _profile = UserProfile(
                id: _profile!.id, fullName: val, email: _profile!.email, role: _profile!.role,
                isVerified: _profile!.isVerified, bio: _profile!.bio, skills: _profile!.skills
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _profile!.bio,
              decoration: const InputDecoration(labelText: 'Bio / Description', border: OutlineInputBorder()),
              maxLines: 3,
              onChanged: (val) => _profile = UserProfile(
                id: _profile!.id, fullName: _profile!.fullName, email: _profile!.email, role: _profile!.role,
                isVerified: _profile!.isVerified, bio: val, skills: _profile!.skills
              ),
            ),
            if (_profile!.role == 'provider') ...[
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('My Service Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
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
            if (_biometricsSupported) ...[
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Security Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              if (_profile!.role == 'customer') ...[
                if (_profile!.isVerified)
                  SwitchListTile(
                    title: const Text('Biometric Login'),
                    subtitle: const Text('Use Face ID / Fingerprint / PIN to log in'),
                    value: _biometricsEnabled,
                    onChanged: (bool value) async {
                      await _biometricService.setBiometricsEnabled(value);
                      setState(() {
                        _biometricsEnabled = value;
                      });
                    },
                  )
                else
                  const ListTile(
                    title: Text('Biometric Login'),
                    subtitle: Text('Verification required to enable biometric login'),
                    trailing: Icon(Icons.lock_outline, color: Colors.grey),
                  ),
              ] else if (_profile!.role == 'provider') ...[
                ListTile(
                  title: const Text('Biometric Security'),
                  subtitle: const Text('Mandatory Lock Enabled'),
                  trailing: const Icon(Icons.lock, color: Colors.green),
                  onTap: () {},
                ),
              ],
            ],
            if (!_profile!.isVerified) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Request Verification'),
                  onPressed: _requestVerification,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }
}
