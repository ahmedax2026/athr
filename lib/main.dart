import 'package:flutter/material.dart';

const emerald = Color(0xFF073E35);
const deep = Color(0xFF052B27);
const gold = Color(0xFFD6B56C);
const cream = Color(0xFFF5EBD5);
const muted = Color(0xFFB9C9BD);

void main() => runApp(const AthrApp());

class AthrApp extends StatelessWidget {
  const AthrApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'أثر لا ينقطع',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: deep,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald, brightness: Brightness.dark).copyWith(primary: gold, surface: emerald),
      appBarTheme: const AppBarTheme(backgroundColor: deep, foregroundColor: cream, centerTitle: true),
    ),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const WelcomeScreen(),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
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
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [emerald, deep, Color(0xFF021C1A)])),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              child: Column(children: [
                const Icon(Icons.auto_awesome, color: gold, size: 23),
                const SizedBox(height: 8),
                const Text('أَثَرٌ لَا يَنْقَطِع', style: TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('ذِكرى طيبة، ودعاء لا ينقطع', style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 22),
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
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10473D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: gold.withValues(alpha: 0.35)),
                  ),
                  child: const Column(children: [
                    Icon(Icons.menu_book_outlined, color: gold, size: 22),
                    SizedBox(height: 8),
                    Text('اللهم اغفر له وارحمه وعافه واعف عنه، وأكرم نزله ووسع مدخله', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 17, height: 1.85)),
                  ]),
                ),
                const SizedBox(height: 20),
                _PrayerHeart(count: _count, onTap: _pray),
                const SizedBox(height: 8),
                const Text('اضغط على القلب ثلاث مرات وادعُ له بالرحمة', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
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
          width: 200,
          height: 180,
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.favorite, size: 180, color: Color(0xFFB68B4E)),
            const Icon(Icons.favorite, size: 165, color: Color(0xFF17584A)),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('اللهم ارحمه\nواغفر له', textAlign: TextAlign.center, style: TextStyle(color: cream, fontSize: 19, fontWeight: FontWeight.w800, height: 1.5)),
            ),
          ]),
        ),
      ),
    ),
    Text('$count/3', key: const ValueKey('tasbeeh-count'), style: const TextStyle(color: gold, fontSize: 23, fontWeight: FontWeight.bold)),
  ]);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const sections = [
    ('القرآن الكريم', 'آيات تتلى وأجر يبقى', Icons.menu_book_outlined),
    ('الأذكار', 'ذكر يطمئن القلب', Icons.auto_awesome_outlined),
    ('السبحة', 'مساحة للتسبيح والدعاء', Icons.favorite_outline),
    ('مواقيت الصلاة', 'تذكير بمواقيت الصلاة', Icons.access_time),
    ('الختمات الجماعية', 'ختمة يجتمع عليها الأحبة', Icons.groups_outlined),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أثر لا ينقطع', style: TextStyle(color: gold, fontWeight: FontWeight.bold))),
    body: SafeArea(
      child: LayoutBuilder(builder: (context, size) {
        final maxWidth = size.maxWidth > 650 ? 650.0 : size.maxWidth;
        final tileWidth = (maxWidth - 52) / 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Center(child: SizedBox(width: maxWidth, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF176451), emerald]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: gold.withValues(alpha: 0.55)),
              ),
              child: Row(children: [
                ClipOval(child: Image.asset('assets/images/father.jpg', width: 70, height: 70, fit: BoxFit.contain)),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('أهلًا بك', style: TextStyle(color: gold, fontSize: 23, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('صدقة جارية على روح عبدالوكيل عبدالسيد محمد', style: TextStyle(color: cream, height: 1.5, fontSize: 13)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('أبواب الخير', style: TextStyle(color: gold, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('نورٌ يبقى، ودعاءٌ يصل.', style: TextStyle(color: muted, fontSize: 14)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final s in sections)
                SizedBox(width: tileWidth, child: Container(
                  constraints: const BoxConstraints(minHeight: 148),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10473D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(s.$3, color: gold, size: 30),
                    const SizedBox(height: 13),
                    Text(s.$1, style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(s.$2, style: const TextStyle(color: muted, fontSize: 12, height: 1.5)),
                  ]),
                )),
            ]),
          ]))),
        );
      }),
    ),
  );
}
