import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Published policy can disable optional reminders but never enables them
/// against the device owner's choice. Offline defaults preserve existing behavior.
class PrayerAdminPolicy {
  const PrayerAdminPolicy(this.data);
  final Map<String, dynamic> data;

  static Future<PrayerAdminPolicy> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (Firebase.apps.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('content')
            .doc('prayer_policy').get().timeout(const Duration(seconds: 2));
        final data = doc.data();
        if (data != null && data['published'] == true) {
          await prefs.setString('reminder_policy_cache', jsonEncode(data.map((key, value) => MapEntry(key, value is String || value is bool || value is num ? value : null))));
          return PrayerAdminPolicy(data);
        }
      }
    } catch (_) {
      // Local prayer reminders must continue without cloud access.
    }
    try {
      final cached = jsonDecode(prefs.getString('reminder_policy_cache') ?? '{}');
      if (cached is Map<String, dynamic>) return PrayerAdminPolicy(cached);
    } catch (_) {}
    return const PrayerAdminPolicy({});
  }

  bool allows(String key) => data[key].toString() != 'false';

  int minutes(String key, int fallback, int minimum, int maximum) =>
      (int.tryParse(data[key]?.toString() ?? '') ?? fallback)
          .clamp(minimum, maximum).toInt();

  static const clockDefaults = <String, String>{
    'morningAzkarTime': '08:00', 'eveningAzkarTime': '18:00',
    'dailyDuaTime': '20:30', 'qiyamTime': '22:00',
  };
  static bool validClock(String value) => RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value);
  String clock(String key) {
    final value = data[key]?.toString() ?? '';
    return validClock(value) ? value : clockDefaults[key] ?? '08:00';
  }
  int clockMinutes(String key) {
    final fields = clock(key).split(':');
    return int.parse(fields[0]) * 60 + int.parse(fields[1]);
  }

  String text(String key, String fallback) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }
}
