import 'dart:async';
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

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final Geocoding geocoding = Geocoding();
  double? latitude, longitude;
  String city = 'حدد المدينة';
  String method = 'egypt';
  int reminder = 10;
  bool adhanEnabled = false;
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
    timer?.cancel();
    super.dispose();
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
    if (latitude != null && longitude != null) {
      _resolveZone();
      _compute();
      await _schedule();
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
      for (var day = 0; day < 7; day++) {
        final date = tz.TZDateTime(zone!, localNow.year, localNow.month, localNow.day + day);
        dates.add(date);
      }
      await PrayerNotifications.schedule(
        days: dates.map(_forDate).toList(),
        zone: zone!, reminderMinutes: reminder);
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر جدولة الإشعارات: $e');
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

  Widget _prayerTile(String prayer) {
    final highlighted = nextTime != null && nextName == prayer;
    final isSunrise = prayer == 'الشروق';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEFE0B9) : Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: highlighted ? const Color(0xFFC9A45C) : const Color(0xFFE8DDC7),
          width: highlighted ? 1.7 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x100A4538), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: highlighted ? _forest : const Color(0xFFF4EDE0),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(_prayerIcon(prayer),
            color: highlighted ? _gold : _forest, size: 27),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(prayer, style: const TextStyle(
            color: _forest, fontSize: 19, fontWeight: FontWeight.w800)),
          Text(highlighted ? 'الصلاة القادمة' : (isSunrise ? 'وقت الشروق' : 'موعد الصلاة'),
            style: const TextStyle(color: Color(0xFF887961), fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_clock(today[prayer]), textDirection: TextDirection.ltr,
            style: const TextStyle(color: _forest, fontSize: 18,
              fontWeight: FontWeight.w900)),
          if (highlighted)
            const Text('● التالية', style: TextStyle(
              color: Color(0xFF8C6A2C), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 9, bottom: 13),
    child: Row(children: [
      Icon(icon, color: _forest, size: 24),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(
        color: _forest, fontSize: 22, fontWeight: FontWeight.w900)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final active = nextTime != null;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('مواقيت الصلاة', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          IconButton(onPressed: _useGps, icon: const Icon(Icons.my_location_rounded),
            tooltip: 'تحديد موقعي'),
          IconButton(onPressed: _searchCity, icon: const Icon(Icons.public_rounded),
            tooltip: 'اختيار مدينة حول العالم'),
        ],
      ),
      body: busy ? const Center(child: CircularProgressIndicator(color: _forest))
          : SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight, end: Alignment.bottomLeft,
                colors: [Color(0xFF126D58), Color(0xFF04352D), Color(0xFF052B25)]),
              border: Border.all(color: _gold, width: 1.3),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(color: Color(0x4205322A), blurRadius: 25, offset: Offset(0, 12)),
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0x1CFFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: .75)),
                ),
                child: const Icon(Icons.mosque_rounded, color: _gold, size: 38),
              ),
              const SizedBox(height: 13),
              const Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: TextStyle(color: Color(0xFFEBD9B5), fontSize: 16)),
              const SizedBox(height: 10),
              Text(city, textAlign: TextAlign.center, style: const TextStyle(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 23),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 19, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0x18000000),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: const Color(0x55D9BC7D)),
                ),
                child: Column(children: [
                  Text(active ? 'الصلاة القادمة • $nextName' : 'حدد مدينتك لعرض المواقيت',
                    textAlign: TextAlign.center, style: const TextStyle(
                      color: _gold, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  FittedBox(child: Text(_remaining(),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white,
                      fontSize: 47, letterSpacing: 2, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 9),
                  Text(active ? 'موعد الأذان: ${_clock(nextTime)}'
                      : 'مواقيت دقيقة حسب الإحداثيات وطريقة الحساب',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFE6DCCB), fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _searchCity,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: const Text('تغيير المدينة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFE1A4),
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: _useGps,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('موقعي الحالي'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFE1A4),
                    side: const BorderSide(color: _gold),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                )),
              ]),
            ]),
          ),
          if (error != null)
            Padding(padding: const EdgeInsets.only(top: 14),
              child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 22),
          _sectionHeader('مواقيت اليوم', Icons.calendar_month_outlined),
          for (final prayer in names) _prayerTile(prayer),
          const SizedBox(height: 14),
          _sectionHeader('الأذان والتنبيهات', Icons.notifications_active_outlined),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE7D6B7)),
            ),
            child: Column(children: [
              const ListTile(
                leading: Icon(Icons.notifications_active_rounded, color: _forest),
                title: Text('إشعار دخول وقت الصلاة', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('أساسي لجميع الصلوات الخمس، بعد السماح بالإشعارات'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.volume_up_rounded, color: _forest),
                title: const Text('صوت الأذان', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('اختياري • الصوت التلقائي قيد التطوير'),
                value: adhanEnabled,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('adhan', value);
                  if (mounted) setState(() => adhanEnabled = value);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.alarm_rounded, color: _forest),
                title: const Text('تنبيه قبل الصلاة', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(reminder == 0 ? 'بدون تنبيه مسبق'
                    : 'قبل الصلاة بـ $reminder دقيقة'),
                trailing: DropdownButton<int>(
                  value: reminder, underline: const SizedBox.shrink(),
                  items: [0,5,10,15,30].map((m) => DropdownMenuItem(
                    value: m, child: Text('$m د'))).toList(),
                  onChanged: (value) { if (value != null) _setReminder(value); },
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: _forest),
                title: const Text('طريقة حساب المواقيت', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(methods[method] ?? methods['egypt']!),
                trailing: DropdownButton<String>(
                  value: method, underline: const SizedBox.shrink(),
                  items: methods.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.key == 'egypt' ? 'مصر' : e.key))).toList(),
                  onChanged: (value) { if (value != null) _setMethod(value); },
                ),
              ),
            ]),
          ),
          const SizedBox(height: 15),
          const Text(
            'تُحسب المواقيت حسب موقع المدينة والطريقة المختارة. وقد تختلف دقائق عن تقويم المسجد المحلي. '
            'الإشعارات المجدولة تحتاج موافقة النظام وقد تتأخر بسبب توفير البطارية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF65796B), height: 1.6, fontSize: 12)),
        ],
      )),
    );
  }
}
