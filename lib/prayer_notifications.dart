import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Prayer notification diagnostics. Sound of the full adhan is deliberately
/// independent from the mandatory prayer-time notifications.
class PrayerNotificationStatus {
  const PrayerNotificationStatus({
    required this.enabled,
    required this.exact,
    required this.pending,
  });
  final bool enabled, exact;
  final int pending;
}

class PrayerNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'athr_prayers_v2', 'مواقيت الصلاة',
      channelDescription: 'إشعارات مواقيت الصلاة والتنبيه قبلها',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _initialized = true;
  }

  static Future<PrayerNotificationStatus> status() async {
    await _ensureInitialized();
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final pending = await _plugin.pendingNotificationRequests();
    return PrayerNotificationStatus(
      enabled: enabled, exact: exact,
      pending: pending.where((entry) => entry.id >= 1000 && entry.id < 3000).length,
    );
  }

  static Future<bool> requestNotificationPermission() async {
    await _ensureInitialized();
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? await _android?.areNotificationsEnabled() ?? false;
  }

  static Future<bool> requestExactPermission() async {
    await _ensureInitialized();
    if (await _android?.canScheduleExactNotifications() ?? false) return true;
    await _android?.requestExactAlarmsPermission();
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  static Future<void> openNotificationSettings() async {
    await _ensureInitialized();
    await _android?.openAppNotificationSettings();
  }

  static Future<void> showTest() async {
    await _ensureInitialized();
    final allowed = await _android?.areNotificationsEnabled() ?? false;
    if (!allowed) {
      throw StateError('الإشعارات غير مسموح بها للتطبيق من إعدادات الهاتف');
    }
    await _plugin.show(
      id: 900,
      title: 'اختبار إشعارات أثر لا ينقطع',
      body: 'لو ظهر التنبيه ده، استقبال إشعارات الصلاة مُفعّل.',
      notificationDetails: _details,
    );
  }

  /// A real device-level alarm test: succeeds even if the app is closed.
  /// Requires Android exact-alarm access to give a meaningful 2-minute check.
  static Future<DateTime> scheduleTest({
    required tz.Location zone,
  }) async {
    await _ensureInitialized();
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('اسمح بإشعارات التطبيق أولًا');
    }
    if (!(await _android?.canScheduleExactNotifications() ?? false)) {
      throw StateError('فعّل التوقيت الدقيق أولًا لاختبار التنبيه المجدول');
    }
    final fireAt = DateTime.now().add(const Duration(minutes: 2));
    await _plugin.cancel(id: 901);
    await _plugin.zonedSchedule(
      id: 901,
      title: 'تجربة تنبيه الصلاة',
      body: 'التنبيه المجدول وصل والتطبيق في الخلفية أو مقفول.',
      scheduledDate: tz.TZDateTime.from(fireAt, zone),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    return fireAt;
  }

  static Future<int> schedule({
    required List<Map<String, DateTime>> days,
    required tz.Location zone,
    required int reminderMinutes,
  }) async {
    await _ensureInitialized();
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('إشعارات التطبيق مقفولة. افتح إعدادات الإشعارات واسمح بها.');
    }
    // Don't erase unrelated notifications from other parts of the app.
    final old = await _plugin.pendingNotificationRequests();
    for (final item in old) {
      if (item.id >= 1000 && item.id < 3000) {
        await _plugin.cancel(id: item.id);
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final useAdhan = preferences.getBool('adhan') ?? false;
    final normalVoice = preferences.getString('adhan_voice') ?? 'adhan_voice_1';
    final fajrVoice = preferences.getString('adhan_fajr_voice') ?? 'adhan_fajr';
    const choices = {'adhan_makkah', 'adhan_afasy', 'adhan_fajr'};
    NotificationDetails detailsFor(String name) {
      if (!useAdhan) return _details;
      final requested = name == 'الفجر' ? fajrVoice : normalVoice;
      final voice = choices.contains(requested) ? requested : 'adhan_makkah';
      return NotificationDetails(android: AndroidNotificationDetails(
        'athr_adhan_${voice}_v2', 'أذان ${voice == 'adhan_fajr' ? 'الفجر' : 'الصلاة'}',
        channelDescription: 'صوت أذان اختياري عند دخول وقت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(voice),
      ));
    }
    final precise = await _android?.canScheduleExactNotifications() ?? false;
    final mode = precise
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final now = DateTime.now();
    var count = 0;
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
            notificationDetails: detailsFor(name),
            androidScheduleMode: mode,
          );
          count++;
        }
        if (reminderMinutes > 0) {
          final before = prayerTime.subtract(Duration(minutes: reminderMinutes));
          if (before.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: 1001 + day * 20 + prayer * 2,
              title: 'اقترب موعد صلاة $name',
              body: 'باقي $reminderMinutes دقيقة على صلاة $name',
              scheduledDate: tz.TZDateTime.from(before, zone),
              notificationDetails: _details,
              androidScheduleMode: mode,
            );
            count++;
          }
        }
      }
    }
    return count;
  }
}
