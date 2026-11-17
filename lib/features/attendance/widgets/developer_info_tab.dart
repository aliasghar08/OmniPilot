import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Dedicated Developer Info tab presenting verified authorship, contact details,
/// and developer profile for Ali Asghar.
class DeveloperInfoTab extends StatelessWidget {
  const DeveloperInfoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author & Lead Developer Profile Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    FloatingCopyrightWatermark.ownerName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD)),
                                  ),
                                  child: Text(
                                    'Author & Lead',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              FloatingCopyrightWatermark.ownerEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  Text(
                    'Architect & Lead AI Systems Engineer for OmniPilot. Designed and built the '
                    'cross-app Android Accessibility engine, Period Attendance compliance framework, '
                    'and Gemini AI multimodal automation architecture.',
                    style: TextStyle(fontSize: 12.5, color: colorScheme.onSurface, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. DMCA Protection & Copyright Notice Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.shield_outlined, color: isDark ? Colors.red.shade300 : Colors.red.shade800, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DMCA Protected & Copyright',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Intellectual Property & Anti-Republishing Notice',
                              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DMCA Protected',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      FloatingCopyrightWatermark.watermarkText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: Color(0xFF38BDF8),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All intellectual property, proprietary accessibility traversal algorithms, Period Form '
                    'heuristics, and UI assets are the exclusive property of Ali Asghar. '
                    'Unauthorized reproduction, redistribution, reverse engineering, or removal of '
                    'authorship metadata is strictly prohibited under international copyright conventions and the DMCA.',
                    style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Application & Compatibility Specs
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.info_outline, color: isDark ? Colors.blue.shade300 : Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '${AppConstants.appName} v1.0.0 (Build 2026)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Universal Android OEM & Accessibility Engine',
                              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSpecRow(context, 'Target Platforms', 'Android 8.0 - 15 (API 26 - 35)'),
                  _buildSpecRow(context, 'OEM Compatibility', 'Transsion XOS 14, Samsung One UI, MIUI, ColorOS, FuntouchOS, Pixel'),
                  _buildSpecRow(context, 'Accessibility Controller', 'Full Read, Write, Read-back Verify, Gestures, Default App Resolution'),
                  _buildSpecRow(context, 'AI Engine', 'Gemini 2.0 Flash / Vertex AI + Web Knowledge Engine'),
                  _buildSpecRow(context, 'License', 'Copyright (c) 2026 Ali Asghar. All rights reserved.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSpecRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
