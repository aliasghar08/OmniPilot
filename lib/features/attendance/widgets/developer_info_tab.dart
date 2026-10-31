import 'package:flutter/material.dart';
import '../../../core/core.dart';

/// Dedicated Developer Info tab presenting verified authorship, contact details,
/// DMCA protection notices, Quantum Forge cryptographic integrity token, and app license.
class DeveloperInfoTab extends StatelessWidget {
  const DeveloperInfoTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isIntact = OwnershipGuard.verifyIntegrity();
    final runtimeToken = OwnershipGuard.computeRuntimeToken();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author & Lead Developer Profile Card
          Card(
            elevation: 2,
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
                          color: const Color(0xFF1E3A8A),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x331E3A8A),
                              blurRadius: 8,
                              offset: Offset(0, 3),
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
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF93C5FD)),
                                  ),
                                  child: const Text(
                                    'Author & Lead',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              FloatingCopyrightWatermark.ownerEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 26),
                  const Text(
                    'Architect & Lead AI Systems Engineer for OmniPilot. Designed and built the '
                    'cross-app Android Accessibility engine, Period Attendance compliance framework, '
                    'and Gemini AI multimodal automation architecture.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.45),
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
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.shield_outlined, color: Colors.red.shade800, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DMCA Protected & Copyright',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Intellectual Property & Anti-Republishing Notice',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DMCA Protected',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
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
                  const Text(
                    'All intellectual property, proprietary accessibility traversal algorithms, Period Form '
                    'heuristics, and UI assets are the exclusive property of Ali Asghar. '
                    'Unauthorized reproduction, redistribution, reverse engineering, or removal of '
                    'authorship metadata is strictly prohibited under international copyright conventions and the DMCA.',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Quantum Forge Cryptographic Integrity Verification Card
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
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.verified_user, color: Colors.green.shade800, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantum Forge Integrity',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Cryptographic Authorship Guard',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          isIntact ? Icons.check_circle : Icons.error,
                          size: 14,
                          color: isIntact ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                        label: Text(
                          isIntact ? 'VERIFIED' : 'TAMPERED',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isIntact ? Colors.green.shade900 : Colors.red.shade900,
                          ),
                        ),
                        backgroundColor: isIntact ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Runtime Authorship Token:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      runtimeToken,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Application & Compatibility Specs
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.appName} v1.0.0 (Build 2026)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Universal Android OEM & Accessibility Engine',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSpecRow('Target Platforms', 'Android 8.0 - 15 (API 26 - 35)'),
                  _buildSpecRow('OEM Compatibility', 'Transsion XOS 14, Samsung One UI, MIUI, ColorOS, FuntouchOS, Pixel'),
                  _buildSpecRow('Accessibility Controller', 'Full Read, Write, Read-back Verify, Gestures, Default App Resolution'),
                  _buildSpecRow('AI Engine', 'Gemini 2.0 Flash / Vertex AI + Web Knowledge Engine'),
                  _buildSpecRow('License', 'Copyright (c) 2026 Ali Asghar. All rights reserved.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
