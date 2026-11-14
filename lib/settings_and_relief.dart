import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_finder/timezone_finder.dart';
import 'prayer_notifications.dart';
import 'prayer_times.dart';
import 'prayer_admin_policy.dart';

const _settingGreen = Color(0xFF073E35);
const _settingGold = Color(0xFFD6B56C);
const _settingCream = Color(0xFFF8F0DE);

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen>
    with WidgetsBindingObserver {
  final Map<String, bool> _values = {};
  bool _ready = false;
  bool _working = false;
  String? _message;
  PrayerNotificationStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus();
    }
  }

  Future<void> _updateStatus() async {
    try {
      final status = await PrayerNotifications.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // The on-device permission dialog can be unavailable on some devices.
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _values['adhan'] = prefs.getBool('adhan') ?? false;
      _values['reminders'] = prefs.getBool('reminders') ?? false;
      _values['daily_prayer'] = prefs.getBool('daily_prayer') ?? false;
      _values['vibration'] = prefs.getBool('vibration') ?? false;
      _ready = true;
    });
    await _updateStatus();
    try { await _syncDaily(); } catch (_) {}
  }

  PrayerAdminPolicy _policy = const PrayerAdminPolicy({});
  Future<void> _syncDaily() async {
    await refreshDailyRemindersFromCache();
    final latest = await PrayerAdminPolicy.load();
    if (mounted) setState(() => _policy = latest);
  }

  Future<void> _change(String key, bool value) async {
    if (_working) return;
    setState(() {
      _working = true;
      _message = null;
      _values[key] = value;
    });
    final prefs = await SharedPreferences.getInstance();
    try {
      if (value && (key == 'adhan' ||
          key == 'reminders' || key == 'daily_prayer')) {
        final granted = await PrayerNotifications.requestNotificationPermission();
        if (!granted) {
          throw StateError('اسمح بالإشعارات أولًا من إعدادات الهاتف.');
        }
      }
      await prefs.setBool(key, value);
      if (key == 'reminders' || key == 'daily_prayer') {
        await _syncDaily();
      } else if (key == 'adhan') {
        final scheduled = await refreshPrayerScheduleFromCache();
        if (!scheduled && value) {
          _message = 'تم حفظ اختيار الأذان. افتح مواقيت الصلاة وحدد موقعك مرة واحدة لتشغيله تلقائيًا.';
        }
      }
    } catch (e) {
      await prefs.setBool(key, !value);
      if (mounted) setState(() => _values[key] = !value);
      _message = e is StateError ? e.message.toString() :
          'تعذر تفعيل الميزة حاليًا. راجع صلاحيات الإشعارات وحاول مجددًا.';
    } finally {
      if (mounted) setState(() => _working = false);
      await _updateStatus();
    }
  }

  Widget _settingRow(String key, String title, String description,
      IconData icon) {
    final enabled = _values[key] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _settingGold.withValues(alpha: .65))),
      child: SwitchListTile.adaptive(
        activeTrackColor: _settingGreen,
        activeThumbColor: _settingGold,
        title: Text(title, style: const TextStyle(color: _settingGreen,
          fontWeight: FontWeight.w900, fontSize: 16)),
        subtitle: Text(description, style: const TextStyle(
          color: Color(0xFF5E6A63), fontSize: 12, height: 1.5)),
        secondary: Icon(icon, color: _settingGreen),
        value: enabled, onChanged: _working ? null : (v) => _change(key, v)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _settingCream,
    appBar: AppBar(title: const Text('الإعدادات',
      style: TextStyle(fontWeight: FontWeight.w900)),
      backgroundColor: _settingGreen, foregroundColor: Colors.white),
    body: !_ready
      ? const Center(child: CircularProgressIndicator(color: _settingGreen))
      : SafeArea(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF15624F), _settingGreen]),
                borderRadius: BorderRadius.circular(20)),
              child: const Column(children: [
                Icon(Icons.tune_rounded, color: _settingGold, size: 30),
                SizedBox(height: 5),
                Text('تفضيلاتك', style: TextStyle(
                  color: Colors.white, fontSize: 24,
                  fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('إعدادات واضحة، وتعمل بضغطة واحدة',
                  style: TextStyle(color: Color(0xFFF1E3C3), fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 15),
            _settingRow('adhan', 'تشغيل الأذان',
              'الأذان الكامل في مواعيد الصلاة بالصوت المختار',
              Icons.volume_up_rounded),
            _settingRow('reminders', 'أذكار الصباح والمساء',
              'صباحًا ${_policy.clock('morningAzkarTime')} • مساءً ${_policy.clock('eveningAzkarTime')}',
              Icons.notifications_active_outlined),
            _settingRow('daily_prayer', 'الدعاء اليومي',
              'تذكير يومي الساعة ${_policy.clock('dailyDuaTime')}',
              Icons.favorite_rounded),
            _settingRow('vibration', 'اهتزاز السبحة',
              'اهتزاز خفيف عند كل تسبيحة',
              Icons.vibration_rounded),
            if (_message != null) Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_message!, textAlign: TextAlign.center,
                style: const TextStyle(color: _settingGreen,
                  fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
              tileColor: Colors.white,
              leading: Icon(_status?.enabled == true
                  ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: _settingGreen),
              title: Text(_status?.enabled == true
                  ? 'الإشعارات مسموح بها' : 'إشعارات التطبيق تحتاج السماح',
                style: const TextStyle(color: _settingGreen,
                  fontWeight: FontWeight.w800)),
              subtitle: const Text('يمكنك مراجعة صلاحيات الهاتف من هنا'),
              trailing: const Icon(Icons.settings_rounded, color: _settingGreen),
              onTap: () async {
                await PrayerNotifications.openNotificationSettings();
                await _updateStatus();
              },
            ),
            const SizedBox(height: 12),
            const Text('تُجدَّد تذكيرات الأذكار والدعاء للأيام القادمة عند فتح الإعدادات. وقد تؤخر قيود البطارية بعض التنبيهات؛ جرّب الاختبار من صفحة مواقيت الصلاة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF59675E),
                height: 1.5, fontSize: 12)),
          ],
        )),
  );
}

