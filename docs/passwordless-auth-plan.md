# ODG passwordless authentication implementation plan

Status: design prepared; passwordless authentication is not implemented or enabled.
Requested channels: WhatsApp and Viber verification codes, plus passkeys. SMS fallback is not assumed.

## Current integration points

Both mobile apps share `mobile/shared_core/lib/login_screen.dart` and `auth_service.dart`.
The Go identity service currently registers email/password accounts and issues 24-hour JWTs.
The gateway explicitly permits login/register without a JWT. New public authentication routes
must be individually allowlisted; enrollment and credential management remain authenticated.
Current biometrics unlock a saved session; they are not server-verified passkeys.
Accounts have no verified phone identity. Booking contact numbers must never become login
identities automatically. Existing email accounts must not be merged based on a claimed email.

## User flows

1. Existing users authenticate with their current account, then verify and link a phone number.
   Require recent authentication for linking, replacing a number or adding/removing passkeys.
2. New users verify their phone and complete name/role onboarding. The schema must support
   accounts without a password or email; never generate a fabricated email address.
3. Users select WhatsApp or Viber, request a code, and verify it. Expose only configured channels.
4. After authentication, offer passkey enrollment using a fresh server challenge.
5. Subsequent visits support discoverable passkey sign-in or messaging verification.
6. Credential management supports multiple passkeys, named devices and revocation. Recovery
   and phone replacement need explicit rules; prevent removing the last usable sign-in method.

## Backend requirements

- Separate unique verified phone identities (E.164) from service contact information.
- Persist purpose-bound, expiring verification challenges and single-use consumption.
- Bind linking challenges to the authenticated account; bind signup data to verified challenges.
- Choose a documented provider API for each channel. Do not treat WhatsApp and Viber as SMS.
- Enforce shared persistent send/verify limits by phone, challenge and trusted client IP, with
  resend cooldown, capped attempts and spending limits. Do not trust forwarded IPs indiscriminately.
- Return generic login failures and avoid revealing whether a phone is registered. Never log codes.
- If the provider manages verification, validate its authoritative result and atomically consume
  the local challenge before granting a session. Otherwise use cryptographically random codes
  and keyed hashes at rest; prevent concurrent verification/replay and cross-purpose reuse.
- Use a maintained WebAuthn library. Persist credential IDs/public keys/user handles and
  short-lived challenges. Validate RP ID, allowed origins, challenge, signature and required
  user verification. Handle synced credentials and signature counters according to the library.
- Preserve existing password login during rollout and reuse the established JWT session contract.
- Phone verification does not grant provider business/qualification verification.

## Mobile and deployment requirements

- Shared phone/channel entry, code entry, resend timer, passkey sign-in/enrollment and credential
  management screens. Handle cancelled passkey prompts and unsupported devices normally.
- Configure a stable HTTPS relying-party domain before enrolling real passkeys.
- Android Digital Asset Links must associate both app package IDs and their signing certificates.
- iOS requires associated-domain configuration and the corresponding website association file.
- Keep provider secrets server-side. Disabled configuration must fail closed without fake success.
- Delivery tests use mocks until approved business senders and test recipients are configured.

## Verification before enabling

Test challenge expiry, attempt limits, replay, concurrent consumption, resend behavior, provider
failures, account-link conflicts, role preservation and migration compatibility. Test WebAuthn
with real cryptographic fixtures, rejecting wrong origins/RP IDs/challenges and missing user
verification. Exercise customer and provider apps on physical devices, including passkey
creation, sign-in, revocation and recovery. Confirm approved message delivery on each channel.

## Missing setup information

- Messaging provider(s), business sender/template provisioning and server-side credentials.
- Stable HTTPS sign-in domain and platform signing/association configuration.
- Account recovery and phone replacement policy before production rollout.

## References

- https://www.twilio.com/docs/verify/authentication-channels
- https://www.twilio.com/docs/verify/whatsapp/byo
- https://www.forbusiness.viber.com/en/blog/post/product-updates-q2-2026/
- https://developer.android.com/identity/credential-manager/prerequisites
