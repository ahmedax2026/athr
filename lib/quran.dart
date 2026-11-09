import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_reader.dart';
import 'interactive_quran_reader.dart';

const emerald = Color(0xFF003D30);
const gold = Color(0xFFBE9442);
const cream = Color(0xFFFFF8E6);

class QuranService {
  static Future<List<dynamic>> fetchAll() async {
    final chapters = jsonDecode(await rootBundle.loadString('assets/quran/quran.json')) as List<dynamic>;
    if (chapters.length != 114 ||
        chapters.fold<int>(0, (sum, item) => sum + (item['ayahs'] as List).length) != 6236) {
      throw const FormatException('بيانات المصحف غير مكتملة');
    }
    return chapters;
  }
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int lastPage = 1;
  late final Future<List<dynamic>> chapters = QuranService.fetchAll();
  @override
  void initState() { super.initState(); _refresh(); }
  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => lastPage = prefs.getInt('mushaf_last_page') ?? 1);
  }
  Future<void> _read(int page) async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => MushafPageReader(initialPage: page)));
    _refresh();
  }
  void _index() => Navigator.push(context, MaterialPageRoute<void>(
    builder: (_) => const QuranIndexScreen()));
  void _pages() async {
    final choice = await showDialog<int>(context: context, builder: (context) {
      int value = lastPage;
      return StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('اختر صفحة المصحف'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الصفحة $value من 604'),
          Slider(min: 1, max: 604, divisions: 603, value: value.toDouble(),
            onChanged: (v) => setLocal(() => value = v.round())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, value), child: const Text('فتح')),
        ],
      ));
    });
    if (choice != null) _read(choice);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: emerald,
    body: SafeArea(child: FutureBuilder<List<dynamic>>(
      future: chapters, builder: (context, snapshot) {
        return Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF002D27), Color(0xFF075742), Color(0xFF00372C)])),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 26), children: [
              const QuranOrnament(),
              const SizedBox(height: 4),
              const Text('الْقُرْآنُ الْكَرِيمُ', textAlign: TextAlign.center,
                style: TextStyle(color: cream, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 170, child: Stack(alignment: Alignment.center, children: [
                Container(width: 240, height: 150, decoration: BoxDecoration(
                  shape: BoxShape.circle, boxShadow: [BoxShadow(
                    color: gold.withValues(alpha: .22), blurRadius: 70, spreadRadius: 25)])),
                const Icon(Icons.auto_stories_rounded, color: Color(0xFFF7D78C), size: 154),
                const Positioned(bottom: 0, child: Icon(Icons.keyboard_double_arrow_up_rounded,
                  color: gold, size: 42)),
              ])),
              const SizedBox(height: 24),
              TextField(readOnly: true, onTap: _index,
                decoration: InputDecoration(
                  hintText: 'ابحث عن سورة...',
                  suffixIcon: const Icon(Icons.search, size: 30, color: Colors.black),
                  filled: true, fillColor: const Color(0xFFFFFCF4),
                  contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(35),
                    borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3, crossAxisSpacing: 9, mainAxisSpacing: 14,
                childAspectRatio: .96,
                children: [
                  _shortcut(Icons.menu_book_rounded, 'فهرس السور', _index),
                  _shortcut(Icons.layers_rounded, 'الأجزاء', _pages),
                  _shortcut(Icons.bookmark_outline_rounded, 'الأحزاب', _pages),
                  _shortcut(Icons.star_border_rounded, 'علاماتي', () => _read(lastPage)),
                  _shortcut(Icons.access_time_rounded, 'آخر قراءة', () => _read(lastPage)),
                  _shortcut(Icons.article_outlined, 'الصفحات', _pages),
                ]),
              const SizedBox(height: 26),
              InkWell(onTap: () => _read(lastPage), borderRadius: BorderRadius.circular(20),
                child: _IvoryPanel(child: Row(children: [
                  CircleAvatar(radius: 27, backgroundColor: gold,
                    child: const Icon(Icons.play_arrow_rounded, color: cream, size: 35)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('متابعة القراءة', style: TextStyle(fontSize: 23,
                      fontWeight: FontWeight.bold, color: Color(0xFF18201C))),
                    const SizedBox(height: 7),
                    Text('الصفحة $lastPage من 604',
                      style: const TextStyle(fontSize: 19, color: Color(0xFF30302B))),
                  ])),
                ]))),
            ]))),
        );
      },
    )),
  );

  Widget _shortcut(IconData icon, String title, VoidCallback action) =>
    InkWell(onTap: action, borderRadius: BorderRadius.circular(19),
      child: Container(decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFDF2), Color(0xFFF5E9CA)]),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFD8BE79))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF896B21), size: 38),
          const SizedBox(height: 11),
          FittedBox(fit: BoxFit.scaleDown, child: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        ])));
}

