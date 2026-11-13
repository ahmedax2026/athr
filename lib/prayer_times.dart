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

  @override
  Widget build(BuildContext context) {
    final active = nextTime != null;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _forest, foregroundColor: Colors.white,
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(onPressed: _useGps, icon: const Icon(Icons.my_location),
              tooltip: 'تحديد الموقع تلقائيًا'),
          IconButton(onPressed: _searchCity, icon: const Icon(Icons.travel_explore),
              tooltip: 'مدينة أخرى'),
        ],
      ),
      body: busy ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B6150), Color(0xFF05362D)],
              begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _gold, width: 1.3)),
          child: Column(children: [
            const Icon(Icons.mosque_rounded, color: _gold, size: 42),
            const SizedBox(height: 12),
            Text(city, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Colors.white,
                  fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Text(active ? 'الصلاة القادمة: $nextName' : 'حدد موقعك لعرض المواقيت',
              style: const TextStyle(fontSize: 17, color: _gold)),
            const SizedBox(height: 8),
            Text(_remaining(), textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 39, color: Colors.white,
                  fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(active ? 'موعد الصلاة: ${_clock(nextTime)}' : 'المواقيت حسب موقع المدينة',
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ]),
        ),
        if (error != null) Padding(padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        if (!active) FilledButton.icon(
          onPressed: _useGps, icon: const Icon(Icons.location_on),
          label: const Text('تحديد موقعي الآن')),
        if (!active) OutlinedButton.icon(
          onPressed: _searchCity, icon: const Icon(Icons.public),
          label: const Text('اختيار مدينة من أي مكان بالعالم')),
        for (final name in names) Card(
          color: active && name == nextName ? const Color(0xFFE9D2A1) : Colors.white,
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: Icon(name == 'الشروق' ? Icons.wb_sunny_outlined
                : Icons.auto_awesome, color: _forest),
            title: Text(name, style: const TextStyle(
              color: _forest, fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: Text(_clock(today[name]),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontWeight: FontWeight.w800,
                  color: _forest, fontSize: 17)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('إعدادات الحساب والتنبيهات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _forest)),
        const SizedBox(height: 8),
        Card(child: Column(children: [
          ListTile(
            title: const Text('طريقة حساب المواقيت'),
            subtitle: Text(methods[method] ?? methods['egypt']!),
            trailing: DropdownButton<String>(
              value: method,
              items: methods.entries.map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.key == 'egypt' ? 'مصر' : e.key))).toList(),
              onChanged: (value) { if (value != null) _setMethod(value); },
            ),
          ),
          ListTile(
            title: const Text('التنبيه قبل الصلاة'),
            subtitle: Text(reminder == 0 ? 'بدون تنبيه مسبق' : 'قبل الصلاة بـ $reminder دقيقة'),
            trailing: DropdownButton<int>(
              value: reminder,
              items: [0,5,10,15,30].map((m) => DropdownMenuItem(
                value: m, child: Text('$m د'))).toList(),
              onChanged: (value) { if (value != null) _setReminder(value); },
            ),
          ),
          const ListTile(
            leading: Icon(Icons.notifications_active_outlined, color: _forest),
            title: Text('إشعار دخول وقت الصلاة'),
            subtitle: Text('أساسي، يحتاج موافقة الهاتف على الإشعارات'),
          ),
          SwitchListTile(
            value: adhanEnabled,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('adhan', value);
              if (mounted) setState(() => adhanEnabled = value);
            },
            title: const Text('تشغيل صوت الأذان اختياريًا'),
            subtitle: const Text('الصوت الكامل يحتاج تنفيذًا إضافيًا في الخلفية؛ الإشعارات تعمل مستقلة عنه'),
          ),
        ])),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('تُحسب المواقيت فلكيًا حسب إحداثيات المدينة وطريقة الحساب المختارة. '
              'قد تختلف دقائق عن التقويم الرسمي للمساجد؛ ويمكن تغيير الطريقة عند الحاجة.',
            style: TextStyle(color: Color(0xFF586B60), height: 1.6)),
        ),
      ]),
    );
  }
}
