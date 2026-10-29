import 'dart:convert';
import '../constants/app_constants.dart';
import '../widgets/floating_copyright_watermark.dart';

/// Cryptographic authorship & anti-republishing guard modeled after Quantum Forge.
///
/// Verifies that the copyright watermark, author attribution, and DMCA protection
/// strings remain intact at runtime. Any unauthorized clone or fork that strips
/// or alters the author metadata fails integrity verification.
class OwnershipGuard {
  const OwnershipGuard._();

  /// Canonical author fingerprint payload (`Ali Asghar|aliasgharinnocent@yahoo.com|OmniPilot`).
  static const String _canonicalIdentity =
      'Ali Asghar|aliasgharinnocent@yahoo.com|OmniPilot';

  /// Expected base64-encoded authorship token.
  static const String expectedAuthorshipToken =
      'QWxpIEFzZ2hhcnxhbGlhc2doYXJpbm5vY2VudEB5YWhvby5jb218T21uaVBpbG90';

  /// Computes the runtime authorship token from active constants and watermark metadata.
  static String computeRuntimeToken() {
    final payload =
        '${FloatingCopyrightWatermark.ownerName}|${FloatingCopyrightWatermark.ownerEmail}|${AppConstants.appName}';
    return base64Encode(utf8.encode(payload));
  }

  /// Returns `true` if all authorship, watermark, and DMCA notices are intact.
  static bool verifyIntegrity() {
    final tokenMatches = computeRuntimeToken() == expectedAuthorshipToken;
    final watermarkContainsOwner = FloatingCopyrightWatermark.watermarkText
        .contains(FloatingCopyrightWatermark.ownerName);
    final watermarkContainsEmail = FloatingCopyrightWatermark.watermarkText
        .contains(FloatingCopyrightWatermark.ownerEmail);
    final watermarkContainsDmca =
        FloatingCopyrightWatermark.watermarkText.contains('DMCA Protected');

    return tokenMatches &&
        watermarkContainsOwner &&
        watermarkContainsEmail &&
        watermarkContainsDmca &&
        _canonicalIdentity.isNotEmpty;
  }

  /// Throws a [StateError] if unauthorized tampering with authorship metadata is detected.
  static void enforceOwnershipOrThrow() {
    if (!verifyIntegrity()) {
      throw StateError(
        'SECURITY VIOLATION: OmniPilot authorship & DMCA watermark integrity check failed. '
        'Unauthorized redistribution or removal of Copyright (c) 2026 Ali Asghar '
        '<aliasgharinnocent@yahoo.com> is strictly prohibited.',
      );
    }
  }
}

