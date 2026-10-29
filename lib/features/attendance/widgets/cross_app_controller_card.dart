import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../../services/services.dart';
import 'permission_status_tile.dart';

/// Card for controlling Android Accessibility Service, Floating AI Overlay, and external app inspection.
class CrossAppControllerCard extends StatelessWidget {
  final String activeExternalPackage;
  final bool isA11yEnabled;
  final bool isBubbleRunning;
  final VoidCallback onToggleBubble;
  final ValueChanged<bool> onInspectScreen;

  const CrossAppControllerCard({
    super.key,
    required this.activeExternalPackage,
    required this.isA11yEnabled,
    required this.isBubbleRunning,
    required this.onToggleBubble,
    required this.onInspectScreen,
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
            PermissionStatusTile(
              icon: isA11yEnabled ? Icons.check_circle : Icons.error_outline,
              iconColor: isA11yEnabled ? Colors.green : Colors.orange,
              title: 'Android Accessibility Service',
              subtitle: isA11yEnabled
                  ? 'Active • Full read, write, verify & click control enabled'
                  : 'Disabled • Enable in Settings to control external apps',
              trailing: FilledButton.tonal(
                onPressed: () async {
                  await AccessibilityBridge.openAccessibilitySettings();
                },
                child: Text(isA11yEnabled ? 'Settings' : 'Enable'),
              ),
            ),
            const Divider(height: 16),
            PermissionStatusTile(
              icon: isBubbleRunning ? Icons.bubble_chart : Icons.radio_button_unchecked,
              iconColor: isBubbleRunning ? Colors.blue : Colors.grey,
              title: 'Interactive Floating AI Overlay',
              subtitle: isBubbleRunning
                  ? 'Active on screen • Tap bubble in any app to open AI HUD'
                  : 'Floating command bar to inspect & fill without leaving other apps',
              trailing: Switch(
                value: isBubbleRunning,
                onChanged: (_) => onToggleBubble(),
              ),
            ),
            const SizedBox(height: 12),
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