class ReliefScreen extends StatelessWidget {
  const ReliefScreen({super.key});
  static const prayers = [
    ('دعاء الكرب', 'لا إله إلا الله العظيم الحليم، لا إله إلا الله رب العرش العظيم، لا إله إلا الله رب السماوات ورب الأرض ورب العرش الكريم.'),
    ('دعاء الهم والحزن', 'اللهم إني أعوذ بك من الهم والحزن، والعجز والكسل، والبخل والجبن، وضلع الدين وغلبة الرجال.'),
    ('دعاء ذي النون', 'لا إله إلا أنت سبحانك إني كنت من الظالمين.'),
    ('دعاء التيسير', 'اللهم لا سهل إلا ما جعلته سهلاً، وأنت تجعل الحزن إذا شئت سهلاً.'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFD6B56C) : const Color(0xFF075B4A);
    return Scaffold(
      appBar: AppBar(title: const Text('فك كرب')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF176451), Color(0xFF073E35)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(children: [
            Icon(Icons.volunteer_activism_outlined, color: Color(0xFFD6B56C), size: 40),
            SizedBox(height: 12),
            Text('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا', textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFF5EBD5), fontSize: 23, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('سورة الشرح — الآية 5', style: TextStyle(color: Color(0xFFB9C9BD))),
          ]),
        ),
        const SizedBox(height: 18),
        for (final prayer in prayers)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prayer.$1, style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(prayer.$2, style: const TextStyle(fontSize: 18, height: 1.9)),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        const Text('اللهم فرّج همّ كل مهموم ونفّس كرب كل مكروب.',
          textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
      ]),
    );
  }
}

Future<tz.Location> _reminderZone() async {
    tzdata.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('prayer_lat');
    final lon = prefs.getDouble('prayer_lon');
    if (lat != null && lon != null) {
      final found = findLocation(lon, lat);
      if (found != null) return found;
    }
    // Until first location setup, use Cairo as a documented fallback for
    // Egyptian users rather than pretending we know their timezone.
    return tz.getLocation('Africa/Cairo');
  }


Future<void> refreshDailyRemindersFromCache() async {
  final prefs = await SharedPreferences.getInstance();
  final zone = await _reminderZone();
  await PrayerNotifications.syncDailyReminders(zone: zone,
    azkar: prefs.getBool('reminders') ?? false,
    dailyDua: prefs.getBool('daily_prayer') ?? false);
}
