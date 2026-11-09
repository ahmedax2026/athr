import 'package:flutter/material.dart';

const _emerald = Color(0xFF075B4A);
const _gold = Color(0xFFB88A36);
const _ink = Color(0xFF202923);
const _paper = Color(0xFFF7F6F0);

void main() => runApp(const AthrApp());

class AthrApp extends StatelessWidget {
  const AthrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أثر لا ينقطع',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _emerald).copyWith(
          primary: _emerald,
          secondary: _gold,
          surface: _paper,
        ),
        scaffoldBackgroundColor: _paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          centerTitle: true,
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _count = 0;

  void _incrementTasbeeh() {
    if (_count >= 3) return;
    setState(() => _count++);
    if (_count != 3) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اللهم تقبل', textAlign: TextAlign.center),
        duration: Duration(milliseconds: 1100),
        backgroundColor: _emerald,
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1.55,
                      child: Image.asset(
                        'assets/images/father.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _MissingPortrait(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'صدقة جارية على روح عبدالوكيل عبدالسيد محمد',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _emerald,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'اللهم اغفر له وارحمه وعافه واعف عنه، وأكرم نزله ووسع مدخله',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, height: 1.8),
                  ),
                  const SizedBox(height: 24),
                  _TasbeehPanel(count: _count, onTap: _incrementTasbeeh),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.spa_outlined, color: _gold, size: 30),
        const SizedBox(height: 6),
        Text(
          'أثر لا ينقطع',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _emerald,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _MissingPortrait extends StatelessWidget {
  const _MissingPortrait();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9F0E9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_outlined, color: _emerald, size: 38),
          const SizedBox(height: 8),
          Text(
            'الصورة غير متاحة حاليًا',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _emerald,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TasbeehPanel extends StatelessWidget {
  const _TasbeehPanel({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E3D9)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'عدد التسبيحات',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$count/3',
            key: const ValueKey('tasbeeh-count'),
            style: const TextStyle(
              color: _emerald,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('welcome-pray-button'),
              onPressed: count < 3 ? onTap : null,
              icon: const Icon(Icons.favorite_border),
              label: const Text('اللهم ارحمه'),
              style: FilledButton.styleFrom(
                backgroundColor: _emerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _sections = [
    _HomeSectionData(
      title: 'القرآن الكريم',
      subtitle: 'آيات تتلى وأجر يبقى',
      icon: Icons.menu_book_outlined,
    ),
    _HomeSectionData(
      title: 'الأذكار',
      subtitle: 'ذكر يطمئن القلب',
      icon: Icons.auto_awesome_outlined,
    ),
    _HomeSectionData(
      title: 'السبحة',
      subtitle: 'مساحة للتسبيح والدعاء',
      icon: Icons.radio_button_checked_outlined,
    ),
    _HomeSectionData(
      title: 'مواقيت الصلاة',
      subtitle: 'تذكير بمواقيت الصلاة',
      icon: Icons.access_time,
    ),
    _HomeSectionData(
      title: 'الختمات الجماعية',
      subtitle: 'ختمة يجتمع عليها الأحبة',
      icon: Icons.groups_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أثر لا ينقطع')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620 ? 3 : 2;
            const spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'أهلًا بك',
                        style: TextStyle(
                          color: _emerald,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'نورٌ يبقى، ودعاءٌ يصل.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final section in _sections)
                            SizedBox(
                              width: itemWidth,
                              child: _HomeSectionTile(data: section),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeSectionData {
  const _HomeSectionData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _HomeSectionTile extends StatelessWidget {
  const _HomeSectionTile({required this.data});

  final _HomeSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E5DC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: _emerald, size: 25),
          const SizedBox(height: 10),
          Text(
            data.title,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: const TextStyle(color: Color(0xFF5F6B62), height: 1.4),
          ),
        ],
      ),
    );
  }
}