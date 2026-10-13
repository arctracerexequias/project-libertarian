import 'package:flutter/material.dart';

const bookingTermsDraft = <(String, String)>[
  (
    "Using ODG",
    "ODG helps customers post service requests and connect with service providers. Posting a request does not guarantee that a provider will accept it or that work will begin immediately. Review the provider and agree on the work before the service starts."
  ),
  (
    "Your request and authority",
    "Provide accurate contact, location, scheduling and job information. Only request work you are authorized to arrange. For children or people receiving care, ensure that you have authority to arrange their care and share the information needed for the service."
  ),
  (
    "Offers and additional costs",
    "Your offer is a proposed price. Providers may propose a different amount; you decide whether to accept. Confirm the scope, total price, number of workers and schedule before work begins. Repair offers cover labor; materials, parts and requested transport should be agreed separately unless expressly included. Personal-service offers include labor, travel and essentials as described in the request. Agree to any additional work or charges before they are incurred."
  ),
  (
    "Payment",
    "Choose an available payment method in the app. Selecting a method when posting does not itself collect payment. Review the amount and instructions when payment is requested. Cash is paid after service as agreed with the provider. Online payment is subject to the checkout instructions presented at that time."
  ),
  (
    "Safe and appropriate services",
    "Provide safe access to the work location and disclose relevant hazards. Harassment, sexual requests, violence and unlawful work are prohibited. ODG bookings are not an emergency response service. For medical care or regulated work, confirm the provider has the qualifications required for the requested task. Arrange appropriate supervision and care instructions for children and vulnerable people."
  ),
  (
    "Personal information",
    "Put contact details and relevant care information in the designated private fields, rather than in public titles or notes. Share only information needed to arrange and perform the service. Do not upload another person’s personal information or photos unless you have authority and a lawful basis to do so. A separate privacy notice must explain ODG’s handling of personal information before these terms are finalized."
  ),
  (
    "Changes, cancellation and concerns",
    "Discuss changes with the provider before the service begins. Keep the booking reference and records of agreed scope and prices. Cancellation, refund and complaint procedures are still being finalized and must be published before these terms take effect. This draft does not introduce cancellation fees or promise a refund outcome."
  ),
  (
    "Your rights and updates",
    "Nothing in these terms is intended to remove rights that cannot be excluded under applicable law. Final terms must identify ODG’s operating entity, contact details, effective date and how changes will be communicated. This draft is for review and does not establish a new acceptance requirement."
  ),
];

class BookingTermsScreen extends StatelessWidget {
  const BookingTermsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Terms & Conditions')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('DRAFT — not yet effective',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('These proposed booking terms are being reviewed. '
              'Posting a request does not record acceptance of this draft.'),
          for (final section in bookingTermsDraft) ...[
            const SizedBox(height: 24),
            Text(section.$1, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(section.$2),
          ],
        ]),
      );
}
