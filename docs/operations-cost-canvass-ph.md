# Project Libertarian: Philippine operating-cost canvass

**Prepared:** 4 September 2026  
**Currency:** Philippine pesos (PHP)  
**Planning exchange rate:** PHP 60 = USD 1

This is a planning canvass, not a legal, tax, or vendor quotation. Local-government
fees depend on the registered city, office type, floor area, capitalization, and
declared line of business. Obtain written quotes before spending.

## Executive budget

| Launch level | One-time cash before launch | Monthly cash burn | Six-month cash need |
|---|---:|---:|---:|
| Closed Android pilot, cash/manual settlement, founder-operated | PHP 100,000-250,000 | PHP 20,000-50,000 | **PHP 220,000-550,000** |
| Public paid beta, Android + iOS, one city | PHP 400,000-1,000,000 | PHP 90,000-220,000 | **PHP 940,000-2,320,000** |
| Staffed city launch with meaningful acquisition spend | PHP 1,000,000-2,000,000 | PHP 350,000-700,000 | **PHP 3,100,000-6,200,000** |

The recommended target is the **public paid beta**, but release it in stages. A
prudent initial capitalization/runway target is about **PHP 1.2-2.0 million** if
the founders continue doing most engineering and management. This is cash
available to the company, not all registration expense.

## Assumptions behind the base case

- Philippine-owned domestic stock corporation, using a One Person Corporation
  (OPC) if there is one founder or a regular corporation if there are co-founders.
- One Metro Manila launch city; home office if permitted, otherwise a low-cost
  registered/virtual office.
- Founder-led management and engineering, plus one support/operations employee.
- Two apps: customer and service provider, on Android and iOS.
- Approximately 1,000 early users and 100-1,000 monthly completed jobs.
- The platform uses a BSP-regulated Philippine payment partner and does not
  custody customer funds itself.
- Provider relationships are documented as independent marketplace merchants,
  subject to a Philippine lawyer's review of the actual control and work model.

## 1. Formation and compliance

### Recommended structure

A corporation is more appropriate than a sole proprietorship for a marketplace
that holds personal data, mediates disputes, and may face service-related claims.
An OPC works for one founder; use a regular domestic stock corporation when
there are multiple founders or near-term investors.

A sole proprietor can register a national-scope business name for PHP 2,000 plus
PHP 30 documentary stamp tax, but the owner has unlimited personal liability.
That small saving is not attractive for this risk profile.

### Initial cash allowance

| Item | Planning allowance | Basis / note |
|---|---:|---|
| SEC incorporation and corporate books | PHP 3,000-6,000 | SEC filing is 0.2% of authorized capital/subscription basis, minimum PHP 2,000, plus legal research fee; SEC estimates the stock-and-transfer book at PHP 470. Payment/convenience charges can apply. |
| Notarization, corporate records, filing help | PHP 3,000-15,000 | Market allowance; DIY filing is cheaper. |
| Barangay clearance, Mayor's/business permit, BFP and local charges | PHP 5,000-25,000 | City-specific allowance. Confirm with the chosen BPLO before signing a lease. |
| BIR registration, books, and invoices | PHP 1,000-3,000 | Government loose DST is PHP 30; the balance allows for books and compliant invoices. |
| E-Commerce Philippine Trustmark | PHP 130 | Current micro-enterprise total: PHP 0 application + PHP 100 web administration + PHP 30 DST. |
| NPC data-processing/DPO registration | PHP 2,500 | National private organization initial registration. If legitimately exempt, a notarized Sworn Declaration and Undertaking is still required. |
| Registered-office deposit/setup | PHP 0-18,000 | Zero if a lawful home office is accepted; otherwise allow for a virtual/serviced address. |
| Marketplace legal pack | PHP 20,000-60,000 | Terms, privacy notice/consents, provider agreement, cancellation/refund rules, acceptable-use policy, complaints/redress process, and contractor-classification review. |
| Trademark, one class | PHP 3,570 DIY; PHP 10,000-25,000 assisted | Small-entity official core fees: PHP 1,200 filing + PHP 900 first publication + PHP 570 certificate + PHP 900 second publication. Search, responses, extra classes, and professional fees are additional. |
| Contingency | PHP 7,000-25,000 | Roughly 15%-20%, especially for LGU-specific charges. |
| **Formation/compliance subtotal** | **PHP 45,000-180,000** | Excludes subscribed/paid-in capital, which remains company money. |

