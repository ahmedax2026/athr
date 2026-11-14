import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _adhanAlarmChannel = MethodChannel('athr/adhan_alarms');
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

  static Future<void> setCheckinsEnabled(bool enabled) async {
    await _adhanAlarmChannel.invokeMethod<void>(
      'setCheckinsEnabled', <String, bool>{'enabled': enabled});
  }

  static Future<void> testCheckin() async {
    await _ensureInitialized();
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('يجب السماح بالإشعارات أولًا');
    }
    await _adhanAlarmChannel.invokeMethod<void>('testCheckin');
  }

  static Future<void> cancelPrayerNotifications() async {
    await _ensureInitialized();
    final old = await _plugin.pendingNotificationRequests();
    for (final item in old) {
      if (item.id >= 1000 && item.id < 3000) {
        await _plugin.cancel(id: item.id);
      }
    }
    await _adhanAlarmChannel.invokeMethod<void>('schedule', <Map<String, Object>>[]);
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
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool('athr_notifications_opt_in') ?? true)) {
      await cancelPrayerNotifications();
      return 0;
    }
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      await cancelPrayerNotifications();
      throw StateError('إشعارات التطبيق مقفولة. افتح إعدادات الإشعارات واسمح بها.');
    }
    // Don't erase unrelated notifications from other parts of the app.
    final old = await _plugin.pendingNotificationRequests();
    for (final item in old) {
      if (item.id >= 1000 && item.id < 3000) {
        await _plugin.cancel(id: item.id);
      }
    }

    final checkinsEnabled = preferences.getBool('prayer_checkin_enabled') ?? true;
    await setCheckinsEnabled(checkinsEnabled);
    final useAdhan = preferences.getBool('adhan') ?? false;
    final normalVoice = preferences.getString('adhan_voice') ?? 'adhan_makkah';
    const choices = {'adhan_makkah', 'adhan_afasy'};
    NotificationDetails detailsFor(String name) {
      // Full recordings are played by a native foreground playback service;
      // keep this notification silent to avoid duplicate competing audio.
      if (!useAdhan) return _details;
      return const NotificationDetails(android: AndroidNotificationDetails(
        'athr_adhan_service_v3', 'أذان الصلاة الكامل',
        channelDescription: 'إشعار وقت الصلاة مع تشغيل الأذان كاملًا في الخلفية',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
      ));
    }
    final precise = await _android?.canScheduleExactNotifications() ?? false;
    final mode = precise
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final now = DateTime.now();
    var count = 0;
    final fullAdhanAlarms = <Map<String, Object>>[];
    for (var day = 0; day < days.length; day++) {
      for (var prayer = 0; prayer < prayerNames.length; prayer++) {
        final name = prayerNames[prayer];
        final prayerTime = days[day][name];
        if (prayerTime == null) continue;
        if (prayerTime.isAfter(now)) {
          if (useAdhan) {
            final chosen = name == 'الفجر'
                ? (preferences.getString('adhan_fajr_voice') ?? normalVoice)
                : normalVoice;
            fullAdhanAlarms.add({
              'at': prayerTime.millisecondsSinceEpoch,
              'voice': choices.contains(chosen) ? chosen : 'adhan_makkah',
            });
          }
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
        // This is a separate notification 30 minutes AFTER this prayer,
        // not a reminder about the next upcoming prayer.
        final checkinTime = prayerTime.add(const Duration(minutes: 30));
        if (checkinsEnabled && checkinTime.isAfter(now)) {
          fullAdhanAlarms.add({
            'at': checkinTime.millisecondsSinceEpoch,
            'voice': 'checkin',
            'prayer': name,
          });
        }
        if (reminderMinutes > 0) {
          final before = prayerTime.subtract(Duration(minutes: reminderMinutes));
          if (before.isAfter(now)) {
            fullAdhanAlarms.add({
              'at': before.millisecondsSinceEpoch,
              'voice': 'reminder',
              'prayer': name,
            });
            await _plugin.zonedSchedule(
              id: 1001 + day * 20 + prayer * 2,
              title: 'اقتربت صلاة $name',
              body: 'اقتربت صلاة $name • متبقي $reminderMinutes دقيقة',
              scheduledDate: tz.TZDateTime.from(before, zone),
              notificationDetails: _details,
              androidScheduleMode: mode,
            );
            count++;
          }
        }
      }
    }
    await _adhanAlarmChannel.invokeMethod<void>('schedule', fullAdhanAlarms);
    return count;
  }
}