class QuranOrnament extends StatelessWidget {
  const QuranOrnament({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: 80,
    child: CustomPaint(painter: _ArchPainter()));
}

class _ArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.7;
    final faint = Paint()..color = gold.withValues(alpha: .38)
      ..style = PaintingStyle.stroke..strokeWidth = .8;
    final w = size.width, h = size.height;
    final arch = Path()
      ..moveTo(0, 2)..lineTo(w, 2)..lineTo(w, 21)
      ..quadraticBezierTo(w*.86, 17, w*.78, 37)
      ..quadraticBezierTo(w*.69, 54, w*.62, 37)
      ..quadraticBezierTo(w*.5, 14, w*.38, 37)
      ..quadraticBezierTo(w*.31, 54, w*.22, 37)
      ..quadraticBezierTo(w*.14, 17, 0, 21)..close();
    canvas.drawPath(arch, line);
    for (var x = 8.0; x < w; x += 22) {
      canvas.drawLine(Offset(x, 2), Offset(x + 15, 22), faint);
      canvas.drawLine(Offset(x + 15, 2), Offset(x, 22), faint);
    }
    for (final x in [w*.14,w*.86]) {
      canvas.drawLine(Offset(x, 19), Offset(x, 56), line);
      canvas.drawCircle(Offset(x, 60), 3, line);
    }
    final rays = Paint()..color = const Color(0x33FFE3A0)
      ..strokeWidth = 2..style = PaintingStyle.stroke;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(Offset(w/2, 0), Offset(w/2 + i*28, h), rays);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SurahRosette extends StatelessWidget {
  const _SurahRosette({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => SizedBox(width: 58, height: 58,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(58,58), painter: _RosettePainter()),
      Text('$number', style: const TextStyle(fontSize: 20,
        fontWeight: FontWeight.bold, color: Color(0xFF29261C))),
    ]));
}

class _RosettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final paint = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 1.6;
    for (final (radius, offset) in [(26.0, 0.0), (23.0, math.pi/8)]) {
      final path = Path();
      for (var i=0; i<16; i++) {
        final a = i*math.pi/8+offset;
        final r = i.isEven ? radius : radius*.84;
        final point = Offset(center.dx+math.cos(a)*r, center.dy+math.sin(a)*r);
        if (i==0) { path.moveTo(point.dx,point.dy); }
        else { path.lineTo(point.dx,point.dy); }
      }
      canvas.drawPath(path..close(), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IvoryPanel extends StatelessWidget {
  const _IvoryPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFFDF4), Color(0xFFF6EACD)]),
      border: Border.all(color: gold, width: 1.4),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10)]),
    child: child);
}

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});
  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> {
  int tab = 0;
  String search = '';
  late final Future<List<dynamic>> chapters = QuranService.fetchAll();
  late final Future<List<dynamic>> pageIndex = rootBundle
    .loadString('assets/mushaf/surah_pages.json').then((v) => jsonDecode(v) as List<dynamic>);
  Future<void> _open(int number, List<dynamic> index) async {
    final entry = index.firstWhere((s) => s['number'] == number);
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => InteractiveQuranReader(surahNumber: number)));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: emerald,
    appBar: AppBar(backgroundColor: emerald, foregroundColor: cream,
      centerTitle: true, title: const Text('فهرس السور',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
    body: FutureBuilder<List<dynamic>>(future: chapters, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: gold));
      return FutureBuilder<List<dynamic>>(future: pageIndex, builder: (context, pages) {
        if (!pages.hasData) return const Center(child: CircularProgressIndicator(color: gold));
        final all = snapshot.data!;
        final filtered = all.where((s) {
          final number = s['number'] as int;
          final isMadani = const [2,3,4,5,8,9,13,22,24,33,47,48,49,55,57,58,59,60,61,62,63,64,65,66,76,98,99,110].contains(number);
          return (tab == 0 || (tab == 2) == isMadani) &&
            (s['name'].toString().contains(search) || number.toString() == search);
        }).toList();
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
          child: Column(children: [
            const QuranOrnament(),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                for (final (index, label) in ['الكل','مكية','مدنية'].indexed)
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(onTap: () => setState(() => tab = index),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: tab == index ? emerald : cream,
                          border: Border.all(color: gold, width: 1.5),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(label, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: tab == index ? gold : Colors.black)))))),
              ])),
            Padding(padding: const EdgeInsets.all(10),
              child: TextField(onChanged: (v) => setState(() => search = v.trim()),
                decoration: InputDecoration(hintText: 'ابحث عن سورة',
                  prefixIcon: const Icon(Icons.search), filled: true, fillColor: cream,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))))),
            Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: filtered.length, itemBuilder: (context, i) {
                final s = filtered[i], n = s['number'] as int;
                final isMadani = const [2,3,4,5,8,9,13,22,24,33,47,48,49,55,57,58,59,60,61,62,63,64,65,66,76,98,99,110].contains(n);
                return Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(onTap: () => _open(n, pages.data!),
                    child: _IvoryPanel(child: Row(children: [
                      const Icon(Icons.volume_up_outlined, color: Color(0xFF8B6C24), size: 28),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('سورة ${s['name']}', style: const TextStyle(fontSize: 23,
                          fontWeight: FontWeight.bold)),
                        Text('${(s['ayahs'] as List).length} آية • ${isMadani ? 'مدنية' : 'مكية'}',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF5B5447))),
                      ])),
                      const SizedBox(width: 14),
                      _SurahRosette(number: n),
                    ]))));
              })),
          ])));
      });
    }),
  );
}

// Compatibility for existing navigation paths.
class QuranSurahScreen extends StatelessWidget {
  const QuranSurahScreen({super.key, required this.number, required this.name, this.initialAyah});
  final int number;
  final String name;
  final int? initialAyah;
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: rootBundle.loadString('assets/mushaf/surah_pages.json'),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final index = jsonDecode(snapshot.data!) as List<dynamic>;
      final page = (index.firstWhere((s) => s['number'] == number)['page'] as int);
      return InteractiveQuranReader(surahNumber: number);
    });
}
