import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admin_and_cases.dart';
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
        content: Text('اللهم تقبل', textAlign: TextAlign.center),
        duration: Duration(milliseconds: 1100),
        backgroundColor: emerald,
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
                const Text('أَثَرٌ لَا يَنْقَطِع', style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('ذِكرى طيبة، ودعاء لا ينقطع', style: TextStyle(color: muted, fontSize: 13)),
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
                const Text('عبدالوكيل عبدالسيد محمد', textAlign: TextAlign.center, style: TextStyle(color: gold, fontSize: 25, fontWeight: FontWeight.w800, height: 1.5)),
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
                    Text('اللهم اغفر له وارحمه وعافه واعف عنه، وأكرم نزله ووسع مدخله', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 15, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 8),
                _PrayerHeart(count: _count, onTap: _pray),
                const SizedBox(height: 8),
                const Text('اضغط على القلب ثلاث مرات وادعُ له بالرحمة', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
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
    ('القرآن الكريم', 'آيات تتلى وأجر يبقى', Icons.menu_book_outlined),
    ('الأذكار', 'ذكر يطمئن القلب', Icons.auto_awesome_outlined),
    ('السبحة', 'مساحة للتسبيح والدعاء', Icons.favorite_outline),
    ('مواقيت الصلاة', 'تذكير بمواقيت الصلاة', Icons.access_time),
    ('الختمات الجماعية', 'ختمة يجتمع عليها الأحبة', Icons.groups_outlined),
    ('فك كرب', 'أدعية لتفريج الهموم', Icons.volunteer_activism_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? cream : const Color(0xFF163C32);
    final secondary = isDark ? muted : const Color(0xFF647A6E);
    final tile = isDark ? const Color(0xFF10473D) : Colors.white;
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
          final maxWidth = size.maxWidth > 650 ? 650.0 : size.maxWidth;
          final tileWidth = (maxWidth - 52) / 2;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Center(child: SizedBox(width: maxWidth, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF176451), Color(0xFF06372F)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: gold.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.09),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: gold),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/father.jpg',
                          width: 80, height: 94, fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            style: TextStyle(color: gold, fontSize: 13)),
                        SizedBox(height: 8),
                        Text('أهلًا بك في أثر لا ينقطع',
                            style: TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.w800, height: 1.5)),
                        SizedBox(height: 5),
                        Text('صدقة جارية على روح عبدالوكيل عبدالسيد محمد',
                            style: TextStyle(color: Color(0xFFE4E9D9), fontSize: 12, height: 1.6)),
                      ],
                    )),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('أبواب الخير', style: TextStyle(color: fg, fontSize: 25, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('نورٌ يبقى، ودعاءٌ يصل.', style: TextStyle(color: secondary, fontSize: 14)),
                const SizedBox(height: 17),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final s in sections)
                    SizedBox(
                      width: tileWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          if (s.$1 == 'فك كرب') {
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PublicCasesScreen()));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('قسم ${s.$1} قيد التطوير')));
                          }
                        },
                        child: Container(
                        constraints: const BoxConstraints(minHeight: 160),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tile,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: accent.withValues(alpha: 0.28)),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.045),
                            blurRadius: 14, offset: const Offset(0, 5),
                          )],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(s.$3, color: accent, size: 27),
                            ),
                            const SizedBox(height: 13),
                            Text(s.$1, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 7),
                            Text(s.$2, style: TextStyle(color: secondary, fontSize: 12, height: 1.5)),
                          ],
                        ),
                      ),
                      ),
                    ),
                ]),
                const SizedBox(height: 25),
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