### Required registrations and recurring filings

1. SEC incorporation (OPC or regular domestic stock corporation).
2. Barangay clearance and city/municipal business permit, including local fire
   and zoning/occupancy requirements that apply to the registered office.
3. BIR Certificate of Registration, registered books, and compliant invoices.
4. SSS, PhilHealth, and Pag-IBIG employer registration before employing staff.
5. DTI E-Commerce Philippine Trustmark. Current rules cover online merchants,
   e-marketplaces, and digital platforms.
6. NPC appointment/registration of a Data Protection Officer and data-processing
   systems when covered. This product continuously handles identity, precise
   location, chats, transaction records, and possibly KYC documents, so budget
   on registration rather than assuming the smallest-business exemption.
7. Annual/periodic SEC, BIR, LGU, NPC, and labor filings, maintained by the
   accountant/corporate secretary.

Allow **PHP 45,000-120,000 per year** for bookkeeping, tax filings, corporate
secretarial work, and year-end financial statements/audit assistance at small
transaction volume. Audit and tax complexity can push this higher.

## 2. Software work still needed before a public paid launch

The repository is a useful MVP, but not yet production-ready:

- `README.md` labels payments as escrow stubs.
- The payment service is wired to Stripe, which does not list the Philippines as
  a supported business location as of this canvass.
- Development JWT/admin secrets and database credentials are present in local
  configuration; production secret management is not configured.
- The mobile configuration still points to a LAN address and placeholder
  production host.
- Android application IDs and release signing contain TODOs.
- A production complaints/refund workflow, merchant verification, moderation,
  observability, backup restoration, and incident procedures are not evident.

### Productionization allowance

| Workstream | Outsourced/hybrid allowance |
|---|---:|
| Replace Stripe; integrate local checkout, webhooks, refunds, payouts, reconciliation, and idempotency | PHP 60,000-160,000 |
| Production infrastructure, CI/CD, secrets, TLS, database backups/restore test, monitoring, rate limits | PHP 50,000-140,000 |
| Security/privacy hardening, authorization review, deletion/retention workflows, vulnerability test | PHP 50,000-150,000 |
| Android/iOS release signing, organization accounts, store listings, privacy disclosures, device QA | PHP 40,000-110,000 |
| Complaint, moderation, merchant-verification and admin-operating workflows | PHP 30,000-90,000 |
| Performance/reliability fixes and launch QA | PHP 30,000-100,000 |
| **Productionization subtotal** | **PHP 260,000-750,000** |

If the founders implement these items, much of this becomes 8-12 weeks of labor
instead of cash. Keep at least **PHP 50,000-150,000** for independent legal,
security, device, and launch review; self-review is not an adequate substitute
for every risk.

No automated test suite was run during this canvass because the local environment
does not have the Go toolchain installed. The estimate is based on repository
inspection and is not a certification of launch readiness.

## 3. Launch accounts and infrastructure

### One-time / annual

| Item | Cost |
|---|---:|
| Google Play organization developer account | About PHP 1,500 one-time (USD 25) |
| Apple Developer Program | About PHP 5,940/year (USD 99) |
| Domain | PHP 700-1,500/year |
| Basic brand/store assets and launch collateral | PHP 5,000-25,000 |
| Initial provider onboarding/background checks | PHP 10,000-40,000 |
| Initial local launch campaign | PHP 30,000-120,000 |

