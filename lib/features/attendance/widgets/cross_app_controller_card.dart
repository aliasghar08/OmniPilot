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

            // 3. Sliding AI Edge Assistant Tile
            PermissionStatusTile(
              icon: isBubbleRunning ? Icons.view_sidebar_rounded : Icons.radio_button_unchecked,
              iconColor: isBubbleRunning ? Colors.blue : Colors.grey,
              title: 'Sliding AI Edge Assistant',
              subtitle: isBubbleRunning
                  ? 'Active on edge • Slide edge handle to open AI menu (no overlay icon)'
                  : 'Sliding edge menu to inspect & control without leaving other apps',
              trailing: Switch(
                value: isBubbleRunning,
                onChanged: (_) => onToggleBubble(),
              ),
            ),

            // 4. Voice Replies (TTS) Tile
            AnimatedBuilder(
              animation: AppSettingsService.instance,
              builder: (context, _) {
                final ttsEnabled = AppSettingsService.instance.ttsVoiceEnabled;
                return Column(
                  children: [
                    const Divider(height: 16),
                    PermissionStatusTile(
                      icon: ttsEnabled ? Icons.record_voice_over : Icons.voice_over_off,
                      iconColor: ttsEnabled ? Colors.purple : Colors.grey,
                      title: 'Voice Replies (Text-to-Speech)',
                      subtitle: ttsEnabled
                          ? 'Active • OmniPilot reads status & replies out loud'
                          : 'Muted • Spoken voice feedback is disabled',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ttsEnabled)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                await AccessibilityBridge.speakTts('OmniPilot voice replies are active.');
                              },
                              icon: const Icon(Icons.volume_up, size: 16),
                              label: const Text('Test Voice', style: TextStyle(fontSize: 12)),
                            ),
                          Switch(
                            value: ttsEnabled,
                            onChanged: (val) async {
                              await AppSettingsService.instance.setTtsVoiceEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            // 5. Managed App Permissions Tile
            const Divider(height: 16),
            PermissionStatusTile(
              icon: Icons.security_rounded,
              iconColor: Colors.teal,
              title: 'Managed App Permissions',
              subtitle: 'Control which third-party apps OmniPilot is authorized to access',
              trailing: FilledButton.tonal(
                onPressed: () => _showPermissionsBottomSheet(context),
                child: const Text('Manage'),
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
                      Expanded(
                        child: Text(
                          'Device Diagnostics (Samsung / Xiaomi / Oppo / Vivo / Infinix / Android 14)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ensure Unrestricted Battery and Auto-Start are enabled so OEM task killers do not suspend background AI automation.',
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
                        label: const Text('Battery (Unrestricted Dialog)'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          await AccessibilityBridge.openAutoStartSettings();
                        },
                        icon: const Icon(Icons.rocket_launch, size: 14),
                        label: const Text('Auto-Start / Background Manager'),
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

            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: AppSettingsService.instance,
              builder: (context, _) {
                final shortcuts = AppSettingsService.instance.shortcuts;
                return Wrap(
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
                    ...shortcuts.map((s) {
                      return ActionChip(
                        avatar: const Icon(Icons.launch, size: 14),
                        label: Text('Open ${s.name}'),
                        onPressed: () async {
                          await AccessibilityBridge.launchExternalApp(s.packageOrQuery);
                        },
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<List<Map<String, String>>>(
              future: AccessibilityBridge.getAuthorizedApps(),
              builder: (context, snapshot) {
                final apps = snapshot.data ?? [];
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Colors.teal),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Managed App Permissions',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(bottomSheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Apps you have authorized OmniPilot to access & automate. You can revoke access anytime.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 20),
                        if (isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (apps.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No third-party apps authorized yet.',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'OmniPilot requests permission via popup when you first target an app.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: apps.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final app = apps[index];
                                final label = app['label'] ?? '';
                                final pkg = app['packageName'] ?? '';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade50,
                                    child: Text(
                                      label.isNotEmpty ? label[0].toUpperCase() : 'A',
                                      style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(pkg, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  trailing: TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () async {
                                      await AccessibilityBridge.revokeAppPermission(pkg);
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Revoke', style: TextStyle(fontSize: 12)),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(bottomSheetContext);
                              final installed = await AccessibilityBridge.getInstalledApps();
                              if (context.mounted && installed.isNotEmpty) {
                                _showAddAppPermissionPicker(context, installed);
                              }
                            },
                            icon: const Icon(Icons.add_moderator_rounded, size: 18),
                            label: const Text('+ Authorize Installed App'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddAppPermissionPicker(BuildContext context, List<Map<String, String>> installed) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select App to Authorize', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: installed.length,
              itemBuilder: (context, index) {
                final item = installed[index];
                final label = item['appName'] ?? item['label'] ?? '';
                final pkg = item['packageName'] ?? '';
                return ListTile(
                  title: Text(label, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(pkg, style: const TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await AccessibilityBridge.requestAppPermissionPopup(
                      pkg,
                      reason: 'Manual authorization by user from dashboard',
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

