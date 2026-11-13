import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_and_cases.dart';
import 'quran.dart';
import 'khatma.dart';
import 'tasbeeh.dart';
import 'azkar.dart';
import 'settings_and_relief.dart';

const emerald = Color(0xFF073E35);
const deep = Color(0xFF052B27);
const gold = Color(0xFFD6B56C);
const cream = Color(0xFFF5EBD5);
const muted = Color(0xFFB9C9BD);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AthrApp());
}

class AthrApp extends StatefulWidget {
  const AthrApp({super.key});
  @override
  State<AthrApp> createState() => _AthrAppState();
}

class _AthrAppState extends State<AthrApp> {
  ThemeMode _mode = ThemeMode.system;

  void _toggleTheme() {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system && brightness == Brightness.dark);
    setState(() => _mode = isDark ? ThemeMode.light : ThemeMode.dark);
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? deep : const Color(0xFFF8F5ED);
    final surface = dark ? emerald : Colors.white;
    final foreground = dark ? cream : const Color(0xFF173C32);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: brightness,
      ).copyWith(primary: dark ? gold : emerald, surface: surface),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'أثر لا ينقطع',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: _mode,
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: WelcomeScreen(onToggleTheme: _toggleTheme),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _count = 0;
  void _pray() {
    if (_count >= 3) return;
    setState(() => _count++);
    if (_count == 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اللهم تقبل', textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF052B27), fontSize: 18, fontWeight: FontWeight.w900)),
        duration: Duration(milliseconds: 1600),
        backgroundColor: Color(0xFFFFE3A0),
      ));
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => HomeScreen(onToggleTheme: widget.onToggleTheme)));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [emerald, deep, Color(0xFF021C1A)])),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: 360,
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: const ValueKey('theme-toggle'),
                    tooltip: 'تغيير المظهر',
                    onPressed: widget.onToggleTheme,
                    icon: const Icon(Icons.brightness_6_outlined, color: gold),
                  ),
                ),
                const Icon(Icons.auto_awesome, color: gold, size: 23),
                const SizedBox(height: 8),
                const LiveContentText(document: 'welcome', field: 'title', fallback: 'أَثَرٌ لَا يَنْقَطِع', style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const LiveContentText(document: 'welcome', field: 'subtitle', fallback: 'ذِكرى طيبة، ودعاء لا ينقطع', style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF164F43),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: gold.withValues(alpha: 0.8), width: 1.4),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 12))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Image.asset(
                      'assets/images/father.jpg',
                      key: const ValueKey('father-portrait'),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 210,
                      errorBuilder: (_, _, _) => const SizedBox(height: 240, child: Center(child: Icon(Icons.person_outline, color: gold, size: 70))),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('صَدَقَةٌ جَارِيَة', textAlign: TextAlign.center, style: TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('على روح المغفور له بإذن الله', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 17, height: 1.7)),
                const SizedBox(height: 3),
                const LiveContentText(document: 'welcome', field: 'name', fallback: 'عبدالوكيل عبدالسيد محمد', style: TextStyle(color: gold, fontSize: 25, fontWeight: FontWeight.w800, height: 1.5)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10473D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: gold.withValues(alpha: 0.35)),
                  ),
                  child: const Column(children: [
                    Icon(Icons.menu_book_outlined, color: gold, size: 22),
                    SizedBox(height: 8),
                    LiveContentText(document: 'welcome', field: 'prayer', fallback: 'اللهم اغفر له وارحمه وعافه واعف عنه، وأكرم نزله ووسع مدخله', style: TextStyle(color: cream, fontSize: 15, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 8),
                _PrayerHeart(count: _count, onTap: _pray),
                const SizedBox(height: 8),
                const Text('اضغط على القلب 3 مرات للدخول إلى أبواب الخير', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                const Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6, runSpacing: 3, children: [
                  Icon(Icons.menu_book_outlined, color: gold, size: 17),
                  Text('قرآن كريم  •  أذكار  •  ختمات جماعية',
                    softWrap: true, textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11)),
                ]),
              ]),
              ),
            ),
          ),
        )),
      ),
    ),
  );
}

