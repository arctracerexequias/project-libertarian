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
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to accept bid.')));
    }
  }

  void _rejectBid(String bidId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Bid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you declining this bid?'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Too expensive'),
              onTap: () => Navigator.pop(context, 'Too expensive'),
            ),
            ListTile(
              title: const Text('Estimated time too long'),
              onTap: () => Navigator.pop(context, 'Estimated time too long'),
            ),
            ListTile(
              title: const Text('Poor rating/reviews'),
              onTap: () => Navigator.pop(context, 'Poor rating/reviews'),
            ),
            ListTile(
              title: const Text('Other'),
              onTap: () async {
                final otherReason = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      title: const Text('Other Reason'),
                      content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter reason')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('OK')),
                      ],
                    );
                  },
                );
                if (mounted) Navigator.pop(context, otherReason);
              },
            ),
          ],
        ),
      ),
    );

    if (reason != null) {
      final success = await _marketplaceService.rejectBid(widget.jobId, bidId, reason: reason);
      if (success) {
        _fetchBids();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to decline bid.')));
      }
    }
  }

  void _counterBid(Bid bid) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final amountController = TextEditingController(text: bid.amount.toString());
        final reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('Make Counter Offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Counter Amount (₱)', prefixText: '₱'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason/Message (Optional)', hintText: 'e.g. Budget is ₱1000 max'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null) {
                  Navigator.pop(context, {'amount': amount, 'reason': reasonController.text});
                }
              },
              child: const Text('Send Counter'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final success = await _marketplaceService.counterOffer(bid.id, result['amount'], reason: result['reason']);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter offer sent!')));
        _fetchBids();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send counter offer.')));
      }
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
                    final bool isCounter = bid.status == 'COUNTERED';

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isCounter)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.compare_arrows, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      bid.counterBy != '' ? 'COUNTER-OFFER RECEIVED' : 'COUNTER-OFFER SENT',
                                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('₱${bid.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                    if (isCounter && bid.counterAmount > 0)
                                      Text('Countered: ₱${bid.counterAmount.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 14, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
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
                            Row(
                              children: [
                                if (bid.status != 'ACCEPTED')
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectBid(bid.id),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                if (bid.status != 'ACCEPTED') const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _counterBid(bid),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                    child: Text(bid.status == 'ACCEPTED' ? 'Renegotiate' : 'Counter'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (bid.status != 'ACCEPTED')
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _acceptBid(bid.id),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                              ],
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
