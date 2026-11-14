import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_finder/timezone_finder.dart';
import 'prayer_notifications.dart';

const _forest = Color(0xFF063D33);
const _gold = Color(0xFFD9BC7D);
const _cream = Color(0xFFF8F0DE);

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with WidgetsBindingObserver {
  final Geocoding geocoding = Geocoding();
  double? latitude, longitude;
  String city = 'حدد المدينة';
  String method = 'egypt';
  int reminder = 10;
  bool adhanEnabled = false;
  final AudioPlayer adhanPreview = AudioPlayer();
  String adhanVoice = 'adhan_makkah';
  String fajrVoice = 'adhan_makkah';
  String? previewingVoice;
  static const voiceNames = <String, String>{
    'adhan_makkah': 'أذان الحرم المكي',
    'adhan_afasy': 'أذان مشاري العفاسي',
  };
  PrayerNotificationStatus? notificationStatus;
  bool checkingNotifications = false;
  bool busy = true;
  String? error;
  DateTime now = DateTime.now();
  Timer? timer;
  tz.Location? zone;
  Map<String, DateTime> today = {};
  DateTime? nextTime;
  String nextName = 'الفجر';

  static const names = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static const methods = <String, String>{
    'egypt': 'الهيئة المصرية العامة للمساحة',
    'umm': 'أم القرى - السعودية',
    'mwl': 'رابطة العالم الإسلامي',
    'karachi': 'جامعة كراتشي',
    'north': 'أمريكا الشمالية',
    'turkiye': 'تركيا',
    'singapore': 'سنغافورة وماليزيا',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tzdata.initializeTimeZones();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => now = DateTime.now());
      if (nextTime != null && !now.isBefore(nextTime!)) _compute();
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    adhanPreview.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _checkNotificationStatus();
    if (latitude != null && zone != null) {
      _compute();
      _schedule();
    }
  }

  adhan.CalculationParameters _parameters() {
    switch (method) {
      case 'umm': return adhan.CalculationMethodParameters.ummAlQura();
      case 'mwl': return adhan.CalculationMethodParameters.muslimWorldLeague();
      case 'karachi': return adhan.CalculationMethodParameters.karachi();
      case 'north': return adhan.CalculationMethodParameters.northAmerica();
      case 'turkiye': return adhan.CalculationMethodParameters.turkiye();
      case 'singapore': return adhan.CalculationMethodParameters.singapore();
      default: return adhan.CalculationMethodParameters.egyptian();
    }
  }

  Map<String, DateTime> _forDate(DateTime date) {
    final coordinates = adhan.Coordinates(latitude!, longitude!);
    final times = adhan.PrayerTimes(
      coordinates: coordinates,
      date: tz.TZDateTime.from(date, zone!),
      calculationParameters: _parameters(),
    );
    return {
      'الفجر': times.fajr,
      'الشروق': times.sunrise,
      'الظهر': times.dhuhr,
      'العصر': times.asr,
      'المغرب': times.maghrib,
      'العشاء': times.isha,
    };
  }

  void _compute() {
    if (latitude == null || longitude == null || zone == null) return;
    final localNow = tz.TZDateTime.from(now, zone!);
    final current = tz.TZDateTime(zone!, localNow.year, localNow.month, localNow.day);
    today = _forDate(current);
    final tomorrow = _forDate(current.add(const Duration(days: 1)));
    nextTime = null;
    for (final name in names.where((n) => n != 'الشروق')) {
      final time = today[name]!;
      if (time.isAfter(now)) { nextTime = time; nextName = name; break; }
    }
    if (nextTime == null) { nextTime = tomorrow['الفجر']; nextName = 'الفجر'; }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    latitude = prefs.getDouble('prayer_lat');
    longitude = prefs.getDouble('prayer_lon');
    city = prefs.getString('prayer_city') ?? 'حدد المدينة';
    method = prefs.getString('prayer_method') ?? 'egypt';
    reminder = prefs.getInt('prayer_reminder') ?? 10;
    adhanEnabled = prefs.getBool('adhan') ?? false;
    adhanVoice = prefs.getString('adhan_voice') ?? 'adhan_makkah';
    fajrVoice = prefs.getString('adhan_fajr_voice') ?? 'adhan_makkah';
    if (!voiceNames.containsKey(adhanVoice)) adhanVoice = 'adhan_makkah';
    if (!voiceNames.containsKey(fajrVoice)) fajrVoice = 'adhan_makkah';
    // Ask for notification permission when the prayer timetable opens.
    // The Android exact-alarm special access remains a separate user action.
    try {
      final allowed = await PrayerNotifications.requestNotificationPermission();
      notificationStatus = await PrayerNotifications.status();
      if (latitude != null && longitude != null) {
        _resolveZone();
        _compute();
        if (allowed) await _schedule();
      }
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر تهيئة تنبيهات الصلاة: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  void _resolveZone() {
    if (latitude == null || longitude == null) return;
    zone = findLocation(longitude!, latitude!);
    if (zone == null) {
      error = 'تعذر تحديد المنطقة الزمنية. اختر مدينة أخرى.';
    } else {
      error = null;
    }
  }

  Future<void> _storePosition(double lat, double lon, String label) async {
    latitude = lat; longitude = lon; city = label;
    _resolveZone();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('prayer_lat', lat);
    await prefs.setDouble('prayer_lon', lon);
    await prefs.setString('prayer_city', label);
    _compute();
    await _schedule();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _useGps() async {
    setState(() { busy = true; error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('فعّل خدمة الموقع في الهاتف أولًا');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('اسمح للتطبيق بالوصول للموقع، أو اختر مدينة يدويًا');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      String label = 'موقعي الحالي';
      try {
        final places = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
        if (places.isNotEmpty) {
          final p = places.first;
          label = [p.locality, p.administrativeArea, p.country]
              .where((s) => s != null && s.trim().isNotEmpty).join('، ');
        }
      } catch (_) {}
      await _storePosition(position.latitude, position.longitude, label);
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString(); });
    }
  }

  Future<void> _searchCity() async {
    // Keep the entered text in the dialog state. Disposing a controller
    // while the closing route still owns its TextField triggers Flutter's
    // _dependents.isEmpty assertion on some Android builds.
    var searchText = '';
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر مدينة من أي دولة'),
        content: TextField(
          autofocus: true,
          textDirection: TextDirection.rtl,
          onChanged: (value) => searchText = value,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          decoration: const InputDecoration(
            hintText: 'مثال: أسيوط، مصر أو London, UK',
            border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, searchText.trim()),
              child: const Text('بحث')),
        ],
      ),
    );
    if (!mounted) return;
    if (query == null || query.isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      final locations = await geocoding.locationFromAddress(query);
      if (locations.isEmpty) { throw StateError('المدينة غير موجودة'); }
      await _storePosition(locations.first.latitude, locations.first.longitude, query);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'تعذر العثور على المدينة. اكتب المدينة والدولة وتأكد من الإنترنت.';
        });
      }
    }
  }

  Future<void> _schedule() async {
    if (latitude == null || zone == null) return;
    try {
      final localNow = tz.TZDateTime.from(DateTime.now(), zone!);
      final dates = <DateTime>[];
      for (var day = 0; day < 14; day++) {
        final date = tz.TZDateTime(zone!, localNow.year, localNow.month, localNow.day + day);
        dates.add(date);
      }
      await PrayerNotifications.schedule(
        days: dates.map(_forDate).toList(),
        zone: zone!, reminderMinutes: reminder);
      final status = await PrayerNotifications.status();
      if (mounted) {
        setState(() {
          notificationStatus = status;
          error = status.pending == 0 ? 'لم يتم تأكيد وجود إشعارات مجدولة؛ افحص الصلاحيات.' : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر جدولة الإشعارات: $e');
    }
  }

  Future<void> _checkNotificationStatus() async {
    if (checkingNotifications) return;
    setState(() => checkingNotifications = true);
    try {
      final status = await PrayerNotifications.status();
      if (mounted) setState(() => notificationStatus = status);
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر فحص الإشعارات: $e');
    } finally {
      if (mounted) setState(() => checkingNotifications = false);
    }
  }

  Future<void> _enableNotifications() async {
    final allowed = await PrayerNotifications.requestNotificationPermission();
    await _checkNotificationStatus();
    if (!mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('السماح بالإشعارات ضروري لاستقبال تنبيهات الصلاة')));
      await PrayerNotifications.openNotificationSettings();
      return;
    }
    await _schedule();
  }

  Future<void> _enablePreciseReminders() async {
    final granted = await PrayerNotifications.requestExactPermission();
    await _checkNotificationStatus();
    if (!mounted) return;
    if (granted) {
      await _schedule();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التوقيت الدقيق لم يُفعّل بعد. سيستمر استخدام التنبيهات التقريبية.')));
    }
  }

  Future<void> _setVoice(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    if (mounted) {
      setState(() {
        if (key == 'adhan_voice') {
          adhanVoice = value;
        } else {
          fajrVoice = value;
        }
      });
    }
    await _schedule();
  }

  Future<void> _previewVoice(String voice) async {
    try {
      if (previewingVoice == voice) {
        await adhanPreview.stop();
        if (mounted) setState(() => previewingVoice = null);
        return;
      }
      await adhanPreview.stop();
      await adhanPreview.play(AssetSource('adhan/$voice.mp3'));
      if (mounted) setState(() => previewingVoice = voice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر تشغيل الصوت التجريبي: $e')));
      }
    }
  }

  Widget _voiceSelector(String label, String value, String prefKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
          color: _forest, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: voiceNames.containsKey(value) ? value : 'adhan_makkah',
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true, border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            items: voiceNames.entries.map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (choice) {
              if (choice != null) _setVoice(prefKey, choice);
            },
          )),
          const SizedBox(width: 7),
          IconButton.filledTonal(
            tooltip: previewingVoice == value ? 'إيقاف التجربة' : 'تجربة الصوت',
            onPressed: () => _previewVoice(value),
            icon: Icon(previewingVoice == value
              ? Icons.stop_circle_outlined : Icons.play_arrow_rounded),
          ),
        ]),
      ]),
    );
  }

  Future<void> _testNotification() async {
    try {
      await PrayerNotifications.showTest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أرسلنا إشعار اختبار الآن. افحص لوحة الإشعارات.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر إرسال الاختبار: $e')));
      }
    }
  }

  Future<void> _testScheduledReminder() async {
    if (zone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدد مدينتك أو موقعك قبل تجربة التنبيه المجدول')));
      return;
    }
    try {
      if (adhanEnabled) {
        await PrayerNotifications.testFullAdhan(adhanVoice);
      } else {
        await PrayerNotifications.scheduleTest(zone: zone!);
      }
      await _checkNotificationStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(adhanEnabled ? 'تم ضبط الأذان الكامل بعد دقيقتين. اقفل الشاشة وجرب وصوله.' : 'تم ضبط تنبيه تجريبي بعد دقيقتين. اقفل الشاشة وجرب وصوله.'),
        duration: Duration(seconds: 6)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لم يتم ضبط تنبيه التجربة: $e')));
      }
    }
  }

  Future<void> _setMethod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    method = value;
    await prefs.setString('prayer_method', value);
    _compute();
    await _schedule();
  }

  Future<void> _setReminder(int value) async {
    final prefs = await SharedPreferences.getInstance();
    reminder = value;
    await prefs.setInt('prayer_reminder', value);
    await _schedule();
    if (mounted) setState(() {});
  }

  String _clock(DateTime? time) {
    if (time == null || zone == null) return '--:--';
    final t = tz.TZDateTime.from(time, zone!);
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'ص' : 'م'}';
  }

  String _remaining() {
    if (nextTime == null) return '--:--:--';
    final duration = nextTime!.difference(now);
    if (duration.isNegative) return '00:00:00';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final mins = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$mins:$secs';
  }


  IconData _prayerIcon(String prayer) {
    switch (prayer) {
      case 'الفجر': return Icons.wb_twilight_rounded;
      case 'الشروق': return Icons.wb_sunny_outlined;
      case 'الظهر': return Icons.wb_sunny_rounded;
      case 'العصر': return Icons.light_mode_outlined;
      case 'المغرب': return Icons.nights_stay_outlined;
      default: return Icons.dark_mode_outlined;
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _cream,
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _forest,
            brightness: Brightness.light,
            surface: _cream),
          textTheme: Theme.of(ctx).textTheme.apply(
            bodyColor: _forest, displayColor: _forest)),
        child: StatefulBuilder(
        builder: (ctx, refresh) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.94,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                const Icon(Icons.mosque_rounded, color: _gold, size: 38),
                const SizedBox(height: 8),
                const Center(child: Text('إعدادات الأذان والتنبيهات',
                  style: TextStyle(color: _forest, fontSize: 25,
                    fontWeight: FontWeight.w900))),
                const SizedBox(height: 8),
                const Center(child: Text(
                  'تحكم في الأذان والتذكير بالصلاة من مكان واحد',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _forest, fontSize: 14))),
                const SizedBox(height: 22),
                SwitchListTile.adaptive(
                  activeTrackColor: _forest,
                  activeThumbColor: _gold,
                  title: const Text('تفعيل صوت الأذان',
                    style: TextStyle(color: _forest, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                  subtitle: const Text('التشغيل يعتمد على أذونات الهاتف وإعدادات Android',
                    style: TextStyle(color: Color(0xFF5F5848), fontSize: 13)),
                  value: adhanEnabled,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('adhan', value);
                    if (!mounted) return;
                    setState(() => adhanEnabled = value);
                    refresh(() {});
                    if (value) {
                      final status = await PrayerNotifications.status();
                      if (!status.exact) await _enablePreciseReminders();
                      else await _schedule();
                    } else {
                      await _schedule();
                    }
                  },
                ),
                if (adhanEnabled) ...[
                  _voiceSelector('صوت الأذان للصلوات', adhanVoice, 'adhan_voice'),
                ],
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('تقدر تسمع الصوت قبل اختياره. صوت المعيقلي لم يُضف بعد. أذان الفجر يستخدم نفس الصوت المختار للصلوات حاليًا.',
                    style: TextStyle(fontSize: 12, color: _forest, height: 1.5)),
                ),
                const Divider(color: _gold, height: 28),
                const Text('مواعيد التنبيهات',
                  style: TextStyle(color: _forest, fontSize: 18,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text('تنبيه قبل الصلاة',
                    style: TextStyle(color: _forest, fontWeight: FontWeight.w800)),
                  trailing: DropdownButton<int>(
                    value: reminder,
                    items: [0, 5, 10, 15, 20, 30, 45, 60].map((v) =>
                      DropdownMenuItem(value: v,
                        child: Text(v == 0 ? 'إيقاف' : '$v دقيقة'))).toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      await _setReminder(v);
                      refresh(() {});
                    },
                  ),
                ),
                ListTile(
                  title: const Text('طريقة حساب المواقيت',
                    style: TextStyle(color: _forest, fontWeight: FontWeight.w800)),
                  trailing: DropdownButton<String>(
                    value: methods.containsKey(method) ? method : 'egypt',
                    items: methods.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.key == 'egypt' ? 'مصر' : e.key))).toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      await _setMethod(v);
                      refresh(() {});
                    },
                  ),
                ),
                const Divider(color: _gold, height: 30),
                const Text('حالة الإشعارات والاختبار',
                  style: TextStyle(color: _forest, fontSize: 18,
                    fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    notificationStatus == null ? 'لم يتم فحص الإشعارات'
                      : !notificationStatus!.enabled ? 'الإشعارات محظورة'
                      : !notificationStatus!.exact ? 'التوقيت الدقيق غير مفعل؛ قد تتأخر التنبيهات'
                      : notificationStatus!.pending == 0 ? 'لا توجد تنبيهات مجدولة'
                      : 'تمت جدولة ${notificationStatus!.pending} إشعار؛ اختبر وصولها على هاتفك',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _forest, fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                if (notificationStatus?.unrestrictedBattery == false)
                  const Padding(padding: EdgeInsets.all(8), child: Text('تحسين البطارية قد يؤخر الأذان على بعض الهواتف. اسمح بالعمل في الخلفية من إعدادات الهاتف.', textAlign: TextAlign.center, style: TextStyle(color: _forest))),
                Wrap(spacing: 10, runSpacing: 12,
                  alignment: WrapAlignment.center, children: [
                  OutlinedButton.icon(onPressed: () async { await PrayerNotifications.openBatterySettings(); }, icon: const Icon(Icons.battery_charging_full), label: const Text('إعدادات البطارية')),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _checkNotificationStatus();
                      refresh(() {});
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('فحص التنبيهات')),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await _enableNotifications();
                      refresh(() {});
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('سماح الإشعارات')),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _enablePreciseReminders();
                      refresh(() {});
                    },
                    icon: const Icon(Icons.alarm_on_outlined),
                    label: const Text('التوقيت الدقيق')),
                  OutlinedButton.icon(
                    onPressed: _testNotification,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('اختبار فوري')),
                  FilledButton.icon(
                    onPressed: _testScheduledReminder,
                    icon: const Icon(Icons.timer_outlined),
                    label: Text(adhanEnabled ? 'اختبار الأذان الكامل' : 'اختبار بعد دقيقتين')),
                ]),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _compactTile(String prayer) {
    final next = nextTime != null && nextName == prayer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: next ? const Color(0xFFEAD7A6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: next ? const Color(0xFFC09A50) : const Color(0xFFE3D9C6),
          width: next ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(_prayerIcon(prayer), size: 18, color: _forest),
        const SizedBox(width: 5),
        Expanded(child: Text(prayer, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _forest, fontSize: 13,
            fontWeight: FontWeight.w800))),
        FittedBox(fit: BoxFit.scaleDown,
          child: Text(_clock(today[prayer]),
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: _forest, fontSize: 12,
              fontWeight: FontWeight.w800))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        title: const Text('مواقيت الصلاة',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _searchCity,
            icon: const Icon(Icons.location_city_outlined),
            tooltip: 'تغيير المدينة'),
          IconButton(onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'الأذان والتنبيهات'),
        ],
      ),
      body: busy
        ? const Center(child: CircularProgressIndicator(color: _forest))
        : SafeArea(child: LayoutBuilder(builder: (context, bounds) {
            final tight = bounds.maxHeight < 510;
            return Padding(
              padding: EdgeInsets.fromLTRB(10, tight ? 5 : 12, 10, tight ? 5 : 12),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: tight ? 7 : 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF146853), Color(0xFF063D33), Color(0xFF032C27)]),
                    border: Border.all(color: _gold),
                    borderRadius: BorderRadius.circular(22)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.location_on_outlined,
                        color: _gold, size: 17),
                      const SizedBox(width: 4),
                      Flexible(child: Text(city, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w800))),
                      IconButton(onPressed: _useGps,
                        icon: const Icon(Icons.my_location_rounded,
                          color: _gold, size: 18),
                        tooltip: 'موقعي الحالي',
                        visualDensity: VisualDensity.compact),
                    ]),
                    Text(nextTime == null ? 'حدد المدينة لعرض المواقيت'
                      : 'الصلاة القادمة: $nextName • ${_clock(nextTime)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _gold, fontSize: 13,
                        fontWeight: FontWeight.w800)),
                    FittedBox(child: Text(_remaining(),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: Colors.white,
                        fontSize: tight ? 29 : 38,
                        fontWeight: FontWeight.w900, letterSpacing: 2))),
                  ]),
                ),
                if (error != null)
                  Padding(padding: const EdgeInsets.only(top: 3),
                    child: Text(error!, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.red, fontSize: 10))),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tight ? 6 : 10),
                  child: const Row(children: [
                    Icon(Icons.calendar_month_outlined,
                      color: _forest, size: 18),
                    SizedBox(width: 6),
                    Text('مواقيت اليوم',
                      style: TextStyle(color: _forest, fontSize: 16,
                        fontWeight: FontWeight.w900)),
                  ]),
                ),
                Expanded(child: LayoutBuilder(builder: (context, gridBounds) {
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: (gridBounds.maxHeight - 14) / 3,
                      mainAxisSpacing: 7, crossAxisSpacing: 7),
                    itemCount: names.length,
                    itemBuilder: (context, index) => _compactTile(names[index]),
                  );
                })),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
                  decoration: BoxDecoration(color: Colors.white,
                    border: Border.all(color: const Color(0xFFE3D9C6)),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(notificationStatus?.enabled == true && notificationStatus?.exact == true && (notificationStatus?.pending ?? 0) > 0
                        ? Icons.verified_outlined
                        : Icons.notifications_off_outlined,
                      color: _forest, size: 22),
                    const SizedBox(width: 7),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notificationStatus?.enabled != true ? 'الإشعارات تحتاج تفعيل' : notificationStatus?.exact != true ? 'فعّل التوقيت الدقيق' : adhanEnabled ? 'الأذان جاهز للتجربة' : 'تنبيهات الصلاة مفعلة',
                          style: const TextStyle(color: _forest,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                        Text(reminder == 0 ? 'بدون تنبيه مسبق'
                            : 'قبل الصلاة بـ $reminder دقيقة',
                          style: const TextStyle(color: Color(0xFF776A55),
                            fontSize: 11)),
                      ])),
                    FilledButton.tonalIcon(onPressed: _openSettings,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: const Text('التحكم')),
                  ]),
                ),
              ]),
            );
          })),
    );
  }
}
