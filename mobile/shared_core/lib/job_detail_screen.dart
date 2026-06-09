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

  late JobStatus _currentStatus;
  bool _statusUpdated = false;
  bool _isBacking = false;
  bool _hasRated = false;
  Bid? _acceptedBid;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.job.status;
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
    Bid? acceptedBid;
    try {
      final bids = await _marketplaceService.getBids(widget.job.id);
      for (final b in bids) {
        if (b.status.toLowerCase() == 'accepted') {
          acceptedBid = b;
          break;
        }
      }
    } catch (e) {
      print('Error fetching bids for provider name: $e');
    }
    if (mounted) {
      setState(() {
        _escrowStatus = status;
        _acceptedBid = acceptedBid;
      });
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
        if (mounted) {
          setState(() {
            _currentStatus = JobStatus.accepted;
            _statusUpdated = true;
          });
          _fetchEscrowStatus();
        }
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
      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
          _statusUpdated = true;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update job status.')),
      );
    }
  }

  void _cancelJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job'),
        content: const Text('Are you sure you want to cancel this job? This will trigger a refund if payment is in escrow.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isActionLoading = true);
      final success = await _marketplaceService.cancelJob(widget.job.id);
      setState(() => _isActionLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job cancelled successfully.')),
        );
        if (mounted) {
          setState(() {
            _currentStatus = JobStatus.cancelled;
            _statusUpdated = true;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel job.')),
        );
      }
    }
  }

  void _showRebookPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rebook Service?'),
        content: const Text('Would you like to schedule this provider for another session of this service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToRebook();
            }, 
            child: const Text('Yes, Rebook')
          ),
        ],
      ),
    );
  }

  void _navigateToRebook() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateJobScreen(
          onJobCreated: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rebooking scheduled successfully!')),
            );
          },
          initialLocation: widget.job.location,
          parentJobId: widget.job.id,
          initialCategory: widget.job.category,
          initialTitle: widget.job.title,
          initialDescription: widget.job.description,
        ),
      ),
    );
  }

  Widget _buildMapSection(bool isProvider) {
    if (widget.job.location == null) {
      return const SizedBox.shrink();
    }

    if (isProvider) {
      if (_currentStatus == JobStatus.published || _currentStatus == JobStatus.bidding) {
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

      if (_currentStatus == JobStatus.accepted) {
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

    return PopScope(
      canPop: _isBacking,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (context.mounted) {
          Navigator.of(context).pop(_statusUpdated);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.job.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isBacking = true;
              });
              Navigator.of(context).pop(_statusUpdated);
            },
          ),
        ),
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
                      _currentStatus.name.toUpperCase(), 
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Text(
                    widget.job.maxBudget != null ? '₱${widget.job.maxBudget!.toStringAsFixed(2)}' : 'No Offer',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.job.description, style: const TextStyle(fontSize: 16, height: 1.4)),
              if (_acceptedBid != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: const Text('Assigned Provider', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    subtitle: Text(
                      _acceptedBid!.providerName.isNotEmpty 
                          ? _acceptedBid!.providerName 
                          : 'Service Provider',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _acceptedBid!.providerRating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                  if (_currentStatus == JobStatus.published || _currentStatus == JobStatus.bidding) ...[
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
                                  currentPrice: widget.job.maxBudget ?? 0,
                                  isCounter: true,
                                  onBidSubmitted: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Counter-offer submitted successfully!')),
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
                  if (_currentStatus == JobStatus.accepted)
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
                  if (_currentStatus == JobStatus.enRoute)
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
                  if (_currentStatus == JobStatus.inProgress) ...[
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(JobStatus.completed),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete Work'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],

                // Customers Options
                if (!isProvider) ...[
                  if (_currentStatus == JobStatus.published || _currentStatus == JobStatus.bidding)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ViewBidsScreen(jobId: widget.job.id, onBidAccepted: () => Navigator.pop(context)))),
                        icon: const Icon(Icons.local_offer),
                        label: const Text('Review Offers & Counters'),
                      ),
                    ),
                  if (_currentStatus == JobStatus.accepted && (_escrowStatus == null || _escrowStatus!['status'] != 'HELD'))
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
                  if (_currentStatus == JobStatus.completed) ...[
                    if (!_hasRated) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final rated = await showDialog<bool>(
                              context: context,
                              builder: (context) => RatingDialog(
                                job: widget.job,
                                onRated: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Provider rated successfully!')),
                                  );
                                },
                              ),
                            );
                            if (rated == true) {
                              setState(() => _hasRated = true);
                              _showRebookPrompt();
                            }
                          },
                          icon: const Icon(Icons.star_rate),
                          label: const Text('Rate & Review Provider'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('You have rated this provider', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  if (_currentStatus == JobStatus.completed && _escrowStatus != null && _escrowStatus!['status'] == 'HELD') ...[
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
                    const SizedBox(height: 16),
                  ],
                  if (_currentStatus == JobStatus.accepted || _currentStatus == JobStatus.enRoute || _currentStatus == JobStatus.inProgress) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final rated = await showDialog<bool>(
                            context: context,
                            builder: (context) => RatingDialog(
                              job: widget.job,
                              onRated: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Job marked as completed and provider rated!')),
                                );
                              },
                            ),
                          );
                          if (rated == true) {
                            if (mounted) {
                              _showRebookPrompt();
                              setState(() {
                                _currentStatus = JobStatus.completed;
                                _statusUpdated = true;
                              });
                            }
                          }
                        },
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
                if (_currentStatus != JobStatus.completed && _currentStatus != JobStatus.cancelled) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _cancelJob,
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Cancel Job', style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
