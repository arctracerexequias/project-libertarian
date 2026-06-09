import 'package:flutter/material.dart';
import 'marketplace_service.dart';

class SubmitBidScreen extends StatefulWidget {
  final String jobId;
  final String category;
  final double currentPrice; // Job budget or current bid
  final bool isCounter;
  final VoidCallback onBidSubmitted;

  const SubmitBidScreen({
    super.key, 
    required this.jobId, 
    required this.category, 
    required this.currentPrice,
    this.isCounter = false,
    required this.onBidSubmitted
  });

  @override
  State<SubmitBidScreen> createState() => _SubmitBidScreenState();
}

class _SubmitBidScreenState extends State<SubmitBidScreen> {
  final _amountController = TextEditingController();
  final _timeController = TextEditingController();
  final _messageController = TextEditingController();
  final _marketplaceService = MarketplaceService();
  bool _isLoading = false;
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.currentPrice.toStringAsFixed(0);
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final insights = await _marketplaceService.getInsights(widget.category);
    if (mounted) {
      setState(() => _insights = insights);
    }
  }

  void _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    setState(() => _isLoading = true);
    final bid = await _marketplaceService.submitBid(
      jobId: widget.jobId,
      amount: amount,
      estimatedTime: _timeController.text,
      message: widget.isCounter ? '[COUNTER OFFER] ${_messageController.text}' : _messageController.text,
    );
    setState(() => _isLoading = false);

    if (bid != null) {
      widget.onBidSubmitted();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isCounter ? 'Make Counter-offer' : 'Place Bid')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isCounter)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Counter-offer:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const Text('You are proposing a different price. Explain why in your message if needed.', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Current Price: ₱${widget.currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (_insights != null && _insights!['count'] > 0)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Market Insights:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Average: ₱${_insights!['average'].toStringAsFixed(2)}'),
                    Text('Completed Jobs: ${_insights!['count']}'),
                  ],
                ),
              ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Your Proposed Price (₱)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText: widget.isCounter ? 'Propose a price different from ₱${widget.currentPrice.toStringAsFixed(0)}' : null,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Estimated Time (e.g. 2 hours)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Message / Note', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isCounter ? Colors.orange : null,
                      ),
                      child: Text(widget.isCounter ? 'Send Counter-offer' : 'Submit Bid'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
