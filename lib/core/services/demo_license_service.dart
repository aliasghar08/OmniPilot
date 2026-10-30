import 'package:cloud_firestore/cloud_firestore.dart';

class DemoLicenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DocumentReference _docRef =
      FirebaseFirestore.instance.collection('licensing').doc('demo_status');

  /// Automatically creates the doc if missing, then checks if a run is available.
  Future<bool> checkAndInitializeLicense() async {
    try {
      final snapshot = await _docRef.get();

      // 1. If document does not exist yet, auto-create it in Firestore
      if (!snapshot.exists) {
        await _docRef.set({
          'is_active': true,
          'runs_remaining': 1,
          'authorized_user': 'Teacher Evaluation',
          'created_at': FieldValue.serverTimestamp(),
        });
        return true;
      }

      // 2. Read existing status
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final bool isActive = data['is_active'] ?? false;
      final int runsRemaining = data['runs_remaining'] ?? 0;

      return isActive && runsRemaining > 0;
    } catch (e) {
      return false;
    }
  }

  /// Atomically consumes the run
  Future<bool> consumeRun() async {
    return await _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(_docRef);
      if (!snapshot.exists) return false;

      final bool isActive = snapshot.get('is_active') ?? false;
      final int runs = snapshot.get('runs_remaining') ?? 0;

      if (!isActive || runs <= 0) return false;

      transaction.update(_docRef, {
        'runs_remaining': runs - 1,
        'used_at': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}

