# Security Policy & Anti-Republishing Architecture

**Owner & Lead Security Architect:** Ali Asghar ([aliasgharinnocent@yahoo.com](mailto:aliasgharinnocent@yahoo.com))  
**Repository:** [https://github.com/aliasghar08/OmniPilot](https://github.com/aliasghar08/OmniPilot)

---

## Supported Versions

We actively maintain and release security updates for the following versions of **OmniPilot**:

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| `1.0.x` | :white_check_mark: | Active Production Release |
| `< 1.0` | :x:                | Legacy Prototype (Unsupported) |

---

## Multi-Layer Security & Anti-Republishing Architecture

OmniPilot implements the **Quantum Forge Security Standard** to protect user privacy, Android system integrity, Firebase backend resources, and intellectual property ownership:

### 1. Cryptographic Authorship & Watermark Guard (`OwnershipGuard`)
- Defined in [`lib/core/security/ownership_guard.dart`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/lib/core/security/ownership_guard.dart).
- Verifies at startup (`main()`) that the canonical author identity (`Ali Asghar | aliasgharinnocent@yahoo.com | OmniPilot`), base64 authorship token, and `FloatingCopyrightWatermark` text are unmodified.
- If an unauthorized clone strips or alters the watermark or author constants, `OwnershipGuard.enforceOwnershipOrThrow()` halts execution immediately.

### 2. Gradle Release-Signing & Store Publishing Lock
- Defined in [`android/app/build.gradle.kts`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/android/app/build.gradle.kts).
- Inspects the Gradle task graph prior to execution. Any attempt to run `assembleRelease`, `bundleRelease`, or store publishing tasks without the owner's private `android/key.properties` signing keystore is immediately blocked with a `SECURITY & DMCA OWNERSHIP LOCK` exception.
- Standard `debug` builds remain open for authorized developer inspection and testing.

### 3. Firebase App Check & Play Integrity Attestation
- Defined in [`lib/main.dart`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/lib/main.dart).
- Uses `FirebaseAppCheck` with `AndroidPlayIntegrityProvider` / `AppleDeviceCheckProvider` in release builds (and debug providers in local development) so unauthorized or repackaged APKs cannot abuse Cloud Firestore or Firebase AI Logic quotas.

### 4. Android Accessibility & Overlay Sandboxing
- Native Kotlin services ([`AttendanceAccessibilityService.kt`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/android/app/src/main/kotlin/com/attendancecopilot/attendance_copilot/AttendanceAccessibilityService.kt) and [`FloatingBubbleService.kt`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/android/app/src/main/kotlin/com/attendancecopilot/attendance_copilot/FloatingBubbleService.kt)) require explicit user-granted system permissions (`BIND_ACCESSIBILITY_SERVICE` and `SYSTEM_ALERT_WINDOW`).
- Password fields (`isPassword == true`) are never logged or transmitted to external services.
- All secret keys, keystores (`*.jks`, `*.keystore`), and `key.properties` are strictly excluded via [`.gitignore`](file:///Users/aliasghar08/development/Attendance%20Copilot%20Repo/.gitignore).

---

## Reporting a Vulnerability

We take the security of **OmniPilot** seriously. If you discover a security vulnerability, please report it responsibly:

1. **Do NOT open a public GitHub issue** for sensitive security vulnerabilities.
2. Email your findings directly to **[aliasgharinnocent@yahoo.com](mailto:aliasgharinnocent@yahoo.com)** or use GitHub's [Private Vulnerability Reporting](https://github.com/aliasghar08/OmniPilot/security/advisories/new).
3. Include:
   - Affected component (`lib/core/security/`, `AttendanceAccessibilityService.kt`, `FloatingBubbleService.kt`, `WebKnowledgeService`, etc.).
   - Clear reproduction steps or proof-of-concept.
   - Potential impact and suggested remediation.

### Response Timeline
- **Initial Acknowledgment:** Within 48 hours
- **Triage & Severity Assessment:** Within 5 business days
- **Patch & Disclosure:** Coordinated after fix verification
