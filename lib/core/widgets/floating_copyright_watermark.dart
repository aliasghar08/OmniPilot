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
    final screenWidth = MediaQuery.sizeOf(context).width;

    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 6),
            child: Opacity(
              opacity: 0.68,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenWidth > 40 ? screenWidth - 20 : 360,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE60A0E17),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 11,
                          color: Color(0xFF60A5FA),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'OmniPilot © $ownerName',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: Color(0xFFF1F5F9),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0x333B82F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DMCA Protected',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF93C5FD),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '$ownerEmail · All Rights Reserved',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                        decoration: TextDecoration.none,
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

