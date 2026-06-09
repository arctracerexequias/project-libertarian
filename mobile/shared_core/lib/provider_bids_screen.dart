import 'package:flutter/material.dart';
import 'marketplace_service.dart';
import 'models.dart';

class ProviderBidsScreen extends StatefulWidget {
  const ProviderBidsScreen({super.key});

  @override
  State<ProviderBidsScreen> createState() => _ProviderBidsScreenState();
}

class _ProviderBidsScreenState extends State<ProviderBidsScreen> {
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
    final bids = await _marketplaceService.getProviderBids();
    setState(() {
      _bids = bids;
      _isLoading = false;
    });
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
                decoration: const InputDecoration(labelText: 'Reason/Message (Optional)', hintText: 'e.g. Can do for ₱800'),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter offer sent!')));
        _fetchBids();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send counter offer.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bids')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bids.isEmpty
              ? const Center(child: Text('No active bids.'))
              : RefreshIndicator(
                  onRefresh: _fetchBids,
                  child: ListView.builder(
                    itemCount: _bids.length,
                    itemBuilder: (context, index) {
                      final bid = _bids[index];
                      final bool isCounter = bid.status == 'COUNTERED';
                      final bool isRejected = bid.status == 'REJECTED';
                      final bool isAccepted = bid.status == 'ACCEPTED';

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
                                          style: TextStyle(
                                            fontSize: 20, 
                                            fontWeight: FontWeight.bold, 
                                            color: isAccepted ? Colors.green : (isRejected ? Colors.red : Colors.blue)
                                          )),
                                      if (isCounter && bid.counterAmount > 0)
                                        Text('Countered: ₱${bid.counterAmount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 14, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(bid.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      bid.status.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(bid.status), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (isRejected && bid.declineReason.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('Reason: ${bid.declineReason}', style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
                                ),
                              const SizedBox(height: 8),
                              Text('Job ID: ${bid.jobId.substring(0, 8)}...', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 16),
                              if (!isRejected && !isAccepted)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _counterBid(bid),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                        child: const Text('Update / Counter'),
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
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'COUNTERED': return Colors.orange;
      default: return Colors.blue;
    }
  }
}
