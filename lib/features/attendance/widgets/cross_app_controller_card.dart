import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../../services/services.dart';
import 'permission_status_tile.dart';

/// Card for controlling Android Accessibility Service, Floating AI Overlay, and external app inspection.
class CrossAppControllerCard extends StatelessWidget {
  final String activeExternalPackage;
  final bool isA11yEnabled;
  final bool isA11ySettingOn;
  final bool canDrawOverlays;
  final bool isBubbleRunning;
  final VoidCallback onToggleBubble;
  final ValueChanged<bool> onInspectScreen;
  final VoidCallback onRequestOverlay;
  final VoidCallback onOpenAppInfo;
  final VoidCallback onRequestIgnoreBattery;

  const CrossAppControllerCard({
    super.key,
    required this.activeExternalPackage,
    required this.isA11yEnabled,
    this.isA11ySettingOn = false,
    required this.canDrawOverlays,
    required this.isBubbleRunning,
    required this.onToggleBubble,
    required this.onInspectScreen,
    required this.onRequestOverlay,
    required this.onOpenAppInfo,
    required this.onRequestIgnoreBattery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppBrandIcon(size: 44, borderRadius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Universal Cross-App Controller',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        activeExternalPackage.isNotEmpty
                            ? 'Target App: $activeExternalPackage'
                            : 'Writes, verifies & controls any Android app in real time',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // 1. Accessibility Service Tile
            if (!isA11yEnabled && isA11ySettingOn) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Accessibility is enabled in Settings, but Infinix/XOS battery manager suspended the service process. Tap "Re-toggle" to turn it OFF and ON, and set Battery to Unrestricted.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            PermissionStatusTile(
              icon: isA11yEnabled
                  ? Icons.check_circle
                  : (isA11ySettingOn ? Icons.warning_amber_rounded : Icons.error_outline),
              iconColor: isA11yEnabled
                  ? Colors.green
                  : (isA11ySettingOn ? Colors.amber.shade800 : Colors.orange),
              title: isA11yEnabled
                  ? 'Android Accessibility Service'
                  : (isA11ySettingOn ? 'Accessibility Suspended by System' : 'Android Accessibility Service'),
              subtitle: isA11yEnabled
                  ? 'Active • Full read, write, verify & click control enabled'
                  : (isA11ySettingOn
                      ? 'Infinix put service to sleep. Tap Re-toggle to reactivate.'
                      : 'Disabled • Enable in Settings to control external apps'),
              trailing: FilledButton.tonal(
                style: (!isA11yEnabled && isA11ySettingOn)
                    ? FilledButton.styleFrom(backgroundColor: Colors.amber.shade100, foregroundColor: Colors.amber.shade900)
                    : null,
                onPressed: () async {
                  await AccessibilityBridge.openAccessibilitySettings();
                },
                child: Text(isA11yEnabled ? 'Settings' : (isA11ySettingOn ? 'Re-toggle' : 'Enable')),
              ),
            ),
            const Divider(height: 16),

            // 2. Display Over Other Apps Tile (Critical for Infinix / Android 14)
            PermissionStatusTile(
              icon: canDrawOverlays ? Icons.check_circle : Icons.warning_amber_rounded,
              iconColor: canDrawOverlays ? Colors.green : Colors.amber.shade800,
              title: 'Display Over Other Apps (Overlay)',
              subtitle: canDrawOverlays
                  ? 'Granted • Assistant bubble authorized to show on top of any app'
                  : 'Required for floating assistant. Tap to authorize in Android settings',
              trailing: canDrawOverlays
                  ? const Chip(
                      label: Text('Granted', style: TextStyle(fontSize: 12)),
                      backgroundColor: Color(0xFFDCFCE7),
                      side: BorderSide.none,
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                      onPressed: onRequestOverlay,
                      child: const Text('Grant'),
                    ),
            ),
            const Divider(height: 16),

            // 3. Floating Assistant Bubble Tile
            PermissionStatusTile(
              icon: isBubbleRunning ? Icons.bubble_chart : Icons.radio_button_unchecked,
              iconColor: isBubbleRunning ? Colors.blue : Colors.grey,
              title: 'Interactive Floating AI Assistant',
              subtitle: isBubbleRunning
                  ? 'Active on screen • Tap bubble in any app to open AI HUD'
                  : 'Floating command bar to inspect & fill without leaving other apps',
              trailing: Switch(
                value: isBubbleRunning,
                onChanged: (_) => onToggleBubble(),
              ),
            ),
            const SizedBox(height: 14),

            // OEM / Infinix Helper Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_android, size: 16, color: Colors.blueGrey),
                      SizedBox(width: 6),
                      Text(
                        'Device Diagnostics (Infinix / XOS / Android 14)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'If assistant closes when switching apps, allow Unrestricted Battery and Pop-up windows in App Info.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: onRequestIgnoreBattery,
                        icon: const Icon(Icons.battery_charging_full, size: 14),
                        label: const Text('Battery Optimization (Unrestricted)'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: onOpenAppInfo,
                        icon: const Icon(Icons.info_outline, size: 14),
                        label: const Text('App Info (Restricted Settings)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onInspectScreen(false),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Inspect Active Window'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => onInspectScreen(true),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Switch & Inspect External App'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.contacts, size: 16),
                  label: const Text('Open Contacts'),
                  onPressed: () async {
                    await AccessibilityBridge.launchExternalApp('Contacts');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.note_alt_outlined, size: 16),
                  label: const Text('Open Notes'),
                  onPressed: () async {
                    await AccessibilityBridge.launchExternalApp('org.fossify.notes');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

