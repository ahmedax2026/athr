import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'prayer_admin_policy.dart';
import 'adhan_catalog.dart';
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

@pragma('vm:entry-point')
void prayerNotificationAction(NotificationResponse response) async {
  if (response.actionId != 'prayed' || response.payload == null) return;
  final key = response.payload!;
  if (!key.startsWith('prayer_done_')) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, true);
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
      onDidReceiveNotificationResponse: prayerNotificationAction,
      onDidReceiveBackgroundNotificationResponse: prayerNotificationAction,
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

  /// Separate notification IDs keep optional daily content independent from
  /// prayer-time notifications (which use IDs 1000–3999).
  static Future<void> syncDailyReminders({
    required tz.Location zone,
    required bool azkar,
    required bool dailyDua,
  }) async {
    await _ensureInitialized();
    for (var day = 0; day < 14; day++) {
      for (final id in [5000 + day * 2, 5001 + day * 2, 6000 + day]) {
        await _plugin.cancel(id: id);
      }
    }
    if (!azkar && !dailyDua) return;
    if (!(await _android?.areNotificationsEnabled() ?? false)) {
      throw StateError('اسمح للتطبيق بإرسال الإشعارات من إعدادات الهاتف');
    }
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(zone);
    for (var day = 0; day < 14; day++) {
      final date = tz.TZDateTime(zone, now.year, now.month, now.day + day);
      if (azkar) {
        for (final entry in [
          (hour: 8, id: 5000 + day * 2, title: 'أذكار الصباح'),
          (hour: 18, id: 5001 + day * 2, title: 'أذكار المساء'),
        ]) {
          final at = tz.TZDateTime(
            zone, date.year, date.month, date.day, entry.hour);
          if (at.isAfter(now)) {
            await _plugin.zonedSchedule(
              id: entry.id,
              title: entry.title,
              body: 'خذ دقيقة لذكر الله، وابدأ وردك اليومي في أثر لا ينقطع.',
              scheduledDate: at,
              notificationDetails: _details,
              androidScheduleMode: mode,
            );
          }
        }
      }
      if (dailyDua) {
        final at = tz.TZDateTime(
          zone, date.year, date.month, date.day, 20, 30);
        if (at.isAfter(now)) {
          await _plugin.zonedSchedule(
            id: 6000 + day,
            title: 'دعاء اليوم 🤍',
            body: 'اللهم اغفر لنا ولوالدينا وارحم موتانا وموتى المسلمين.',
            scheduledDate: at,
            notificationDetails: _details,
            androidScheduleMode: mode,
          );
        }
      }
    }
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
    final policy = await PrayerAdminPolicy.load();
    final useAdhan = (preferences.getBool('adhan') ?? false) && policy.allows('allowAdhan');
    final normalVoice = preferences.getString('adhan_voice') ?? 'adhan_makkah';
    final normalAvailable = await AdhanCatalog.availableVoice(normalVoice);
    final fajrAvailable = await AdhanCatalog.availableVoice(preferences.getString('adhan_fajr_voice') ?? normalVoice);
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
    final qiyamEnabled = (preferences.getBool('qiyam_reminder_enabled') ?? true) && policy.allows('allowQiyam');
    final followupEnabled = (preferences.getBool('prayer_followup_enabled') ?? true) && policy.allows('allowFollowup');
    final followupDelay = policy.minutes('followupMinutes', 30, 5, 120);
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
            final chosen = name == 'الفجر' ? fajrAvailable : normalAvailable;
            fullAdhanAlarms.add({
              'at': prayerTime.millisecondsSinceEpoch,
              'voice': chosen,
            });
          }
          await _plugin.zonedSchedule(
            id: 1000 + day * 20 + prayer * 2,
            title: 'حان الآن موعد صلاة $name',
            body: policy.text('prayerBody', 'حي على الصلاة • أثر لا ينقطع'),
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
              title: '🤍 هل صليت صلاة $name؟',
              body: policy.text('followupBody', 'مر $followupDelay دقيقة على موعد الصلاة. ربنا يتقبل منك.'),
              payload: 'prayer_done_${dateKey}_$name',
              scheduledDate: tz.TZDateTime.from(followAt, zone),
              notificationDetails: const NotificationDetails(android: AndroidNotificationDetails(
                'athr_prayer_followup_v1', 'متابعة الصلاة',
                importance: Importance.high, priority: Priority.high,
                actions: [AndroidNotificationAction('prayed', 'نعم، صليت'),
                  AndroidNotificationAction('not_yet', 'ليس بعد')],
              )),
              androidScheduleMode: mode,
            );
            count++;
          }
        }
        if (reminderMinutes > 0 && policy.allows('allowAdvance')) {
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
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  'athr_prayer_early_silent_v1', 'تذكير قبل الصلاة',
                  channelDescription: 'تنبيه بصري قبل الصلاة، ويُشغّل الصوت مرة واحدة في الخلفية',
                  importance: Importance.high,
                  priority: Priority.high,
                  playSound: false,
                )),
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