class _PrayerHeart extends StatelessWidget {
  const _PrayerHeart({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(children: [
    const Text('دعوة من القلب', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 8),
    Semantics(
      button: true,
      label: 'اللهم ارحمه واغفر له',
      child: InkWell(
        key: const ValueKey('welcome-pray-button'),
        onTap: count < 3 ? onTap : null,
        borderRadius: BorderRadius.circular(90),
        child: SizedBox(
          width: 150,
          height: 128,
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.favorite, size: 128, color: Color(0xFFB68B4E)),
            const Icon(Icons.favorite, size: 118, color: Color(0xFF17584A)),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('اللهم ارحمه\nواغفر له', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 15, fontWeight: FontWeight.w800, height: 1.3)),
            ),
          ]),
        ),
      ),
    ),
    Text('$count/3', key: const ValueKey('tasbeeh-count'), style: const TextStyle(color: gold, fontSize: 23, fontWeight: FontWeight.bold)),
  ]);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onToggleTheme});
  final VoidCallback? onToggleTheme;
  static const sections = [
    ('القرآن الكريم', 'تلاوة وتدبر وختمات', Icons.menu_book_rounded),
    ('الأذكار', 'ذكر يطمئن القلب', Icons.auto_awesome_rounded),
    ('الختمات الجماعية', 'معًا لختم القرآن', Icons.groups_rounded),
    ('مواقيت الصلاة', 'تنبيه بمواقيت الصلاة', Icons.access_time_rounded),
    ('السبحة', 'تسبيح وذكر ودعاء', Icons.favorite_border_rounded),
    ('فك كرب', 'مساعدة المحتاجين', Icons.volunteer_activism_rounded),
  ];

  void _showDua(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.volunteer_activism_rounded, size: 42, color: gold),
          const SizedBox(height: 12),
          const Text('دعوة من القلب', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('اللهم اغفر لعبدالوكيل عبدالسيد محمد وارحمه، وعافه واعف عنه، وأكرم نزله، ووسع مدخله، واجعل قبره روضة من رياض الجنة.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 18, height: 1.9)),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.favorite_rounded),
            label: const Text('اللهم آمين')),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? cream : const Color(0xFF163C32);
    final secondary = isDark ? muted : const Color(0xFF647A6E);
    final tile = isDark ? const Color(0xFF135145) : const Color(0xFFFFFCF3);
    final accent = isDark ? gold : const Color(0xFF94702F);
    return Scaffold(
      appBar: AppBar(
        title: Text('أثر لا ينقطع', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'دخول الإدارة',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen())),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            key: const ValueKey('settings-button'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AppSettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            key: const ValueKey('home-theme-toggle'),
            tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
            onPressed: onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, size) {
          // Account for the scroll view's 18px padding on both sides.
          final availableWidth = size.maxWidth - 36;
          final maxWidth = availableWidth > 650 ? 650.0 : availableWidth;
          final tileWidth = (maxWidth - 24) / 3;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Center(child: SizedBox(width: maxWidth, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight, end: Alignment.bottomLeft,
                      colors: [Color(0xFF176451), Color(0xFF06372F)]),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: gold.withValues(alpha: 0.72), width: 1.2),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
                      blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: Column(children: [
                    const Text('صَدَقَةٌ جَارِيَة', textAlign: TextAlign.center,
                      style: TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold, width: 1.4)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset('assets/images/father.jpg',
                            width: 94, height: 105, fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 94, height: 105,
                              child: Icon(Icons.person_outline, color: gold))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(children: [
                        Text('على روح المغفور له بإذن الله',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cream, fontSize: 13, height: 1.6)),
                        SizedBox(height: 7),
                        Text('عبدالوكيل عبدالسيد محمد',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: gold, fontSize: 16,
                            fontWeight: FontWeight.w900, height: 1.5)),
                        SizedBox(height: 10),
                        Text('اللهم اغفر له وارحمه\nوعافه واعف عنه وأكرم نزله\nووسع مدخله واجعل قبره روضة من رياض الجنة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cream, fontSize: 10.5, height: 1.45)),
                      ])),
                    ]),
                  ]),
                ),
                const SizedBox(height: 7),
                Text('أبواب الخير', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                LiveContentText(document: 'home', field: 'tagline', fallback: 'نورٌ يبقى، ودعاءٌ يصل.', style: TextStyle(color: secondary, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 12, runSpacing: 8, children: [
                  for (final s in sections)
                    SizedBox(
                      width: tileWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          if (s.$1 == 'القرآن الكريم') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QuranScreen()));
                          } else if (s.$1 == 'الختمات الجماعية') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const KhatmaScreen()));
                          } else if (s.$1 == 'الأذكار') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AzkarScreen()));
                          } else if (s.$1 == 'السبحة') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TasbeehScreen()));
                          } else if (s.$1 == 'فك كرب') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicCasesScreen()));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('قسم ${s.$1} قيد التطوير')));
                          }
                        },
                        child: Container(
                        constraints: const BoxConstraints(minHeight: 104),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
                            colors: [tile, isDark ? const Color(0xFF0C3B33) : const Color(0xFFF4EBD7)]),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.1),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.045),
                            blurRadius: 22, offset: const Offset(0, 11),
                          )],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 43, height: 43,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Icon(s.$3, color: accent, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(s.$1, textAlign: TextAlign.center,
                              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(height: 5),
                            Text(s.$2, textAlign: TextAlign.center,
                              style: TextStyle(color: secondary, fontSize: 10, height: 1.3)),
                          ],
                        ),
                      ),
                      ),
                    ),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    key: const ValueKey('pray-for-father-button'),
                    onPressed: () => _showDua(context),
                    icon: const Icon(Icons.favorite_border_rounded, size: 19),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('ادع له')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(
                    key: const ValueKey('contact-us-button'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ContactUsScreen())),
                    icon: const Icon(Icons.support_agent_outlined, size: 19),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('تواصل معنا')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      backgroundColor: accent,
                      foregroundColor: isDark ? const Color(0xFF103F35) : Colors.white,
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )),
                ]),
                const SizedBox(height: 18),
                Center(child: Text('اللهم اجعل هذا العمل نورًا ورحمةً له',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary, fontSize: 13, height: 1.6))),
              ],
            ))),
          );
        }),
      ),
    );
  }
}