### Monthly base case

| Expense | Founder-only pilot | Public paid beta |
|---|---:|---:|
| Compute, managed PostgreSQL, object storage, backups, monitoring | PHP 3,000-8,000 | PHP 5,000-15,000 |
| Email, domain allocation, support and admin software | PHP 1,000-4,000 | PHP 2,000-8,000 |
| Maps/tiles, SMS/OTP, email delivery, KYC checks | PHP 500-3,000 | PHP 2,000-12,000 |
| Accountant, tax filings, corporate secretary allocation | PHP 4,000-10,000 | PHP 6,000-15,000 |
| Registered address | PHP 0-6,000 | PHP 0-8,000 |
| Insurance/legal/compliance reserve | PHP 2,000-8,000 | PHP 4,000-15,000 |
| Customer support / marketplace operations | Founder | PHP 25,000-45,000 |
| Engineering maintenance/on-call | Founder | PHP 20,000-60,000 |
| Provider and customer acquisition | PHP 5,000-20,000 | PHP 20,000-75,000 |
| Refund/fraud/incident reserve and contingency | PHP 4,500-10,000 | PHP 10,000-25,000 |
| **Approximate monthly total** | **PHP 20,000-50,000** | **PHP 90,000-220,000** |

DigitalOcean's published entry points support the infrastructure allowance:
managed databases start at USD 15/month, object storage at USD 5/month, and
Droplets at USD 4/month. The actual stack should not use the smallest Droplet;
the seven services can initially share one adequately sized host, but the
database and backups should be isolated. Avoid Kubernetes during the pilot.

