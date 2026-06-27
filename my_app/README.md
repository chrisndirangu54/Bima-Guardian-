# Bima Guardian — Bug Fixes

This package contains 8 fixed Dart files from `chrisndirangu54/Bima-Guardian-`,
plus a unified diff (`all_fixes.patch`) showing every change line-by-line.

## How to apply

**Option A — copy files directly**
Copy each file in `lib/` here into the matching path in your `my_app/` project,
overwriting the original. Paths match exactly:

```
lib/Models/company.dart
lib/Models/cover.dart
lib/Models/policy.dart
lib/Screens/admin_panel.dart
lib/Screens/cover_screen.dart
lib/Services/auth_service.dart
lib/Services/company_config_service.dart
lib/insurance_app.dart
```

**Option B — apply the patch**
From your repo's `my_app/` directory:
```
patch -p2 < all_fixes.patch
```
(or `git apply --directory=my_app all_fixes.patch` from the repo root, adjusting
the path prefix if needed)

Then run `flutter analyze` and `flutter test` — I could not run the Dart SDK in
my sandbox, so these fixes are reviewed manually (incl. brace-balance and
cross-reference checks) but not compiler-verified. Please verify before merging.

---

## What was fixed

### Critical
- **Admin Panel had no real authorization check.** Any signed-in user (even
  anonymous) could reach `/admin` directly — the nav button being hidden was
  the *only* protection. `admin_panel.dart` now re-verifies `isAdmin` against
  Firestore on load and shows "Access Denied" if the check fails or the user
  isn't an admin.
- **Promoting a user to admin didn't survive their next login.**
  `auth_service.dart`'s `initializeUserData` was called on every login and
  always wrote `isAdmin: false`. It now only seeds `role`/`isAdmin` the first
  time a user document is created, never on subsequent logins.

  ⚠️ **These two are connected — and there's a third leg you still need:**
  a `firestore.rules` file. I didn't find one anywhere in the repo (it's
  referenced in `firebase.json` but missing), which means whatever rules are
  live only exist in the Firebase Console, unversioned. The client-side fix
  above stops the in-app route, but if Firestore rules allow open writes,
  a user can still set `isAdmin: true` on their own doc directly through the
  SDK. I'd strongly recommend adding a rule that only allows `isAdmin`/`role`
  writes when the request is made by an existing admin.

### Severe
- **Non-admin PDF submissions silently failed.** `_validatePdfWithChatGPT`
  called OpenAI with a placeholder key that was never set, so it always
  returned `false`, which blocked claim/quote/cover submission for every
  regular user with no error shown. Rewired to use Gemini (already
  configured elsewhere in the app) and changed to fail **open** rather than
  closed, since unlike admins, regular users never get to inspect/approve
  the PDF themselves.
- **Encrypted billing data was permanently undecryptable.** Both
  `_saveUserDetails` and `_schedulePaystackAutoBilling` generated a brand
  new AES key/IV on every call and only saved the ciphertext, discarding the
  key. Added `_encryptPayload`/`_decryptPayload` helpers that persist one
  key/IV pair in secure storage and reuse it. Also switched key/IV generation
  from `fromLength` (not cryptographically random) to `fromSecureRandom`.
- **Two conflicting OCR implementations.** `cover_screen.dart` used a
  working Gemini-based OCR; `insurance_app.dart` had its own separate,
  broken OpenAI-based one (placeholder key). Depending on which screen
  triggered "extract from previous policy," it either worked or silently
  failed. Both now use Gemini consistently.
- **Build-breaking import on Linux/CI.** `Insured_item.dart` (capital I) was
  imported in two files, but the file on disk is `insured_item.dart`. Worked
  on case-insensitive filesystems (macOS/Windows), failed to compile on
  Linux. Fixed in both files.

### Moderate
- **`Cover` model dropped claim data on every reload.** `claimStatus` and
  `claimCount` were never written to/read from `toJson`/`fromJson`/`toMap`/
  `fromMap` — they silently reset whenever a `Cover` round-tripped through
  Firestore. Also, `claimCount` was a stray mutable field with no
  constructor parameter (could never actually be set), and `==`/`hashCode`
  used inconsistent comparison logic for the `additionalLevels` list,
  violating Dart's equals/hashCode contract. All fixed; `==`/`hashCode` now
  use `ListEquality`/`MapEquality` consistently for both list and map fields.
- **`Policy` and `Company` had dead fields.** `isClaim`/`isExtention`
  (`Policy`) and `isClaim`/`isExtention`/`isCancellation` (`Company`) were
  field-initialized to `false` outside the constructor, meaning no code
  could ever set them to `true`. I confirmed zero readers exist for any of
  these anywhere in the codebase (the real, working version of this concept
  is tracked separately via raw Firestore map lookups elsewhere in
  `insurance_app.dart`), so I removed them rather than guessing at intended
  wiring that was never built. Also fixed unsafe `subtype!`/`coverageType!`
  null-assertions in `Policy.toJson()`/`toString()` that could throw, and
  added defensive null-safe casting to both models' `fromJson`.
- **M-Pesa STK push password was structurally wrong.** Safaricom's Daraja
  API requires `Password` to be `base64(Shortcode + Passkey + Timestamp)`;
  the code was sending a literal placeholder string instead. Now computed
  correctly, with the right `yyyyMMddHHmmss` timestamp format. You still
  need to fill in your real shortcode/passkey — see code comments.
- **Paystack auto-billing lost the real policy.** When scheduling
  auto-billing, the code built a *new* `Cover` from scratch with blank
  `id`/`name`/`companyId` and a hardcoded `'User Name'`, instead of using
  the actual cover being paid for. `_initializePayment` and
  `showPaymentDialog` now thread the real `Cover` through via `copyWith`.
  Also fixed a hardcoded `'cover123'` placeholder ID in the same flow.

### Minor
- Removed a duplicate `cloud_firestore` import in `company_config_service.dart`.
- Added missing `mounted` checks before `setState` after `await` in a few
  flagged spots (`_checkUserRole`, `fetchTrendingTopics`, `fetchBlogPosts`)
  to prevent "setState() called after dispose()" crashes.

---

## Not fixed — needs your input

These need real credentials or a design decision I can't make for you:

- **Syncfusion PDF migration isn't in this repo at all.** No
  `syncfusion_flutter_pdf` dependency, no usage in `lib/`, and it doesn't
  appear anywhere in the full git history (97 commits checked). The old
  `pdf_text` package is still what's actually wired up. Worth checking
  whether that work exists in a different local branch/copy that was never
  pushed here.
- **Hardcoded placeholder secrets** — Paystack secret key, M-Pesa API key,
  NewsAPI key, SMTP credentials, DMVIC login, Stripe key, a fictional
  `api.payment-gateway.com` endpoint. These need your real values. Note:
  Paystack's *secret* key and the M-Pesa key should not live in client-side
  Dart source even once filled in — they're extractable from the compiled
  app. Worth routing those through a small backend/Cloud Function instead.
- **`EmailAnalyzer`'s Gmail OAuth `ClientId`** — needs your real Google
  Cloud OAuth credentials.
- **Missing `firestore.rules` file** — see the admin-auth note above.