class LiveContentText extends StatelessWidget {
  const LiveContentText({super.key, required this.document, required this.field,
    required this.fallback, this.style});
  final String document, field, fallback;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return Text(fallback, textAlign: TextAlign.center, style: style);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('content').doc(document).snapshots(),
    builder: (context, snapshot) {
      final data = snapshot.data?.data();
      final value = (data != null && data['published'] == true) ? data[field] : null;
      final display = value is String && value.trim().isNotEmpty ? value : fallback;
      return Text(display, textAlign: TextAlign.center, style: style);
    },
  );
  }
}

class ContactUsScreen extends StatelessWidget {
  static Future<void> _openWhatsApp(BuildContext context, String raw) async {
    final number = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.length < 10 || number.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('رقم واتساب غير صحيح. أضفه من الإدارة بكود الدولة، مثل 201xxxxxxxxx')));
      return;
    }
    final url = Uri.parse('https://wa.me/$number');
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز')));
      }
    }
  }

  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تواصل معنا')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('settings').doc('contact').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل وسائل التواصل'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        final channels = <(String, String, IconData)>[
          ('whatsapp', 'واتساب', Icons.chat_outlined),
          ('facebook', 'فيسبوك', Icons.facebook_outlined),
          ('messenger', 'ماسنجر', Icons.message_outlined),
          ('telegram', 'تليجرام', Icons.send_outlined),
        ];
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Icon(Icons.support_agent_outlined, size: 70, color: gold),
            const SizedBox(height: 16),
            const Text('وسائل التواصل الرسمية', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (data?['public'] != true ||
                !channels.any((channel) => (data?[channel.$1] ?? '').toString().trim().isNotEmpty))
              const Padding(padding: EdgeInsets.all(24),
                child: Text('سيتم إضافة وسائل التواصل قريبًا', textAlign: TextAlign.center)),
            if (data?['public'] == true)
              for (final channel in channels)
                if ((data?[channel.$1] ?? '').toString().trim().isNotEmpty)
                  Card(child: ListTile(
                    leading: Icon(channel.$3),
                    title: Text(channel.$2,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    subtitle: Text(data![channel.$1].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: channel.$1 == 'whatsapp'
                      ? const Icon(Icons.open_in_new_rounded) : null,
                    onTap: channel.$1 == 'whatsapp'
                      ? () => _openWhatsApp(context, data[channel.$1].toString())
                      : null,
                  )),
          ]),
        ));
      },
    ),
  );
}
