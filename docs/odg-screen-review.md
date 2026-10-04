# ODG customer screen review and implementation

Reviewed the supplied ODG references against the Flutter customer app and marketplace API. The existing blue-and-white visual language, service icons, progress indicators, Back/Next/GRIND navigation, and success/failure summaries are retained. The layouts scroll naturally rather than clipping long content beneath action buttons.

## Screen coverage

| Reference flow | Finding | Implemented behavior |
| --- | --- | --- |
| Homepage | Primary service shortcuts existed; Job Requests opened another creation form. | Job Requests opens existing request history. The personal-services menu presents the nine reference services. |
| Home Repair | Menu, address, description, offer and review existed. End times and photos were not actually persisted. | Saves structured booking data, provider count, per-provider offer, complete schedule and photos. |
| Vehicle Repair | Existing flow required towing even when the customer would not bring the vehicle to a shop. | Towing is conditional; year/model validation and summaries are corrected. |
| Appliance / Device Repair | Existing service choices and brand/model forms. Device model was not required; obsolete pickup answers could appear in summaries. | Requires a device model, keeps appliance model optional, and applies conditional pickup behavior. |
| Massage | Previously generic job form. | Gender, home/hotel service, client count, illness and recent-procedure questions, conditional private details. |
| Nail Care | Previously a generic manicure/pedicure request. | Home service, client count, health intake, treatment selection and optional additional services. |
| Tailoring | Missing dedicated intake. | Item count, materials, project gender, custom measurements and conditional measurements. |
| Housekeeping | Previously generic job form. | Provider gender, multiple tasks, and required description when Others is selected. |
| Landscaping | Missing personal-service flow. | Provider count, multiple tasks, Other details, and offer multiplied by provider count. |
| Babysitting | Previously generic child-care request. | Child count, one age per child, special-needs intake and conditional medication/details. Supports fractional years for infants. |
| Caregiving / Nursing | Previously generic elderly-care request. | Provider gender, nurse/caregiver role, attendee age, health and recent-condition questions with private details. |
| Pet Care | Previously generic grooming request. | Home service, number/types of pets, Other details, illness intake and care tasks. |
| Tutorial | Previously generic job form. | Provider gender, grade, age, special-needs details, subjects, hours and topics. |
| Review / success / failure | Generic summaries omitted service intake; retries could create duplicate jobs. | Service answers, schedule, photos, totals and payment are retained. Retry reuses a customer-scoped request ID, including when navigating back to review without edits. |
| Saved request details | Attachments were only filenames; raw address/contact were embedded in public descriptions. | Actual JPEG/PNG bytes and private intake persist atomically. The detail screen retrieves authorized data from the API. |

## Design corrections

- Caregiving’s “What type of massage?” placeholder is a copied label; the implemented title is service-neutral. Similar mismatched example content does not carry into other services.
- Babysitting and appliance summaries are visibly clipped in the references. Content and buttons now participate in normal scrolling, including on narrow phones with enlarged text.
- A start and an end are distinct values. “Immediately” no longer forces the summary to say “ASAP” when the customer selected an end time. End must follow start; scheduled starts must be in the future.
- Review shows the customer's complete address so they can verify it. The result masks contact information; server authorization controls what other users can retrieve.
- Barangay and city are entered as text rather than offering four Makati barangays against unrelated city choices. This avoids invalid dropdown combinations; authoritative address lookup is still a separate integration.
- Amounts preserve cents. Home-repair and landscaping totals multiply the offer by provider count; other personal-service offers are totals, not per-client charges.
- Hidden conditional answers are excluded from submission. Health information, measurements, contact details and photos are private fields; public notes explicitly ask customers to avoid personal details.

## Persistence and privacy

Migration `000008_booking_details` adds a nullable JSONB booking column; older jobs remain readable. The new backend must be deployed after applying the migration. No live app database was modified during this work.

Photos are limited to five JPEG/PNG files, 2 MB each, with a server dimension limit. They are stored with the booking, not as local filenames. Request-list queries exclude private photo data; authorized detail reads include it. For larger workloads, object storage and thumbnail delivery should replace inline photo storage.

The job owner and accepted provider can retrieve private details. Unassigned viewers receive public answers and approximate coordinates. Known legacy Address/Contact lines are redacted on public reads, but arbitrary personal information typed into historical free-text notes is not automatically classified or migrated.

A retry of the same draft returns the original persisted request. Editing the draft creates a new submission identity; drafts and retry IDs do not survive closing the app.

## Features still requiring product integrations

- Payment options reflect the existing backend: cash after service or card checkout. The reference's Maya wallet is not implemented.
- Promotions, referral attribution and reward redemption have no backing APIs or configured rules. The homepage no longer advertises a fictitious FIRST10 discount or awards fabricated points. Sharing copies an invitation without promising referral credit.
- Support messaging has no destination or ticket API. It now reports its availability honestly and directs users to the help guide or existing provider chat, instead of falsely reporting that a ticket was sent.
- The reference's Terms & Conditions link needs an approved document and destination. Booking copy explains offer/payment behavior without claiming agreement to an unavailable document.
- Notifications remain the existing welcome/booking-update interface; this work does not add push delivery.

## Verification

- Flutter shared tests cover all nine intake screens at 320×568 with enlarged text, conditional/private answers, child-age validation, submission failure/retry, and HTTP validation errors.
- Customer widget tests cover homepage/menu navigation, dedicated intake entry points, repair forms and narrow-screen layout. Provider widget tests verify compatibility with shared changes.
- Go tests cover photo validation, booking privacy on list/detail routes, customer-scoped retry identity, and a real PostgreSQL/PostGIS round trip through creation, retry, reads and provider acceptance.
- The complete SQL migration chain applies to a fresh disposable PostGIS database. Backend tests use isolated fixtures, not the app database.
- Device photo permissions, live card checkout and deployment are not exercised by these automated checks.
