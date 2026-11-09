import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _prefs = SharedPreferencesAsync();
  final Map<String, bool> _values = {};
  bool _ready = false;
  static const _items = [
    ('adhan', 'تشغيل الأذان', 'التفضيل محفوظ؛ تشغيل الأذان التلقائي قيد التطوير', Icons.volume_up_outlined),
    ('reminders', 'تذكيرات الأذكار', 'الإشعارات المجدولة قيد التطوير', Icons.notifications_outlined),
    ('daily_prayer', 'الدعاء اليومي', 'تفضيل محفوظ للتخصيص في تحديث قادم', Icons.favorite_outline),
    ('vibration', 'الاهتزاز عند التسبيح', 'سيعمل عند تطوير السبحة التفاعلية', Icons.vibration),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final item in _items) {
      _values[item.$1] = await _prefs.getBool(item.$1) ?? false;
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _change(String key, bool value) async {
    setState(() => _values[key] = value);
    await _prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFD6B56C) : const Color(0xFF075B4A);
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: !_ready ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.all(18), children: [
          Text('تفضيلاتك', style: TextStyle(color: accent, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('اختار اللي يناسبك. إعداداتك بتتحفظ على نفس الجهاز.'),
          const SizedBox(height: 18),
          Card(
            child: Column(children: [
              for (final item in _items)
                SwitchListTile(
                  title: Text(item.$2),
                  subtitle: Text(item.$3),
                  secondary: Icon(item.$4, color: accent),
                  value: _values[item.$1] ?? false,
                  onChanged: (value) => _change(item.$1, value),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('تنبيه: مفاتيح الأذان والإشعارات والاهتزاز تحفظ رغبتك فقط حاليًا؛ لن تصدر صوتًا أو إشعارات حتى نكمل تنفيذ تلك الميزات.',
            style: TextStyle(height: 1.7)),
        ]),
    );
  }
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
