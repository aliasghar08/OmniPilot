import 'package:flutter/material.dart';

/// A non-intrusive floating copyright & ownership watermark rendered across
/// every screen in the application via [MaterialApp.builder].
///
/// Wrapped in [IgnorePointer] so it never intercepts taps, drags, or gestures.
class FloatingCopyrightWatermark extends StatelessWidget {
  const FloatingCopyrightWatermark({super.key});

  static const String ownerName = 'Ali Asghar';
  static const String ownerEmail = 'aliasgharinnocent@yahoo.com';
  static const String watermarkText =
      'OmniPilot © $ownerName · $ownerEmail · All Rights Reserved · DMCA Protected';

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 6),
            child: Opacity(
              opacity: 0.58,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC0A0E17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 11,
                      color: Color(0xFF60A5FA),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        watermarkText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: Color(0xFFE2E8F0),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

