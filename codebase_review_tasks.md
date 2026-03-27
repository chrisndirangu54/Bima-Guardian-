# Codebase Review: Proposed Engineering Tasks

## 1) Typo Fix Task
**Issue found:** The root README heading is `# Bima-Guardian-`, which appears to include an accidental trailing hyphen.

**Task:** Normalize the project name in `README.md` to the agreed canonical title (e.g., `# Bima Guardian`).

**Why this matters:** Eliminates naming inconsistency across docs, issue templates, and external references.

**Acceptance criteria:**
- `README.md` title no longer has the trailing hyphen typo.
- Project name formatting is consistent with the app branding used elsewhere.

---

## 2) Bug Fix Task
**Issue found:** `my_app/lib/insurance_app.dart` imports `dart:io` directly. This is a runtime/build bug risk for Flutter Web because `dart:io` is not available on web targets.

**Task:** Refactor `dart:io` usage behind platform-aware abstractions (conditional imports or `kIsWeb` + split implementation files).

**Why this matters:** Prevents web build failures and improves platform portability.

**Acceptance criteria:**
- No unconditional `dart:io` imports remain in shared web-targeted code paths.
- `flutter analyze` passes.
- Web target build command succeeds (or CI equivalent check passes).

---

## 3) Code Comment / Documentation Discrepancy Task
**Issue found:** `my_app/lib/insurance_app.dart` contains a stale import comment (`// Remove this import; see below for correct usage.`) that does not match the current code.

**Task:** Remove or rewrite the stale comment so the import section reflects the actual intended architecture.

**Why this matters:** Avoids misleading maintainers and accidental “cleanup” edits based on outdated notes.

**Acceptance criteria:**
- The stale comment is removed or replaced with accurate intent.
- Import block comments are current and actionable.

---

## 4) Test Improvement Task
**Issue found:** `my_app/test/widget_test.dart` still uses the Flutter template “Counter increments smoke test,” but the app under test is not a counter app.

**Task:** Replace the template test with app-specific widget tests (e.g., startup route, login screen presence, and initial provider wiring).

**Why this matters:** Improves regression signal quality and prevents irrelevant failures.

**Acceptance criteria:**
- Counter template assertions (`find.text('0')`, `find.text('1')`, `Icons.add`) are removed.
- New tests validate real app behavior and are deterministic in CI (with Firebase/platform mocks where needed).
