import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';

/// Displays the fields the API has authorized for this viewer. Never reconstruct
/// private details from a list response or infer access from a local role.
class BookingSummary extends StatelessWidget {
  final Job job;
  const BookingSummary({super.key, required this.job});

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'Not specified';
    return '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final booking = job.booking;
    if (booking == null) return const SizedBox.shrink();
    final private = booking['private'] as Map?;
    final answers = <String, dynamic>{
      ...Map<String, dynamic>.from(booking['answers'] ?? {}),
      ...Map<String, dynamic>.from(private?['answers'] ?? {}),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Service details', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Area: ${booking['area']}'),
      Text(
          'Start: ${job.isEmergency ? 'Immediately' : _date(job.scheduledAt?.toIso8601String())}'),
      Text(
          'End: ${booking['end_asap'] == true ? 'ASAP' : _date(booking['end_at'])}'),
      Text(
          'Providers: ${booking['workers']} • Offer per provider: ₱${(booking['unit_offer'] as num).toStringAsFixed(2)}'),
      if (private == null)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
                'Contact details, private intake and photos are shared with the accepted provider.'))
      else ...[
        Text('Address: ${private['address']}'),
        Text('Contact: ${private['contact']}'),
      ],
      for (final entry in answers.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text('${entry.key}: ${entry.value}'),
        ),
      for (final photo in (private?['photos'] as List? ?? []))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Semantics(
              label: photo['name'],
              image: true,
              child: Image.memory(
                base64Decode(photo['data']),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Text('Photo could not be displayed.'),
              )),
        ),
    ]);
  }
}
