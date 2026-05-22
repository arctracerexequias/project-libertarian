import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'marketplace_service.dart';
import 'payment_service.dart';
import 'auth_service.dart';
import 'models.dart';
import 'view_bids_screen.dart';
import 'chat_screen.dart';
import 'rating_dialog.dart';
import 'submit_bid_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _marketplaceService = MarketplaceService();
  final _paymentService = PaymentService();
  final _authService = AuthService();
  bool _isFunding = false;
  bool _isChatLoading = false;
  bool _isLoadingProfile = true;
  bool _isActionLoading = false;
  UserProfile? _userProfile;
  Map<String, dynamic>? _escrowStatus;

  @override
  void initState() {
    super.initState();
    _fetchEscrowStatus();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final profile = await _authService.getProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _fetchEscrowStatus() async {
    final status = await _paymentService.getEscrowStatus(widget.job.id);
    if (mounted) {
      setState(() => _escrowStatus = status);
    }
  }

  void _fundEscrow() async {
    setState(() => _isFunding = true);
    final bids = await _marketplaceService.getBids(widget.job.id);
    final acceptedBid = bids.firstWhere((b) => b.status == 'accepted', orElse: () => bids.first);
    
    final result = await _paymentService.initEscrow(widget.job.id, acceptedBid.amount);
    setState(() => _isFunding = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funds secured in escrow!')),
      );
      _fetchEscrowStatus();
    }
  }

  void _releasePayment() async {
    final success = await _paymentService.releaseEscrow(widget.job.id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment released to provider.')),
      );
      _fetchEscrowStatus();
    }
  }

  void _navigateToChat() async {
    setState(() => _isChatLoading = true);
    final profile = await _authService.getProfile();
    setState(() => _isChatLoading = false);

    if (profile != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ChatScreen(jobId: widget.job.id, userId: profile.id)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user profile for chat.')),
      );
    }
  }

  void _acceptJobDirect() async {
    if (widget.job.maxBudget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot accept job: Client has not set an initial offer.')),
      );
      return;
    }
    setState(() => _isActionLoading = true);
    final bid = await _marketplaceService.submitBid(
      jobId: widget.job.id,
      amount: widget.job.maxBudget!,
      estimatedTime: '2 hours',
      message: 'Direct Acceptance of Client Offer.',
    );
    if (bid != null) {
      final success = await _marketplaceService.acceptBid(widget.job.id, bid.id);
      setState(() => _isActionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept job.')),
        );
      }
    } else {
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize job acceptance.')),
      );
    }
  }

  void _updateStatus(JobStatus newStatus) async {
    setState(() => _isActionLoading = true);
    final success = await _marketplaceService.updateJobStatus(widget.job.id, newStatus);
    setState(() => _isActionLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.name.toUpperCase()}')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update job status.')),
      );
    }
  }

  Widget _buildMapSection(bool isProvider) {
    if (widget.job.location == null) {
      return const SizedBox.shrink();
    }

    if (isProvider) {
      if (widget.job.status == JobStatus.published || widget.job.status == JobStatus.bidding) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            children: [
              Icon(Icons.lock, color: Colors.amber.shade800, size: 36),
              const SizedBox(height: 8),
              Text(
                'Location details are hidden',
                style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Accept this job to view the general area.',
                style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
              ),
            ],
          ),
        );
      }

      if (widget.job.status == JobStatus.accepted) {
        // Obfuscate location: stable deterministic offset
        final offsetLat = (widget.job.id.hashCode % 100 - 50) * 0.0001;
        final offsetLng = (widget.job.id.hashCode % 80 - 40) * 0.0001;
        final generalLatLng = LatLng(
          widget.job.location!.latitude + offsetLat,
          widget.job.location!.longitude + offsetLng,
        );

        return Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade300, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: generalLatLng,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.google.gemini.cli',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: generalLatLng,
                      radius: 800, // 800 meter general zone
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    // Customer app view, or Provider when active/ongoing (EN_ROUTE, IN_PROGRESS)
    return Container(
      height: 220,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: widget.job.location!,
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
                  point: widget.job.location!,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isProvider = _userProfile?.role == 'provider';

    return Scaffold(
      appBar: AppBar(title: Text(widget.job.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.job.status.name.toUpperCase(), 
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  widget.job.maxBudget != null ? '\$${widget.job.maxBudget!.toStringAsFixed(2)}' : 'No Offer',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.job.description, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildMapSection(isProvider),
            const SizedBox(height: 8),
            if (_isActionLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
            else ...[
              // Providers Options
              if (isProvider) ...[
                if (widget.job.status == JobStatus.published || widget.job.status == JobStatus.bidding) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _acceptJobDirect,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Accept Direct'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubmitBidScreen(
                                jobId: widget.job.id,
                                category: widget.job.category,
                                onBidSubmitted: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Counter offer submitted successfully!')),
                                  );
                                  Navigator.pop(context, true);
                                },
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Counter Offer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.job.status == JobStatus.accepted)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(JobStatus.enRoute),
                      icon: const Icon(Icons.directions_run),
                      label: const Text('Go En Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (widget.job.status == JobStatus.enRoute)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(JobStatus.inProgress),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (widget.job.status == JobStatus.inProgress)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.engineering, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Work in Progress - Do your best!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],

              // Customers Options
              if (!isProvider) ...[
                if (widget.job.status == JobStatus.published || widget.job.status == JobStatus.bidding)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => ViewBidsScreen(jobId: widget.job.id, onBidAccepted: () => Navigator.pop(context)))),
                      icon: const Icon(Icons.local_offer),
                      label: const Text('Review Counter Offers'),
                    ),
                  ),
                if (widget.job.status == JobStatus.accepted && (_escrowStatus == null || _escrowStatus!['status'] != 'HELD'))
                  _isFunding 
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _fundEscrow,
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Fund Escrow'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        ),
                      ),
                if (_escrowStatus != null && _escrowStatus!['status'] == 'HELD') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Payment Secured in Escrow', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.job.status == JobStatus.completed && _escrowStatus != null && _escrowStatus!['status'] == 'HELD')
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _releasePayment,
                      icon: const Icon(Icons.payment),
                      label: const Text('Release Payment'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                if (widget.job.status == JobStatus.accepted || widget.job.status == JobStatus.enRoute || widget.job.status == JobStatus.inProgress) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => RatingDialog(
                          jobId: widget.job.id,
                          onRated: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Job marked as completed and provider rated!')),
                            );
                            Navigator.pop(context, true);
                          },
                        ),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              
              const SizedBox(height: 16),
              _isChatLoading 
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToChat,
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat with Participant'),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
