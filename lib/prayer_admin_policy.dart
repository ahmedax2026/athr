import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Published policy can disable optional reminders but never enables them
/// against the device owner's choice. Offline defaults preserve existing behavior.
class PrayerAdminPolicy {
  const PrayerAdminPolicy(this.data);
  final Map<String, dynamic> data;

  static Future<PrayerAdminPolicy> load() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('content')
            .doc('prayer_policy').get().timeout(const Duration(seconds: 2));
        final data = doc.data();
        if (data != null && data['published'] == true) {
          return PrayerAdminPolicy(data);
        }
      }
    } catch (_) {
      // Local prayer reminders must continue without cloud access.
    }
    return const PrayerAdminPolicy({});
  }

  bool allows(String key) => data[key].toString() != 'false';

  int minutes(String key, int fallback, int minimum, int maximum) =>
      (int.tryParse(data[key]?.toString() ?? '') ?? fallback)
          .clamp(minimum, maximum).toInt();

  String text(String key, String fallback) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}
