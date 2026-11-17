import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';

/// Displays inspected editable fields, clickable buttons, and visible text from the active external Android app.
class DiscoveredFieldsCard extends StatelessWidget {
  final List<Map<String, dynamic>> lastInspectedFields;
  final List<Map<String, dynamic>> lastClickableElements;
  final List<String> lastScreenTexts;

  const DiscoveredFieldsCard({
    super.key,
    required this.lastInspectedFields,
    required this.lastClickableElements,
    required this.lastScreenTexts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final models = List.generate(
      lastInspectedFields.length,
      (i) => ExternalFieldModel.fromMap(i, lastInspectedFields[i]),
    );
    final populatedCount = models.where((f) => f.isPopulated).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined, size: 20, color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editable Fields (${models.length}) • Populated ($populatedCount)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'No external fields inspected yet. Open another app and tap the Floating Bubble, or tap "Switch & Inspect External App" above.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: models.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final f = models[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: f.isPopulated
                          ? (isDark ? const Color(0xFF064E3B) : Colors.green.shade100)
                          : (isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade200),
                      child: Text(
                        '#${f.index}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: f.isPopulated
                              ? (isDark ? const Color(0xFF6EE7B7) : Colors.green.shade900)
                              : (isDark ? colorScheme.onSurface : Colors.grey.shade800),
                        ),
                      ),
                    ),
                    title: Text(
                      f.displayLabel,
                      style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      f.isPopulated
                          ? '✅ Existing Write: "${f.currentValue}"'
                          : '⬜ Empty • ID: ${f.shortId}',
                      style: TextStyle(
                        color: f.isPopulated
                            ? (isDark ? const Color(0xFF86EFAC) : Colors.green.shade800)
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            f.isPopulated ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            if (lastClickableElements.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Detected Buttons & Controls',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: lastClickableElements.take(12).map((btn) {
                  final lbl = btn['label']?.toString() ?? 'Button';
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.touch_app, size: 14),
                    label: Text(lbl, style: const TextStyle(fontSize: 11)),
                    onPressed: () async {
                      await AccessibilityBridge.ensureExternalAppFocused();
                      await AccessibilityBridge.clickElement(lbl);
                    },
                  );
                }).toList(),
              ),
            ],
            if (lastScreenTexts.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Screen Text Snapshot',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                lastScreenTexts.take(15).join(' • '),
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

