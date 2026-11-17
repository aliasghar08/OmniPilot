import 'package:flutter/material.dart';
import '../../../services/services.dart';

/// Interactive in-app control center allowing the user to customize automation speeds,
/// typing fallback strategies, write verification, and manage third-party target apps.
class InAppCustomizationCard extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const InAppCustomizationCard({
    super.key,
    this.onSettingsChanged,
  });

  @override
  State<InAppCustomizationCard> createState() => _InAppCustomizationCardState();
}

class _InAppCustomizationCardState extends State<InAppCustomizationCard> {
  final AppSettingsService _settings = AppSettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _settings.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
    widget.onSettingsChanged?.call();
  }

  void _showManualAddShortcutDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final queryCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_to_home_screen, color: Colors.blue),
            SizedBox(width: 8),
            Text('Add Target App Shortcut', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add any app installed on your phone to inspect and autofill with one tap.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name (e.g. WhatsApp, School ERP)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryCtrl,
              decoration: const InputDecoration(
                labelText: 'Package Name or App Name',
                hintText: 'e.g. com.whatsapp or WhatsApp',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final query = queryCtrl.text.trim();
              if (name.isNotEmpty && query.isNotEmpty) {
                await _settings.addShortcut(name, query);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add Shortcut'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppSelectionDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        String searchQuery = '';
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.apps_rounded,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Target App',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Choose from downloaded apps to create shortcut',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: FutureBuilder<List<Map<String, String>>>(
                  future: AccessibilityBridge.getInstalledApps(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Loading installed apps...', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    final allApps = snapshot.data ?? [];
                    if (allApps.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.app_blocking_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 10),
                            const Text('No downloaded apps found.', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _showManualAddShortcutDialog(context);
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Enter package name manually'),
                            ),
                          ],
                        ),
                      );
                    }

                    final existingShortcuts = _settings.shortcuts
                        .map((e) => e.packageOrQuery.toLowerCase())
                        .toSet();

                    final filtered = allApps.where((app) {
                      final name = (app['appName'] ?? '').toLowerCase();
                      final pkg = (app['packageName'] ?? '').toLowerCase();
                      final q = searchQuery.toLowerCase().trim();
                      if (q.isEmpty) return true;
                      return name.contains(q) || pkg.contains(q);
                    }).toList();

                    return Column(
                      children: [
                        TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search downloaded apps...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setDialogState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text('No apps match your search.', style: TextStyle(color: Colors.grey)),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final app = filtered[idx];
                                    final name = app['appName'] ?? 'App';
                                    final pkg = app['packageName'] ?? '';
                                    final isAdded = existingShortcuts.contains(pkg.toLowerCase()) ||
                                        existingShortcuts.contains(name.toLowerCase());

                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      leading: CircleAvatar(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFFDBEAFE),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        pkg,
                                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: isAdded
                                          ? const Chip(
                                              label: Text('Added', style: TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              side: BorderSide.none,
                                            )
                                          : FilledButton.tonal(
                                              style: FilledButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                              ),
                                              onPressed: () async {
                                                await _settings.addShortcut(name, pkg);
                                                if (dialogContext.mounted) {
                                                  Navigator.pop(dialogContext);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Added $name to target apps.'),
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Text('Add', style: TextStyle(fontSize: 12)),
                                            ),
                                      onTap: () async {
                                        if (isAdded) return;
                                        await _settings.addShortcut(name, pkg);
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added $name to target apps.'),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showManualAddShortcutDialog(context);
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Enter Manually', style: TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In-App Automation & Customization',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tune speeds, verification, overlay & target app shortcuts',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),

            // 1. Target Apps & Shortcuts Manager
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick-Launch Target Apps',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showAppSelectionDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add App', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._settings.shortcuts.map((item) {
                  return Chip(
                    avatar: const Icon(Icons.open_in_new, size: 14),
                    label: Text(item.name, style: const TextStyle(fontSize: 12)),
                    onDeleted: () async {
                      await _settings.removeShortcut(item.id);
                    },
                    deleteIconColor: Colors.grey.shade600,
                  );
                }),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 20),

            // 2. Typing Speed & Keystroke Delay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Input & Transition Delay',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Controls typing pacing for slow OEM apps (${_settings.inputDelayMs} ms)',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_settings.inputDelayMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            Slider(
              value: _settings.inputDelayMs.toDouble(),
              min: 50,
              max: 600,
              divisions: 11,
              label: '${_settings.inputDelayMs} ms',
              onChanged: (val) async {
                await _settings.setInputDelayMs(val.round());
              },
            ),

            // 3. Write Verification & Auto-Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Switch to External App', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Bring target app to the foreground during automation', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              value: _settings.autoSwitchToExternal,
              onChanged: (val) async {
                await _settings.setAutoSwitchToExternal(val);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Read-Back Write Verification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Verify node text matches after writing to prevent missed fields', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              value: _settings.verifyWrites,
              onChanged: (val) async {
                await _settings.setVerifyWrites(val);
              },
            ),

            const Divider(height: 16),

            // 4. Typing Fallback Strategy Selector
            const Text(
              'Typing Fallback Engine',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'smart_auto',
                      label: Text('Smart Auto', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.auto_fix_high, size: 14),
                    ),
                    ButtonSegment(
                      value: 'action_only',
                      label: Text('Direct Only', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.flash_on, size: 14),
                    ),
                    ButtonSegment(
                      value: 'clipboard',
                      label: Text('Paste Only', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.content_paste, size: 14),
                    ),
                  ],
                  selected: {_settings.typingStrategy},
                  onSelectionChanged: (set) async {
                    if (set.isNotEmpty) {
                      await _settings.setTypingStrategy(set.first);
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await _settings.resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings reset to recommended defaults.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset to Defaults', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
