import 'package:flutter/material.dart';
import 'marketplace_service.dart';

class RatingDialog extends StatefulWidget {
  final String jobId;
  final VoidCallback onRated;

  const RatingDialog({super.key, required this.jobId, required this.onRated});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _score = 5;
  final _commentController = TextEditingController();
  final _marketplaceService = MarketplaceService();
  bool _isLoading = false;

  void _submit() async {
    setState(() => _isLoading = true);
    final success = await _marketplaceService.completeJob(widget.jobId, _score, _commentController.text);
    setState(() => _isLoading = false);

    if (success) {
      widget.onRated();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete & Rate Job'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was the service?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _score ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _score = index + 1),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Optional Comment',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
