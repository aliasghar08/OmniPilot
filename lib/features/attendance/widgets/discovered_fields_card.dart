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
                const Icon(Icons.fact_check_outlined, size: 20, color: Colors.indigo),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'No external fields inspected yet. Open another app and tap the Floating Bubble, or tap "Switch & Inspect External App" above.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
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
                      backgroundColor:
                          f.isPopulated ? Colors.green.shade100 : Colors.grey.shade200,
                      child: Text(
                        '#${f.index}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: f.isPopulated
                              ? Colors.green.shade900
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                    title: Text(
                      f.displayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      f.isPopulated
                          ? '✅ Existing Write: "${f.currentValue}"'
                          : '⬜ Empty • ID: ${f.shortId}',
                      style: TextStyle(
                        color: f.isPopulated
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                        fontWeight:
                            f.isPopulated ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            if (lastClickableElements.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Detected Buttons & Controls (${lastClickableElements.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              Text(
                'Screen Text Snapshot (${lastScreenTexts.length} items)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                lastScreenTexts.take(15).join(' • '),
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
