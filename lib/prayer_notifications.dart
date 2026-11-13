import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local reminders for five daily prayers and optional advance warnings.
/// The audio adhan is a separate, optional feature and is not started here.
class PrayerNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _initialized = true;
    final platform = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  static Future<void> schedule({
    required List<Map<String, DateTime>> days,
    required tz.Location zone,
    required int reminderMinutes,
  }) async {
    await _ensureInitialized();
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'athr_prayers', 'مواقيت الصلاة',
        channelDescription: 'تنبيهات دخول وقت الصلاة وتذكيراتها',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final now = DateTime.now();
    for (var day = 0; day < days.length; day++) {
      for (var prayer = 0; prayer < prayerNames.length; prayer++) {
        final name = prayerNames[prayer];
        final prayerTime = days[day][name];
        if (prayerTime == null) continue;
        if (prayerTime.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: 1000 + day * 20 + prayer * 2,
            title: 'حان الآن موعد صلاة $name',
            body: 'حي على الصلاة • أثر لا ينقطع',
            scheduledDate: tz.TZDateTime.from(prayerTime, zone),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
        if (reminderMinutes > 0) {
          final before = prayerTime.subtract(Duration(minutes: reminderMinutes));
          if (before.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: 1001 + day * 20 + prayer * 2,
              title: 'اقترب موعد صلاة $name',
              body: 'باقي $reminderMinutes دقيقة على صلاة $name',
              scheduledDate: tz.TZDateTime.from(before, zone),
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        }
      }
    }
  }
}
