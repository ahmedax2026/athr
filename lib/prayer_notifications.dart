import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

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

@pragma('vm:entry-point')
Future<void> prayerNotificationActionBackground(NotificationResponse response) async {
  await PrayerNotifications.handleAction(response);
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
      color: Color(0xFF073E35),
      styleInformation: BigTextStyleInformation(''),
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
      onDidReceiveNotificationResponse: handleAction,
      onDidReceiveBackgroundNotificationResponse: prayerNotificationActionBackground,
    );
    _initialized = true;
  }

  static const String _doneAction = 'prayer_done';
  static const String _laterAction = 'prayer_later';

  static Future<void> handleAction(NotificationResponse response) async {
    final action = response.actionId;
    if (action != _doneAction && action != _laterAction) return;
    final parts = (response.payload ?? '').split('|');
    if (parts.length != 3 || parts[0] != 'prayer') return;
    final dateKey = parts[1];
    final prayer = parts[2];
    const allowed = {'الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'};
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}
    await _ensureInitialized();
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final pending = await _plugin.pendingNotificationRequests();
    return PrayerNotificationStatus(
      enabled: enabled, exact: exact,
      pending: pending.where((entry) => entry.id >= 1000 && entry.id < 4000).length,
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


  static Future<void> cancelFollowUp({
    required int dayOffset,
    required int prayerIndex,
  }) async {
    await _ensureInitialized();
    await _plugin.cancel(id: 3000 + dayOffset * 10 + prayerIndex);
  }

  static Future<void> showQiyamPreview() async {
    await _ensureInitialized();
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('اسمح بإشعارات التطبيق أولًا');
    }
    await _plugin.show(
      id: 902,
      title: '🌙 ركعتان تنيران ليلتك',
      body: 'لا تنسَ قيام الليل 🤍 حتى لو ركعتين خفيفتين قبل النوم.',
      notificationDetails: _details,
    );
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
      if (item.id >= 1000 && item.id < 4000) {
        await _plugin.cancel(id: item.id);
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final useAdhan = preferences.getBool('adhan') ?? false;
    final normalVoice = preferences.getString('adhan_voice') ?? 'adhan_makkah';
    const choices = {'adhan_makkah', 'adhan_afasy'};
    NotificationDetails detailsFor() {
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
    final qiyamEnabled = preferences.getBool('qiyam_reminder_enabled') ?? true;
    final followupEnabled = preferences.getBool('prayer_followup_enabled') ?? true;
    final followupDelay = preferences.getInt('prayer_followup_delay') ?? 10;
    final now = DateTime.now();
    var count = 0;
    final fullAdhanAlarms = <Map<String, Object>>[];
    for (var day = 0; day < days.length; day++) {
      final isha = days[day]['العشاء'];
      if (qiyamEnabled && isha != null) {
        final at = tz.TZDateTime(zone, isha.year, isha.month, isha.day, 22);
        final afterIsha = isha.add(const Duration(minutes: 45));
        final qiyamAt = afterIsha.isAfter(at) ? afterIsha : at;
        if (qiyamAt.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: 2000 + day,
            title: '🌙 ركعتان تنيران ليلتك',
            body: 'لا تنسَ قيام الليل 🤍 حتى لو ركعتين خفيفتين قبل النوم.',
            scheduledDate: tz.TZDateTime.from(qiyamAt, zone),
            notificationDetails: _details,
            androidScheduleMode: mode,
          );
          fullAdhanAlarms.add({
            'at': qiyamAt.millisecondsSinceEpoch,
            'voice': 'qiyam',
          });
          count++;
        }
      }
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
            notificationDetails: detailsFor(),
            androidScheduleMode: mode,
          );
          count++;
        }
        if (followupEnabled && followupDelay > 0) {
          final followAt = prayerTime.add(Duration(minutes: followupDelay));
          final dateKey = '${prayerTime.year.toString().padLeft(4, '0')}-'
              '${prayerTime.month.toString().padLeft(2, '0')}-'
              '${prayerTime.day.toString().padLeft(2, '0')}';
          final done = preferences.getBool('prayer_done_${dateKey}_$name') ?? false;
          if (!done && followAt.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: 3000 + day * 10 + prayer,
              title: '🤍 هل صليت $name؟',
              body: 'لو صليت الحمد لله، علّم عليها من الإشعار. ربنا يتقبل منك.',
              payload: 'prayer|$dateKey|$name',
              scheduledDate: tz.TZDateTime.from(followAt, zone),
              notificationDetails: _followupDetails(),
              androidScheduleMode: mode,
            );
            count++;
          }
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
).hasMatch(dateKey) ||
        !allowed.contains(prayer)) return;
    final prefs = await SharedPreferences.getInstance();
    if (action == _doneAction) {
      await prefs.setBool('prayer_done_${dateKey}_$prayer', true);
    } else {
      // This action only acknowledges the follow-up. It does not silently
      // mark a prayer as completed.
      await prefs.setString('prayer_later_${dateKey}_$prayer',
          DateTime.now().toIso8601String());
      tzdata.initializeTimeZones();
      await _plugin.zonedSchedule(
        id: response.id ?? 3900,
        title: '🤍 هل صليت $prayer؟',
        body: 'تذكير جديد بعد ١٠ دقائق. ربنا يتقبل منك.',
        payload: 'prayer|$dateKey|$prayer',
        scheduledDate: tz.TZDateTime.from(
          DateTime.now().add(const Duration(minutes: 10)), tz.local),
        notificationDetails: _followupDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    if (action == _doneAction && response.id != null) {
      await _plugin.cancel(id: response.id!);
    }
  }

  static NotificationDetails _followupDetails() =>
      const NotificationDetails(android: AndroidNotificationDetails(
        'athr_prayer_followup_v4', 'متابعة الصلاة',
        channelDescription: 'متابعة الصلاة بعد موعدها',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFF073E35),
        styleInformation: BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(_doneAction, 'صليت الحمد لله',
            cancelNotification: true),
          AndroidNotificationAction(_laterAction, 'ذكرني لاحقًا',
            cancelNotification: true),
        ],
      ));

  static Future<PrayerNotificationStatus> status() async {
    await _ensureInitialized();
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final pending = await _plugin.pendingNotificationRequests();
    return PrayerNotificationStatus(
      enabled: enabled, exact: exact,
      pending: pending.where((entry) => entry.id >= 1000 && entry.id < 4000).length,
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


  static Future<void> cancelFollowUp({
    required int dayOffset,
    required int prayerIndex,
  }) async {
    await _ensureInitialized();
    await _plugin.cancel(id: 3000 + dayOffset * 10 + prayerIndex);
  }

  static Future<void> showQiyamPreview() async {
    await _ensureInitialized();
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('اسمح بإشعارات التطبيق أولًا');
    }
    await _plugin.show(
      id: 902,
      title: '🌙 ركعتان تنيران ليلتك',
      body: 'لا تنسَ قيام الليل 🤍 حتى لو ركعتين خفيفتين قبل النوم.',
      notificationDetails: _details,
    );
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
      if (item.id >= 1000 && item.id < 4000) {
        await _plugin.cancel(id: item.id);
      }
    }

    final preferences = await SharedPreferences.getInstance();
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
    final qiyamEnabled = preferences.getBool('qiyam_reminder_enabled') ?? true;
    final followupEnabled = preferences.getBool('prayer_followup_enabled') ?? true;
    final followupDelay = preferences.getInt('prayer_followup_delay') ?? 10;
    final now = DateTime.now();
    var count = 0;
    final fullAdhanAlarms = <Map<String, Object>>[];
    for (var day = 0; day < days.length; day++) {
      final isha = days[day]['العشاء'];
      if (qiyamEnabled && isha != null) {
        final at = tz.TZDateTime(zone, isha.year, isha.month, isha.day, 22);
        final afterIsha = isha.add(const Duration(minutes: 45));
        final qiyamAt = afterIsha.isAfter(at) ? afterIsha : at;
        if (qiyamAt.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: 2000 + day,
            title: '🌙 ركعتان تنيران ليلتك',
            body: 'لا تنسَ قيام الليل 🤍 حتى لو ركعتين خفيفتين قبل النوم.',
            scheduledDate: tz.TZDateTime.from(qiyamAt, zone),
            notificationDetails: _details,
            androidScheduleMode: mode,
          );
          fullAdhanAlarms.add({
            'at': qiyamAt.millisecondsSinceEpoch,
            'voice': 'qiyam',
          });
          count++;
        }
      }
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
        if (followupEnabled && followupDelay > 0) {
          final followAt = prayerTime.add(Duration(minutes: followupDelay));
          final dateKey = '${prayerTime.year.toString().padLeft(4, '0')}-'
              '${prayerTime.month.toString().padLeft(2, '0')}-'
              '${prayerTime.day.toString().padLeft(2, '0')}';
          final done = preferences.getBool('prayer_done_${dateKey}_$name') ?? false;
          if (!done && followAt.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: 3000 + day * 10 + prayer,
              title: '🤍 هل صليت $name؟',
              body: 'لو صليت الحمد لله، افتح متابعة الصلاة وعلّم عليها. ربنا يتقبل منك.',
              scheduledDate: tz.TZDateTime.from(followAt, zone),
              notificationDetails: _details,
              androidScheduleMode: mode,
            );
            count++;
          }
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
