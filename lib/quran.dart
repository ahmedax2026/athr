import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_reader.dart';
import 'react_quran_preview.dart';

const emerald = Color(0xFF003D30);
const gold = Color(0xFFFFD77A);
const cream = Color(0xFFFFF8E6);
const darkInk = Color(0xFF17251E);

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
    if (mounted) setState(() => lastPage = prefs.getInt('react_quran_last_page') ?? 1);
  }
  Future<void> _read(int page) async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => ReactQuranPreview(initialPage: page)));
    _refresh();
  }
  Future<void> _openBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final mark = prefs.getInt('react_quran_bookmark');
    if (!mounted) return;
    if (mark == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('افتح المصحف واضغط علامة الحفظ أولًا')));
      return;
    }
    await _read(mark);
  }
  void _tajweed() => _index();
  void _index() => Navigator.push(context, MaterialPageRoute<void>(
    builder: (_) => const QuranIndexScreen()));
  // Starting pages of the 30 juz in the 604-page Madinah Mushaf.
  static const List<int> juzStartPages = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  void _juz() {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => const QuranJuzScreen()));
  }
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
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(
                      builder: (_) => const QuranIndexScreen())),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('المصحف العثماني الجديد'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: gold,
                    side: const BorderSide(color: gold),
                    minimumSize: const Size.fromHeight(46)),
                ),
              ),
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
                  _shortcut(Icons.color_lens_outlined, 'المصحف العثماني', _tajweed),
                  _shortcut(Icons.menu_book_rounded, 'فهرس السور', _index),
                  _shortcut(Icons.layers_rounded, 'الأجزاء', _juz),
                  _shortcut(Icons.star_border_rounded, 'علاماتي', _openBookmark),
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
            style: const TextStyle(fontSize: 17, color: darkInk, fontWeight: FontWeight.w800))),
        ])));
}

class QuranJuzScreen extends StatelessWidget {
  const QuranJuzScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: emerald,
    appBar: AppBar(
      backgroundColor: emerald, foregroundColor: cream, centerTitle: true,
      title: const Text('أجزاء القرآن الكريم',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
    body: ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _QuranScreenState.juzStartPages.length,
      itemBuilder: (context, index) {
        final page = _QuranScreenState.juzStartPages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => ReactQuranPreview(initialPage: page))),
            child: _IvoryPanel(child: Row(children: [
              CircleAvatar(backgroundColor: emerald,
                child: Text('${index + 1}', style: const TextStyle(
                  color: cream, fontWeight: FontWeight.w900))),
              const SizedBox(width: 14),
              Expanded(child: Text('الجزء ${index + 1}',
                style: const TextStyle(fontSize: 21,
                  color: darkInk, fontWeight: FontWeight.w900))),
              Text('صفحة $page', style: const TextStyle(
                fontSize: 15, color: darkInk, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left, color: darkInk),
            ])),
          ),
        );
      },
    ),
  );
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
    final faint = Paint()..color = gold.withValues(alpha: .65)
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
      Text('$number', style: const TextStyle(fontSize: 22,
        fontWeight: FontWeight.w900, color: Color(0xFF111A14))),
    ]));
}

class _RosettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final paint = Paint()..color = const Color(0xFF735315)..style = PaintingStyle.stroke..strokeWidth = 2.2;
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
      gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFF4D8)]),
      border: Border.all(color: const Color(0xFF9C7226), width: 1.8),
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
    final entry = index.cast<Map<String, dynamic>>().firstWhere(
      (item) => item['number'] == number);
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => ReactQuranPreview(initialPage: entry['page'] as int)));
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                            color: tab == index ? const Color(0xFFFFFFFF) : darkInk)))))),
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
                      const Icon(Icons.volume_up_outlined, color: Color(0xFF56400C), size: 28),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('سورة ${s['name']}', style: const TextStyle(fontSize: 23,
                          color: darkInk, fontWeight: FontWeight.w800)),
                        Text('${(s['ayahs'] as List).length} آية • ${isMadani ? 'مدنية' : 'مكية'}',
                          style: const TextStyle(fontSize: 16, color: Color(0xFF36352E))),
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
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final entries = jsonDecode(snapshot.data!) as List<dynamic>;
      final entry = entries.firstWhere((item) => item['number'] == number);
      return MushafPageReader(initialPage: entry['page'] as int);
    });
}


/// Offline trial of a second, text-based Quran reading mode.
/// The verse text comes exclusively from the bundled Quran JSON.
/// Tajweed rule coloring is deliberately not claimed until verified data is integrated.
class TajweedTrialScreen extends StatefulWidget {
  const TajweedTrialScreen({super.key});
  @override
  State<TajweedTrialScreen> createState() => _TajweedTrialScreenState();
}

class _TajweedTrialScreenState extends State<TajweedTrialScreen> {
  late final Future<List<dynamic>> chapters = QuranService.fetchAll();
  int selected = 0;
  double fontSize = 29;

  String verseText(dynamic verse) {
    if (verse is String) return verse;
    if (verse is Map) {
      for (final key in ['text', 'text_uthmani', 'arabic', 'content']) {
        final value = verse[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8E8),
    appBar: AppBar(
      backgroundColor: emerald,
      foregroundColor: cream,
      title: const Text('القرآن الكريم • قراءة متصلة'),
      actions: [
        IconButton(
          tooltip: 'تصغير الخط',
          onPressed: () => setState(() => fontSize = (fontSize - 2).clamp(22, 48)),
          icon: const Icon(Icons.text_decrease)),
        IconButton(
          tooltip: 'تكبير الخط',
          onPressed: () => setState(() => fontSize = (fontSize + 2).clamp(22, 48)),
          icon: const Icon(Icons.text_increase)),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: chapters,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل بيانات القرآن المحلية'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final surah = all[selected] as Map;
        final verses = surah['ayahs'] as List;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: DropdownButtonFormField<int>(
              key: ValueKey(selected),
              initialValue: selected,
              decoration: InputDecoration(
                labelText: 'اختر السورة',
                labelStyle: const TextStyle(color: darkInk),
                floatingLabelStyle: const TextStyle(color: emerald),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14))),
              isExpanded: true,
              items: [
                for (var i = 0; i < all.length; i++)
                  DropdownMenuItem(value: i,
                    child: Text('${i + 1} - ${all[i]['name']}')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => selected = value);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Text('قراءة متصلة بخط مكبّر — ألوان أحكام التجويد لم تُفعّل بعد',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF805C22), fontSize: 12)),
          ),
          Expanded(child: ListView(
            key: ValueKey('tajweed-surah-$selected'),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B503D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: gold)),
                child: Text('سورة ${surah['name']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25, fontWeight: FontWeight.w800, color: cream)),
              ),
              const SizedBox(height: 16),
              if (selected != 0 && selected != 8)
                const Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, color: darkInk, height: 2)),
              const SizedBox(height: 12),
              // A single paragraph allows verses to flow naturally on the same line.
              // Verse-end ornaments are inline spans rather than separate blocks.
              Text.rich(
                TextSpan(children: [
                  for (var i = 0; i < verses.length; i++)
                    if (verseText(verses[i]).isNotEmpty) ...[
                      TextSpan(text: '${verseText(verses[i]).trim()} '),
                      TextSpan(
                        text: '۞${i + 1} ',
                        style: TextStyle(
                          fontSize: fontSize * .66,
                          color: const Color(0xFF926A26),
                          fontWeight: FontWeight.w700)),
                    ],
                ]),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                softWrap: true,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.7,
                  color: darkInk),
              ),
            ],
          )),
        ]);
      },
    ),
  );
}
