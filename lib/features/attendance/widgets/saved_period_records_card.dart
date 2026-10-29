import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'period_record_list_tile.dart';

/// Card displaying local and Cloud Firestore saved period attendance records.
class SavedPeriodRecordsCard extends StatelessWidget {
  final List<Map<String, dynamic>> localSavedRecords;

  const SavedPeriodRecordsCard({
    super.key,
    required this.localSavedRecords,
  });

  @override
  Widget build(BuildContext context) {
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.cloud_sync, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Saved Period Attendance Records',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (localSavedRecords.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: localSavedRecords.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return PeriodRecordListTile(data: localSavedRecords[index]);
                },
              ),
              const Divider(height: 16),
            ],
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance_logs')
                  .orderBy('created_at', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    localSavedRecords.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  if (localSavedRecords.isNotEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Tap "Save Period Attendance Record" above or ask Gemini to log a period record.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty && localSavedRecords.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'No period attendance logs recorded yet.\nUse the AI Presets or Save button above!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return PeriodRecordListTile(data: data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