For employees, do not budget salary alone. As of this canvass, the NCR
non-agriculture minimum is PHP 755/day. Employer SSS is 10% of monthly salary
credit (plus Employees' Compensation), with PhilHealth, Pag-IBIG, 13th-month pay,
leave, equipment, and payroll administration on top. A PHP 25,000 support salary
normally needs roughly **PHP 30,000-34,000/month of loaded employer budget**.

## 4. Payment, escrow, and app-store economics

### Recommended payment design

Do not market or implement self-custodied "escrow" until Philippine payments
counsel and the gateway approve the flow. BSP guidance says platforms that
enable/process payments and merchant acquisition can fall within regulated OPS
activities. Use a BSP-regulated partner's marketplace/wallet/split-payout product
and describe the mechanism using the partner-approved terminology.

PayMongo's standard published prices, exclusive of VAT, currently include:

| Rail | Published fee |
|---|---:|
| Online QR Ph | 1.34% |
| Maya | 1.79% |
| GCash | 2.23% |
| Local cards | 3.125% + PHP 13.39 |
| Payout | PHP 10 per transaction |
| Wallet KYC | PHP 30 one time per account |
| Wallet maintenance | PHP 15/account/month for 1-25,000 clients |

The wallet/marketplace product can therefore be materially more expensive than
plain checkout. Obtain a written platform proposal before finalizing the take
rate. Keep wallet balances off your own ledger unless counsel and the licensed
partner confirm the structure.

### App-store issue with boosts

Payments for cleaning, repairs, transport, and other physical services can use
an external payment provider. Paid coverage/roaming boosts unlock visibility or
functionality inside the app, so they are digital purchases. Apple explicitly
uses social-post boosts as an in-app-purchase example, and Google requires Play
billing for in-app digital features. Budget a **15% store fee** at small-business
tiers where eligible, or remove paid boosts from the launch model. Do not assume
that selling them through a website avoids every store rule.

### Example unit economics

Assume 100 completed jobs/month, PHP 1,500 average job value, and a 12% platform
commission:

| Measure | Amount |
|---|---:|
| Monthly GMV | PHP 150,000 |
| Platform commission revenue | PHP 18,000 |
| GCash processing at 2.23%, before VAT | PHP 3,345 |
| 100 payouts at PHP 10, before VAT | PHP 1,000 |
| Contribution before refunds, tax, support, and fixed costs | **PHP 13,655** |

At the same assumptions, each completed job contributes about PHP 136.55 before
VAT on gateway charges, tax, refunds, and fraud. Covering PHP 90,000 of monthly
fixed cost requires about **660 completed jobs/month** (roughly PHP 990,000 GMV).
At PHP 150,000 fixed cost it requires about **1,100 jobs/month**. A 15% take rate,
minimum service fee, customer-paid convenience fee where lawful, and batched
payouts can improve this, but each affects conversion or provider earnings.

## 5. Recommended staged launch

### Stage 1: legal and operational design (weeks 1-3)

- Choose OPC versus regular corporation, city, office address, initial category,
  take rate, and whether providers are businesses or individuals.
- Get written advice on marketplace liability, worker classification, tax invoice
  flow, payment custody, terms, privacy, and complaints.
- Incorporate, reserve the brand, and start gateway underwriting early.

### Stage 2: closed Android pilot (weeks 3-8)

- One city and one or two low-risk service categories.
- Cash or gateway-hosted checkout; no self-held escrow and no paid boosts.
- Manually verify 20-50 providers and cap customer invitations.
- Prove successful matching, completion, complaint resolution, repeat use, and
  contribution per job before adding scale cost.

### Stage 3: public paid beta (weeks 8-16)

- Complete production hardening and independent review.
- Launch organization-owned Android and iOS accounts.
- Use partner-approved payment/payout flows and reconciliation.
- Staff support during advertised service hours and publish the required
  business, complaint, privacy, pricing, cancellation, and merchant information.

## 6. Decisions that most change this estimate

Before requesting firm quotes, decide:

1. Registered city and whether the office is residential, virtual, or leased.
2. Single founder (OPC) or multiple founders/investors (regular corporation).
3. Cash-only pilot versus gateway payments and provider payouts.
4. Whether the platform charges commission, lead fees, subscriptions, or boosts.
5. Launch city, service categories, operating hours, and provider headcount.
6. Founder-performed engineering versus contractors or employees.
7. Android first versus simultaneous Android and iOS.

## Primary pricing and regulatory sources

- [SEC registration calculator](https://appointment.sec.gov.ph/online-services/registration-calculator/)
- [DTI business-name fees](https://bnrs.dti.gov.ph/faq)
- [BIR online-seller registration guide](https://bir-cdn.bir.gov.ph/BIR/pdf/TAXPAYERS%20GUIDE%20FOR%20ONLINE%20SELLERS.pdf)
- [DTI Trustmark FAQ and fees](https://trustmark.dti.gov.ph/faqs)
- [DTI Internet Transactions Act](https://ecommerce.dti.gov.ph/internet-transactions-act-of-2023/)
- [NPC registration fees](https://privacy.gov.ph/npc-implements-registration-fees-and-charges-and-submission-of-sworn-declaration-and-undertaking-for-exemption-from-data-processing-system-registration/)
- [BSP operator-of-payment-system overview](https://www.bsp.gov.ph/SitePages/PaymentsAndSettlements/PaymentsAndSettlements.aspx)
- [PayMongo pricing](https://www.paymongo.com/pricing)
- [Stripe global availability](https://stripe.com/global)
- [IPOPHL trademark fees](https://www.ipophil.gov.ph/services/schedule-of-fees/trademark-related-fees/)
- [Google Play account fee](https://support.google.com/googleplay/android-developer/answer/6112435)
- [Google Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- [Apple Developer membership and commissions](https://developer.apple.com/programs/whats-included/)
- [Apple App Review payment rules](https://developer.apple.com/app-store/review/guidelines/)
- [DigitalOcean pricing](https://www.digitalocean.com/pricing)
- [NCR minimum wage](https://nwpc.dole.gov.ph/ncr/)
- [SSS contribution rate](https://www.sss.gov.ph/pay-contribution/)

