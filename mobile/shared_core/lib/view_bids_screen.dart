import 'package:flutter/material.dart';
import 'marketplace_service.dart';
import 'models.dart';

class ViewBidsScreen extends StatefulWidget {
  final String jobId;
  final VoidCallback onBidAccepted;

  const ViewBidsScreen({super.key, required this.jobId, required this.onBidAccepted});

  @override
  State<ViewBidsScreen> createState() => _ViewBidsScreenState();
}

class _ViewBidsScreenState extends State<ViewBidsScreen> {
  final _marketplaceService = MarketplaceService();
  List<Bid> _bids = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBids();
  }

  Future<void> _fetchBids() async {
    setState(() => _isLoading = true);
    final bids = await _marketplaceService.getBids(widget.jobId);
    setState(() {
      _bids = bids;
      _isLoading = false;
    });
  }

  void _acceptBid(String bidId) async {
    final success = await _marketplaceService.acceptBid(widget.jobId, bidId);
    if (success) {
      widget.onBidAccepted();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept bid.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Bids')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bids.isEmpty
              ? const Center(child: Text('No bids yet.'))
              : ListView.builder(
                  itemCount: _bids.length,
                  itemBuilder: (context, index) {
                    final bid = _bids[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('₱${bid.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 16, color: Colors.amber),
                                        Text(' ${bid.providerRating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (bid.providerVerified)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child: Icon(Icons.verified, size: 16, color: Colors.blue),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(bid.estimatedTime, style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(bid.message),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _acceptBid(bid.id),
                                child: const Text('Accept Bid'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
