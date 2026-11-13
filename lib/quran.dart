import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'athr_mushaf_reader.dart';

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
  int? bookmark;
  static const List<int> juzStartPages = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        lastPage = (prefs.getInt('react_quran_last_page') ?? 1).clamp(1, 604);
        bookmark = prefs.getInt('react_quran_bookmark');
      });
    }
  }

  Future<void> _read(int page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AthrMushafReader(initialPage: page.clamp(1, 604))));
    if (mounted) await _refresh();
  }

  Future<void> _openBookmark() async {
    if (bookmark != null) {
      await _read(bookmark!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('افتح المصحف واضغط علامة الحفظ أولًا')));
    }
  }

  // The native QuranLibraryScreen provides its own surah/juz index.
  Future<void> _index() => _read(lastPage);
  Future<void> _juz() => _read(lastPage);

  Future<void> _pages() async {
    var selected = lastPage;
    final result = await showDialog<int>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('اختيار الصفحة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الصفحة $selected من 604'),
          Slider(min: 1, max: 604, divisions: 603,
            value: selected.toDouble(),
            onChanged: (value) => setLocal(() => selected = value.round())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('فتح')),
        ],
      )));
    if (result != null && mounted) await _read(result);
  }

  Widget _tile(IconData icon, String text, VoidCallback action) =>
    Material(color: Colors.transparent, child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF145C4B), Color(0xFF07362F)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withValues(alpha: .65)),
          boxShadow: const [BoxShadow(
            color: Color(0x44001510), blurRadius: 13, offset: Offset(0, 6))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: gold, size: 34),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: cream, fontSize: 17,
              fontWeight: FontWeight.w800))),
        ]),
      ),
    ));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF062F29),
    appBar: AppBar(backgroundColor: const Color(0xFF062F29),
      foregroundColor: cream, centerTitle: true,
      title: const Text('القرآن الكريم', style: TextStyle(
        fontSize: 25, color: gold, fontWeight: FontWeight.bold))),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B4439),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: gold.withValues(alpha: .55))),
            child: Column(children: [
              const Icon(Icons.auto_stories_rounded, size: 62, color: gold),
              const SizedBox(height: 7),
              const Text('المصحف العثماني', style: TextStyle(
                color: cream, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('قراءة وطمأنينة في كل صفحة',
                style: TextStyle(color: Color(0xFFCAD9D0), fontSize: 14)),
              const SizedBox(height: 15),
              FilledButton.icon(
                onPressed: () => _read(lastPage),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('افتح المصحف'),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF07372F),
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          const SizedBox(height: 17),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              _tile(Icons.menu_book_outlined, 'فهرس السور', _index),
              _tile(Icons.layers_rounded, 'الأجزاء', _juz),
              _tile(Icons.article_outlined, 'الصفحات', _pages),
              _tile(Icons.bookmark_outline, 'علاماتي', _openBookmark),
              _tile(Icons.history, 'آخر قراءة', () => _read(lastPage)),
              _tile(Icons.auto_stories_rounded, 'المصحف', () => _read(lastPage)),
            ],
          ),
          const SizedBox(height: 17),
          Material(color: Colors.transparent, child: InkWell(
            onTap: () => _read(lastPage),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF135747), Color(0xFF08352C)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold, width: 1)),
              child: Row(children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: gold),
                  padding: const EdgeInsets.all(11),
                  child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFF06352C), size: 29)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment:
                  CrossAxisAlignment.start, children: [
                  const Text('متابعة القراءة', style: TextStyle(
                    color: gold, fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('الصفحة $lastPage من 604',
                    style: const TextStyle(color: cream, fontSize: 17)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: lastPage / 604,
                    color: gold,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.white24),
                ])),
              ]),
            ),
          )),
        ]),
    ))),
  );
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
              builder: (_) => AthrMushafReader(
                initialPage: page,
                firstPage: page,
                lastPage: index == 29 ? 604 : _QuranScreenState.juzStartPages[index + 1] - 1))),
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
      return AthrMushafReader(initialPage: entry['page'] as int);
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
