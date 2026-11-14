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
import 'prayer_admin_policy.dart';
import 'adhan_catalog.dart';

const _forest = Color(0xFF063D33);
const _gold = Color(0xFFD9BC7D);
const _cream = Color(0xFFF8F0DE);

/// Rebuild the next two weeks of prayer notifications from the saved
/// location when the home settings toggle changes, even if the prayer page
/// has not been opened in the current session.
Future<bool> refreshPrayerScheduleFromCache() async {
  final prefs = await SharedPreferences.getInstance();
  final lat = prefs.getDouble('prayer_lat');
  final lon = prefs.getDouble('prayer_lon');
  if (lat == null || lon == null) return false;
  tzdata.initializeTimeZones();
  final location = findLocation(lon, lat);
  if (location == null) return false;
  final parameters = switch (prefs.getString('prayer_method') ?? 'egypt') {
    'umm' => adhan.CalculationMethodParameters.ummAlQura(),
    'mwl' => adhan.CalculationMethodParameters.muslimWorldLeague(),
    'karachi' => adhan.CalculationMethodParameters.karachi(),
    'north' => adhan.CalculationMethodParameters.northAmerica(),
    'turkiye' => adhan.CalculationMethodParameters.turkiye(),
    'singapore' => adhan.CalculationMethodParameters.singapore(),
    _ => adhan.CalculationMethodParameters.egyptian(),
  };
  final localNow = tz.TZDateTime.now(location);
  final days = <Map<String, DateTime>>[];
  for (var day = 0; day < 14; day++) {
    final date = tz.TZDateTime(
      location, localNow.year, localNow.month, localNow.day + day);
    final times = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(lat, lon),
      date: date, calculationParameters: parameters);
    days.add({
      'الفجر': times.fajr,
      'الشروق': times.sunrise,
      'الظهر': times.dhuhr,
      'العصر': times.asr,
      'المغرب': times.maghrib,
      'العشاء': times.isha,
    });
  }
  await PrayerNotifications.schedule(
    days: days, zone: location,
    reminderMinutes: prefs.getInt('prayer_reminder') ?? 10);
  return true;
}

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
  bool followupEnabled = true;
  bool qiyamEnabled = true;
  final Map<String, bool> prayedToday = {};
  bool adhanEnabled = false;
  final AudioPlayer adhanPreview = AudioPlayer();
  StreamSubscription<void>? _previewFinished;
  String adhanVoice = 'adhan_makkah';
  String fajrVoice = 'adhan_makkah';
  String? previewingVoice;
  List<Map<String, dynamic>> customVoices = [];
  bool downloadingVoice = false;
  static const voiceNames = <String, String>{
    'adhan_makkah': 'أذان الحرم المكي',
    'adhan_afasy': 'أذان مشاري العفاسي',
  };
  PrayerNotificationStatus? notificationStatus;
  bool checkingNotifications = false;
  bool _gpsRunning = false;
  bool _locationSettingsPending = false;
  VoidCallback? _refreshDiagnostics;
  bool busy = true;
  String? error;
  DateTime now = DateTime.now();
  final _clockTick = ValueNotifier<int>(0);
  String? _displayedPrayerDay;
  bool _refreshingPrayerDay = false;
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
    _previewFinished = adhanPreview.onPlayerComplete.listen((_) {
      if (mounted) setState(() => previewingVoice = null);
    });
    tzdata.initializeTimeZones();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      now = DateTime.now();
      _clockTick.value++;
      if (_displayedPrayerDay != null && _displayedPrayerDay != _dayStamp) {
        _refreshPrayerDay();
      }
      if (nextTime != null && !now.isBefore(nextTime!)) _compute();
    });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    _clockTick.dispose();
    _previewFinished?.cancel();
    adhanPreview.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkNotificationStatus());
    if (_locationSettingsPending) {
      _locationSettingsPending = false;
      unawaited(_useGps(automatic: true, allowSettings: false));
    }
    if (_displayedPrayerDay != _dayStamp) _refreshPrayerDay();
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
    followupEnabled = prefs.getBool('prayer_followup_enabled') ?? true;
    qiyamEnabled = prefs.getBool('qiyam_reminder_enabled') ?? true;
    await _loadCompletedPrayers();
    adhanEnabled = prefs.getBool('adhan') ?? false;
    adhanVoice = prefs.getString('adhan_voice') ?? 'adhan_makkah';
    fajrVoice = prefs.getString('adhan_fajr_voice') ?? 'adhan_makkah';
    adhanVoice = await AdhanCatalog.availableVoice(adhanVoice);
    fajrVoice = await AdhanCatalog.availableVoice(fajrVoice);
    unawaited(_loadCustomVoices());
    // Show saved prayer times immediately. Never block the page on permission
    // prompts, notification scheduling, GPS, or reverse geocoding.
    if (latitude != null && longitude != null) {
      _resolveZone();
      _compute();
    }
    if (!mounted) return;
    setState(() => busy = false);
    // Refresh the current location silently; a previously saved position
    // remains the offline fallback if network or GPS is unavailable.
    unawaited(_refreshInBackground());
    unawaited(_useGps(automatic: true));
  }

  Future<void> _refreshInBackground() async {
    try {
      notificationStatus = await PrayerNotifications.status();
      if (mounted) setState(() {});
      if (latitude != null && zone != null) {
        await _schedule();
      }
    } catch (_) {
      // A permission/service issue must not block offline prayer times.
    }
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
    _compute();
    if (mounted) setState(() => busy = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('prayer_lat', lat);
    await prefs.setDouble('prayer_lon', lon);
    await prefs.setString('prayer_city', label);
    _compute();
    await _schedule();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _useGps({bool automatic = false, bool allowSettings = true}) async {
    if (!mounted || _gpsRunning) return;
    _gpsRunning = true;
    final hasCachedLocation = latitude != null && longitude != null;
    // Automatic refresh is always silent, including on first use.
    // Manual location changes may show their own loading indication.
    if (!automatic) {
      setState(() { busy = true; error = null; });
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && allowSettings) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (permission == LocationPermission.deniedForever && !automatic && allowSettings) {
          _locationSettingsPending = true;
          await Geolocator.openAppSettings();
        }
        throw StateError('لم يُسمح بالوصول للموقع');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (allowSettings) {
          _locationSettingsPending = true;
          await Geolocator.openLocationSettings();
        }
        return;
      }
      if (automatic && !hasCachedLocation) {
        final last = await Geolocator.getLastKnownPosition();
        if (!mounted) return;
        if (last != null) await _storePosition(last.latitude, last.longitude, 'آخر موقع معروف');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12)));
      if (!mounted) return;
      String label = city == 'حدد المدينة' ? 'موقعي الحالي' : city;
      try {
        if (!automatic || city == 'حدد المدينة') {
        final places = await geocoding.placemarkFromCoordinates(
          position.latitude, position.longitude);
        if (places.isNotEmpty) {
          final place = places.first;
          label = [place.locality, place.administrativeArea, place.country]
              .where((value) => value != null && value.trim().isNotEmpty)
              .join('، ');
          if (label.isEmpty) label = 'موقعي الحالي';
        }
        }
      } catch (_) {
        // Reverse geocoding can fail offline: coordinates still work.
      }
      if (!mounted) return;
      await _storePosition(position.latitude, position.longitude, label);
      await _loadCompletedPrayers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        // Preserve cached prayer times instead of showing a location error
        // on every automatic opening, but make first-time setup actionable.
        if (!automatic) {
          error = e.toString();
        } else if (latitude == null || longitude == null) {
          error = 'يمكنك السماح بالموقع لحساب المواقيت تلقائيًا أو اختيار مدينة.';
        }
      });
    } finally {
      _gpsRunning = false;
      if (mounted && busy) setState(() => busy = false);
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

  String get _dayStamp {
    final day = zone == null
        ? DateTime.now()
        : tz.TZDateTime.from(DateTime.now(), zone!);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshPrayerDay() async {
    if (_refreshingPrayerDay || !mounted) return;
    _refreshingPrayerDay = true;
    try {
      await _loadCompletedPrayers();
      if (mounted && latitude != null && zone != null) _compute();
    } finally {
      _refreshingPrayerDay = false;
    }
  }

  Future<void> _loadCompletedPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final day = _dayStamp;
    final loaded = <String, bool>{};
    for (final name in names.where((v) => v != 'الشروق')) {
      loaded[name] = prefs.getBool('prayer_done_${day}_$name') ?? false;
    }
    if (!mounted) return;
    setState(() {
      prayedToday..clear()..addAll(loaded);
      _displayedPrayerDay = day;
    });
  }

  Future<void> _markPrayer(String name) async {
    final previous = prayedToday[name] ?? false;
    final next = !previous;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_done_${_dayStamp}_$name', next);
    if (!mounted) return;
    setState(() => prayedToday[name] = next);
    if (next) {
      const prayerNames = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      final prayerIndex = prayerNames.indexOf(name);
      if (prayerIndex != -1) {
        await PrayerNotifications.cancelFollowUp(
          dayOffset: 0, prayerIndex: prayerIndex);
      }
    } else {
      await _schedule();
    }
  }

  Future<void> _setFollowup(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_followup_enabled', value);
    if (!mounted) return;
    setState(() => followupEnabled = value);
    await _schedule();
  }

  Future<void> _setQiyam(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('qiyam_reminder_enabled', value);
    if (!mounted) return;
    setState(() => qiyamEnabled = value);
    await _schedule();
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
      if (mounted) {
        setState(() => notificationStatus = status);
        _refreshDiagnostics?.call();
      }
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

  Future<void> _loadCustomVoices() async {
    final items = await AdhanCatalog.load();
    if (mounted) setState(() => customVoices = items);
  }

  String _voiceLabel(String id) => voiceNames[id] ??
      customVoices.where((v) => v['id'] == id).map((v) => v['name'].toString()).firstOrNull ?? 'صوت الأذان المختار';

  Future<void> _openVoicePicker() async {
    if (downloadingVoice || !mounted) return;
    await adhanPreview.stop();
    if (!mounted) return;
    setState(() => previewingVoice = null);
    final chosen = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AdhanVoicePicker(selected: adhanVoice),
    );
    if (chosen == null || !mounted) return;
    final id = chosen['id']!;
    setState(() => downloadingVoice = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('adhan_voice', id);
      await prefs.setString('adhan_fajr_voice', id);
      if (!mounted) return;
      setState(() {
        adhanVoice = id;
        fajrVoice = id;
        if (chosen['url'] != null) {
          customVoices = [...customVoices.where((v) => v['id'] != id), Map<String, dynamic>.from(chosen)];
        }
      });
      await _schedule();
    } finally {
      if (mounted) setState(() => downloadingVoice = false);
    }
  }

  Future<void> _previewVoice(String voice, {bool forcePlay = false}) async {
    try {
      if (!forcePlay && previewingVoice == voice) {
        await adhanPreview.stop();
        if (mounted) setState(() => previewingVoice = null);
        return;
      }
      await adhanPreview.stop();
      if (!mounted) return;
      setState(() => previewingVoice = null);
      await adhanPreview.play(AdhanCatalog.validId.hasMatch(voice)
          ? DeviceFileSource(await AdhanCatalog.localPath(voice))
          : AssetSource('adhan/$voice.mp3'));
      if (mounted) setState(() => previewingVoice = voice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر تشغيل الصوت التجريبي: $e')));
      }
    }
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

  bool _startingTest = false;
  Future<void> _testScheduledReminder() async {
    if (zone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدد مدينتك أو موقعك قبل تجربة التنبيه المجدول')));
      return;
    }
    if (_startingTest) return;
    _startingTest = true;
    try {
      final policy = await PrayerAdminPolicy.load();
      final seconds = policy.minutes('testDelaySeconds', 10, 5, 120);
      if (!mounted) return;
      if (adhanEnabled) {
        await PrayerNotifications.testFullAdhan(adhanVoice, seconds: seconds);
      } else {
        await PrayerNotifications.scheduleTest(zone: zone!, seconds: seconds);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle_outline, color: _gold, size: 28), const SizedBox(width: 12), Expanded(child: Text('تم ضبط الاختبار بعد $seconds ثانية. يمكنك البقاء هنا أو إغلاق الشاشة.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
        duration: Duration(seconds: seconds.clamp(5, 12).toInt())));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('لم يتم ضبط تنبيه التجربة: $e')));
      }
    } finally { _startingTest = false; }
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

  // Detailed diagnostics live in a separate dialog so the everyday
  // settings panel remains beautiful and fully visible without scrolling.
  void _openDiagnostics(StateSetter refresh) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, repaint) {
          _refreshDiagnostics = () { if (dialogContext.mounted) { repaint(() {}); refresh(() {}); } };
          Future<void> update() async {
            try {
              final latest = await PrayerNotifications.status();
              if (!dialogContext.mounted) return;
              setState(() => notificationStatus = latest);
              repaint(() {});
              refresh(() {});
            } catch (_) {
              if (dialogContext.mounted) repaint(() {});
            }
          }

          Widget stateRow(String title, bool? active,
              IconData icon, String hint) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3CFA7))),
              child: Row(children: [
                Icon(icon, color: _forest),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      color: _forest, fontWeight: FontWeight.w900)),
                    Text(hint, style: const TextStyle(
                      color: Color(0xFF67756D), fontSize: 11)),
                  ],
                )),
                Text(active == null ? 'جارٍ الفحص' :
                    active ? 'مفعّل' : title == 'العمل في الخلفية' ? 'غير مستثنى' : 'يحتاج تفعيل',
                  style: TextStyle(
                    color: active == true ? _forest :
                      const Color(0xFF9F6033),
                    fontSize: 12, fontWeight: FontWeight.w900)),
              ]),
            ),
          );

          return AlertDialog(
            backgroundColor: _cream,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: const BorderSide(color: _gold, width: 1.6)),
            title: const Column(children: [
              Icon(Icons.verified_user_rounded,
                color: _forest, size: 34),
              SizedBox(height: 5),
              Text('فحص الإشعارات', textAlign: TextAlign.center,
                style: TextStyle(color: _forest,
                  fontWeight: FontWeight.w900, fontSize: 23)),
              SizedBox(height: 4),
              Text('تأكد من وصول تنبيهات الصلاة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF68756B),
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            scrollable: true,
            content: SizedBox(width: 355, child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                stateRow('السماح بالإشعارات',
                  notificationStatus?.enabled,
                  Icons.notifications_active_outlined,
                  'مطلوب لاستقبال إشعارات الصلاة'),
                stateRow('التنبيهات في وقتها',
                  notificationStatus?.exact,
                  Icons.alarm_rounded,
                  'يساعد في وصول التنبيه بدقة'),
                stateRow('العمل في الخلفية', notificationStatus?.unrestrictedBattery, Icons.battery_charging_full, 'اختر البطارية ثم بدون قيود إن كان متاحًا'),
                if(notificationStatus?.unrestrictedBattery != true)
                  OutlinedButton.icon(onPressed: () async { await PrayerNotifications.openBatterySettings(); }, icon:const Icon(Icons.settings_outlined), label:const Text('إعدادات البطارية')),
                const SizedBox(height: 8),
                if (notificationStatus?.enabled != true)
                  SizedBox(width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _enableNotifications();
                        await update();
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('تفعيل الإشعارات'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: Colors.white))),
                if (notificationStatus?.exact != true)
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _enablePreciseReminders();
                        await update();
                      },
                      icon: const Icon(Icons.alarm_on_rounded),
                      label: const Text('ضبط التوقيت الدقيق'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _forest,
                        side: const BorderSide(color: _gold, width: 1.4)))),
                Row(children: [
                  Expanded(child: FilledButton(
                    onPressed: () async {
                      await _testNotification();
                      await update();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _forest,
                      foregroundColor: Colors.white),
                    child: const Text('اختبار الآن'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(
                    onPressed: () async {
                      await _testScheduledReminder();
                      await update();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _forest,
                      foregroundColor: Colors.white),
                    child: Text(adhanEnabled ? 'اختبار الأذان' : 'اختبار مجدول'))),
                ]),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('تم', style: TextStyle(
                    color: _forest, fontWeight: FontWeight.w900))),
              ],
            )),
          );
        },
      ),
    ).whenComplete(() => _refreshDiagnostics = null);
    unawaited(_checkNotificationStatus());
  }

  Widget _settingsToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF3),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFDCC58D), width: 1)),
    child: Row(children: [
      Container(
        width: 35, height: 35,
        decoration: BoxDecoration(
          color: _forest, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: _gold, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _forest,
              fontWeight: FontWeight.w900, fontSize: 14)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF756B58), fontSize: 11)),
        ])),
      Switch.adaptive(
        value: value,
        activeTrackColor: _forest,
        activeThumbColor: _gold,
        onChanged: onChanged),
    ]),
  );

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: _cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _forest, brightness: Brightness.light, surface: _cream),
          textTheme: Theme.of(ctx).textTheme.apply(
            bodyColor: _forest, displayColor: _forest)),
        child: StatefulBuilder(builder: (ctx, refresh) =>
          SafeArea(child: FractionallySizedBox(
            heightFactor: .94,
            child: LayoutBuilder(builder: (ctx, bounds) {
              // All options on one screen. Scale modestly on shorter devices
              // instead of hiding actions below an invisible scroll region.
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: bounds.maxWidth < 390 ? bounds.maxWidth : 390,
                  height: 718,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(children: [
                      Container(
                        height: 104,
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF14634E), Color(0xFF04362E)]),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: _gold, width: 1.5)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mosque_rounded, color: _gold, size: 24),
                                SizedBox(width: 8),
                                Flexible(child: Text('الأذان والتنبيهات',
                                  maxLines: 1,
                                  style: TextStyle(color: Colors.white,
                                    fontSize: 22, fontWeight: FontWeight.w900))),
                              ]),
                            const SizedBox(height: 5),
                            const Text('إعدادات بسيطة ومريحة لكل صلاة',
                              style: TextStyle(color: Color(0xFFFFE7B5),
                                fontSize: 12)),
                          ]),
                      ),
                      const SizedBox(height: 11),
                      _settingsToggle(
                        title: 'تشغيل الأذان كاملًا',
                        subtitle: 'يعمل بالصوت المختار وقت الصلاة',
                        icon: Icons.volume_up_rounded,
                        value: adhanEnabled,
                        onChanged: (enabled) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('adhan', enabled);
                          if (!mounted) return;
                          setState(() => adhanEnabled = enabled);
                          if (!enabled) {
                            await adhanPreview.stop();
                            if (mounted) setState(() => previewingVoice = null);
                          }
                          refresh(() {});
                          await _schedule();
                        }),
                      Container(
                        height: 106,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF3),
                          border: Border.all(color: const Color(0xFFDCC58D)),
                          borderRadius: BorderRadius.circular(17)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('اختر صوت الأذان',
                              style: TextStyle(color: _forest,
                                fontSize: 14, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: Material(
                                color: _forest,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: downloadingVoice ? null : () async {
                                    await _openVoicePicker();
                                    if (ctx.mounted) refresh(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                                    child: Row(children: [
                                      const Icon(Icons.graphic_eq_rounded, color: _gold, size: 19),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_voiceLabel(adhanVoice),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
                                      const Icon(Icons.keyboard_arrow_down_rounded, color: _gold),
                                    ]),
                                  ),
                                ),
                              )),
                              IconButton(
                                onPressed: downloadingVoice ? null : () async {
                                  await _previewVoice(adhanVoice);
                                  if (ctx.mounted) refresh(() {});
                                },
                                tooltip: previewingVoice == adhanVoice ? 'إيقاف المعاينة' : 'تشغيل المعاينة',
                                icon: Icon(previewingVoice == adhanVoice ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                  color: _forest, size: 28)),
                            ]),
                            Text(downloadingVoice ? 'جارٍ تنزيل الصوت...' : 'اضغط السهم لاختيار المؤذن • يعمل دون إنترنت بعد التحميل',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(
                                fontSize: 10, color: Color(0xFF74664D))),
                          ]),
                      ),
                      const SizedBox(height: 9),
                      _settingsToggle(
                        title: 'تذكير قبل الصلاة',
                        subtitle: reminder == 0 ? 'متوقف' : 'قبل الأذان بـ $reminder دقيقة',
                        icon: Icons.notifications_active_rounded,
                        value: reminder != 0,
                        onChanged: (enabled) {
                          final next = enabled ? 10 : 0;
                          setState(() => reminder = next);
                          refresh(() {});
                          unawaited(_setReminder(next));
                        }),
                      if (reminder > 0)
                        SizedBox(height: 40,
                          child: Row(children: [
                            const Text('قبل الصلاة', style: TextStyle(
                              color: _forest, fontSize: 12,
                              fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Expanded(child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true, value: reminder,
                                dropdownColor: _cream,
                                style: const TextStyle(color: _forest,
                                  fontWeight: FontWeight.w900, fontSize: 13),
                                items: [5, 10, 15, 20, 30, 45, 60]
                                  .map((minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes دقيقة')))
                                  .toList(),
                                onChanged: (next) {
                                  if (next == null) return;
                                  setState(() => reminder = next);
                                  refresh(() {});
                                  unawaited(_setReminder(next));
                                },
                              ),
                            )),
                          ]),
                        ),
                      _settingsToggle(
                        title: 'متابعة الصلاة',
                        subtitle: 'اسألني بعد الصلاة بـ 30 دقيقة',
                        icon: Icons.fact_check_rounded,
                        value: followupEnabled,
                        onChanged: (enabled) async {
                          await _setFollowup(enabled);
                          refresh(() {});
                        }),
                      _settingsToggle(
                        title: 'قيام الليل',
                        subtitle: 'تذكير لطيف بركعتين قبل النوم',
                        icon: Icons.nights_stay_rounded,
                        value: qiyamEnabled,
                        onChanged: (enabled) async {
                          await _setQiyam(enabled);
                          refresh(() {});
                        }),
                      const SizedBox(height: 5),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _forest,
                          borderRadius: BorderRadius.circular(15)),
                        child: Row(children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.place_outlined, color: _gold),
                          const SizedBox(width: 6),
                          const Expanded(child: Text('حساب المواقيت',
                            style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 13))),
                          DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: methods.containsKey(method) ? method : 'egypt',
                            dropdownColor: _forest,
                            style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w800),
                            iconEnabledColor: _gold,
                            items: methods.keys.map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v == 'egypt' ? 'مصر' : v,
                                style: const TextStyle(color: Colors.white)))).toList(),
                            onChanged: (v) async {
                              if (v == null) return;
                              await _setMethod(v);
                              refresh(() {});
                            })),
                          const SizedBox(width: 12),
                        ]),
                      ),
                      const Spacer(),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => _openDiagnostics(refresh),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(43),
                            foregroundColor: _forest,
                            side: const BorderSide(color: _gold, width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.verified_user_outlined, size: 18),
                          label: const Text('فحص الإشعارات'))),
                        const SizedBox(width: 9),
                        Expanded(child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(43),
                            backgroundColor: _forest,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('تم')),
                        ),
                      ]),
                    ]),
                  ),
                ),
              );
            }),
          ))),
      ),
    ).whenComplete(() async {
      await adhanPreview.stop();
      if (mounted) setState(() => previewingVoice = null);
    });
  }

  Widget _compactTile(String prayer) {
    final next = nextTime != null && nextName == prayer;
    final sunrise = prayer == 'الشروق';
    final completed = prayedToday[prayer] ?? false;
    final accent = completed ? const Color(0xFF70D5A6) : _gold;
    return LayoutBuilder(builder: (context, limits) {
      final compact = limits.maxHeight < 105;
      return Container(
        padding: EdgeInsets.fromLTRB(9, compact ? 6 : 9, 9, compact ? 4 : 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: completed
                ? const [Color(0xFF126D51), Color(0xFF063B32)]
                : next
                    ? const [Color(0xFF286958), Color(0xFF073D35)]
                    : const [Color(0xFF125345), Color(0xFF052F2B)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: next || completed ? accent : _gold.withValues(alpha: .57),
            width: next || completed ? 1.6 : 1),
          boxShadow: const [BoxShadow(
            color: Color(0x26002E28), blurRadius: 9, offset: Offset(0, 4))]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(_prayerIcon(prayer), size: compact ? 17 : 21, color: accent),
              const SizedBox(width: 6),
              Expanded(child: Text(prayer, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w900))),
              if (next)
                const Icon(Icons.brightness_1, size: 7, color: _gold),
            ]),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_clock(today[prayer]),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: const Color(0xFFFFF1CD),
                    fontSize: compact ? 14 : 18,
                    fontWeight: FontWeight.w900)),
              ),
            ),
            if (sunrise)
              const Align(alignment: Alignment.centerRight,
                child: Text('موعد الشروق', style: TextStyle(
                  color: _gold, fontSize: 10)))
            else
              SizedBox(
                height: compact ? 26 : 31,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _markPrayer(prayer),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    backgroundColor: completed
                        ? const Color(0xFFD9F2DE) : const Color(0xFFECD6A3),
                    foregroundColor: _forest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    visualDensity: VisualDensity.compact,
                    elevation: 0),
                  icon: Icon(completed
                      ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: compact ? 14 : 16),
                  label: FittedBox(fit: BoxFit.scaleDown,
                    child: Text(completed ? 'تمت الصلاة ✓' : 'صليت الحمد لله',
                      style: const TextStyle(fontWeight: FontWeight.w900,
                        fontSize: 11))),
                ),
              ),
          ],
        ),
      );
    });
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
                    horizontal: 13, vertical: tight ? 7 : 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06372F),
                    border: Border.all(color: _gold, width: 1.7),
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: const [BoxShadow(
                      color: Color(0x3000221B), blurRadius: 10,
                      offset: Offset(0, 4))]),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.location_on_rounded,
                        color: Color(0xFFFFE0A1), size: 18),
                      const SizedBox(width: 5),
                      Flexible(child: Text(city, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w900))),
                      IconButton(onPressed: _useGps,
                        tooltip: 'تحديث الموقع',
                        icon: const Icon(Icons.my_location_rounded,
                          color: Color(0xFFFFE0A1), size: 21),
                        constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(4)),
                    ]),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF145C4D),
                        border: Border.all(
                          color: const Color(0xFFFFE0A1), width: .8),
                        borderRadius: BorderRadius.circular(11)),
                      child: Text(
                        nextTime == null
                          ? 'حدد المدينة لعرض المواقيت'
                          : 'الصلاة القادمة: $nextName • ${_clock(nextTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w900)),
                    ),
                    SizedBox(height: tight ? 3 : 6),
                    FittedBox(child: ValueListenableBuilder<int>(
                      valueListenable: _clockTick,
                      builder: (context, tick, child) => Text(_remaining(),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: const Color(0xFFFFE0A1),
                        fontSize: tight ? 32 : 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)))),
                  ]),
                ),
                if (error != null)
                  Padding(padding: const EdgeInsets.only(top: 3),
                    child: Text(error!, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.red, fontSize: 10))),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tight ? 5 : 8),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_outlined,
                      color: _forest, size: 18),
                    const SizedBox(width: 6),
                    const Text('صلوات اليوم',
                      style: TextStyle(color: _forest, fontSize: 16,
                        fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: _forest, borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _gold)),
                      child: Text(
                        '${prayedToday.values.where((done) => done).length} / 5 تمت',
                        style: const TextStyle(color: _gold,
                          fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
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
                  padding: EdgeInsets.fromLTRB(10, tight ? 4 : 8, 10, tight ? 4 : 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C4E40), Color(0xFF06332B)]),
                    border: Border.all(color: _gold, width: 1.1),
                    borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Icon(notificationStatus?.enabled == true && notificationStatus?.exact == true && (notificationStatus?.pending ?? 0) > 0
                        ? Icons.verified_outlined
                        : Icons.notifications_off_outlined,
                      color: _gold, size: 22),
                    const SizedBox(width: 7),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notificationStatus?.enabled != true ? 'الإشعارات تحتاج تفعيل' : notificationStatus?.exact != true ? 'فعّل التوقيت الدقيق' : adhanEnabled ? 'الأذان جاهز للتجربة' : 'تنبيهات الصلاة مفعلة',
                          style: const TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w800)),
                        Text(reminder == 0 ? 'بدون تنبيه مسبق'
                            : 'قبل الصلاة بـ $reminder دقيقة',
                          style: const TextStyle(color: _gold,
                            fontSize: 11)),
                      ])),
                    FilledButton.icon(onPressed: _openSettings,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold, foregroundColor: _forest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

class _AdhanVoicePicker extends StatefulWidget {
  const _AdhanVoicePicker({required this.selected});
  final String selected;
  @override
  State<_AdhanVoicePicker> createState() => _AdhanVoicePickerState();
}

class _AdhanVoicePickerState extends State<_AdhanVoicePicker> {
  final _player = AudioPlayer();
  StreamSubscription<void>? _finished;
  List<Map<String, dynamic>> _voices = [];
  bool _loading = true;
  bool _startingPreview = false;
  String _query = '';
  String? _playing;
  String? _selecting;
  String? _selectionError;
  Future<void> _select(Map<String, String> item) async {
    if (_startingPreview || _selecting != null) return;
    setState(() { _selecting = item['id']; _selectionError = null; });
    try {
      await _player.stop();
      if (!mounted) return;
      setState(() => _playing = null);
      final url = item['url'];
      if (url != null) await AdhanCatalog.download(item['id']!, url);
      if (mounted) Navigator.pop(context, item);
    } catch (e) {
      if (mounted) {
        setState(() => _selectionError = e is StateError && e.message == 'file too large'
          ? 'حجم الأذان يتجاوز 50 ميجابايت. اختر تسجيلًا أقل حجمًا.'
          : 'تعذر حفظ الصوت للعمل دون إنترنت. تحقق من الاتصال وصلاحية الملف ثم أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _selecting = null);
    }
  }
  @override
  void initState() {
    super.initState();
    _finished = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    _load();
  }
  Future<void> _load() async {
    final voices = await AdhanCatalog.load();
    if (mounted) setState(() { _voices = voices; _loading = false; });
  }
  Future<void> _preview(String id, String? url) async {
    if (_startingPreview) return;
    setState(() => _startingPreview = true);
    try {
      final wasPlaying = _playing == id;
      await _player.stop();
      if (!mounted) return;
      setState(() => _playing = null);
      if (wasPlaying) return;
      if (url == null) {
        await _player.play(AssetSource('adhan/$id.mp3'));
      } else {
        try {
          await _player.play(UrlSource(url)).timeout(const Duration(seconds: 20));
        } catch (_) {
          await _player.stop();
          final path = await AdhanCatalog.download(id, url);
          if (!mounted) return;
          await _player.play(DeviceFileSource(path));
        }
      }
      if (mounted) setState(() => _playing = id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذرت المعاينة. تحقق من الاتصال والرابط.')));
      }
    } finally {
      if (mounted) setState(() => _startingPreview = false);
    }
  }
  @override
  void dispose() {
    _finished?.cancel();
    _player.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final entries = <Map<String, String>>[
      for (final item in AdhanCatalog.builtIn.entries) {'id': item.key, 'name': item.value},
      for (final item in _voices) {'id': item['id'].toString(), 'name': item['name'].toString(), 'url': item['url'].toString()},
    ].where((item) => item['name']!.contains(_query.trim())).toList();
    return Directionality(textDirection: TextDirection.rtl, child: SafeArea(
      child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: FractionallySizedBox(heightFactor: .78, child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 42, height: 4, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(8))),
          const Padding(padding: EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.graphic_eq_rounded, color: _forest, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('اختر صوت المؤذن', style: TextStyle(color: _forest, fontWeight: FontWeight.w900, fontSize: 22))),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
            style: const TextStyle(color: _forest, fontWeight: FontWeight.w700),
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(hintText: 'ابحث باسم المؤذن', hintStyle: const TextStyle(color: _forest),
              prefixIcon: const Icon(Icons.search_rounded, color: _forest), filled: true, fillColor: const Color(0xFFFFFCF3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _gold))),
          )),
          const SizedBox(height: 10),
          if (_loading || _selecting != null) const LinearProgressIndicator(color: _forest, backgroundColor: _gold),
          if (_selecting != null) const Padding(padding: EdgeInsets.all(8), child: Text('جارٍ حفظ الأذان على الجهاز...', style: TextStyle(color: _forest, fontWeight: FontWeight.bold))),
          if (_selectionError != null) Padding(padding: const EdgeInsets.all(8), child: Text(_selectionError!, style: const TextStyle(color: _forest, fontWeight: FontWeight.bold))),
          Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: entries.length, separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = entries[index], id = item['id']!;
              final active = widget.selected == id, playing = _playing == id;
              return Material(
                color: active ? _forest : const Color(0xFFFFFCF3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: _gold)),
                child: ListTile(
                  onTap: _startingPreview || _selecting != null ? null : () => _select(item),
                  leading: IconButton(onPressed: _startingPreview || _selecting != null ? null : () => _select(item),
                    tooltip: 'اختيار المؤذن', icon: Icon(active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: active ? _gold : _forest)),
                  title: Text(item['name']!, style: TextStyle(color: active ? Colors.white : _forest, fontWeight: FontWeight.w900)),
                  subtitle: Text(active ? 'الصوت الحالي' : item['url'] == null ? 'محفوظ في التطبيق' : 'تحميل عند الاختيار',
                    style: TextStyle(color: active ? _gold : const Color(0xFF74664D), fontSize: 11)),
                  trailing: IconButton(
                    onPressed: _startingPreview || _selecting != null ? null : () => _preview(id, item['url']),
                    tooltip: playing ? 'إيقاف المعاينة' : 'معاينة',
                    icon: Icon(playing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      color: active ? _gold : _forest, size: 30)),
                ),
              );
            },
          )),
        ])),
      ),
    ));
  }
}
