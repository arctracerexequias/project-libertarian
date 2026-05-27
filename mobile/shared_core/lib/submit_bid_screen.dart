import 'package:flutter/material.dart';
import 'marketplace_service.dart';

class SubmitBidScreen extends StatefulWidget {
  final String jobId;
  final String category;
  final VoidCallback onBidSubmitted;

  const SubmitBidScreen({super.key, required this.jobId, required this.category, required this.onBidSubmitted});

  @override
  State<SubmitBidScreen> createState() => _SubmitBidScreenState();
}

class _SubmitBidScreenState extends State<SubmitBidScreen> {
  final _amountController = TextEditingController();
  final _timeController = TextEditingController();
  final _messageController = TextEditingController();
  final _marketplaceService = MarketplaceService();
  bool _isLoading = false;
  bool _isCounterOffer = true;
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
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
      message: '[COUNTER OFFER] ${_messageController.text}',
    );
    setState(() => _isLoading = false);

    if (bid != null) {
      widget.onBidSubmitted();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Make Counteroffer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
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
                labelText: _isCounterOffer ? 'Your Proposed Price (₱)' : 'Bid Amount (₱)',
                border: const OutlineInputBorder()
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Estimated Time', border: OutlineInputBorder()),
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
                        backgroundColor: _isCounterOffer ? Colors.orange : null,
                      ),
                      child: Text(_isCounterOffer ? 'Send Counteroffer' : 'Submit Bid'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
