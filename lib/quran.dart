import 'dart:convert';
import 'mushaf_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranService {
  static Future<List<dynamic>> fetchAll() async {
    final json = jsonDecode(await rootBundle.loadString('assets/quran/quran.json'));
    final chapters = json as List<dynamic>;
    if (chapters.length != 114 ||
        chapters.fold<int>(0, (sum, item) => sum + (item['ayahs'] as List).length) != 6236) {
      throw const FormatException('بيانات المصحف غير مكتملة');
    }
    return chapters;
  }
}

const _forest = Color(0xFF063F32);
const _gold = Color(0xFFC5A052);
const _ivory = Color(0xFFFFF8E7);

class _GoldFrame extends StatelessWidget {
  const _GoldFrame({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _ivory,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _gold.withValues(alpha: .65), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x23000000), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: child,
  );
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late final Future<List<dynamic>> surahs = QuranService.fetchAll();
  String search = '';
  int? lastSurah;
  int? lastAyah;
  int? lastPage;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
      lastSurah = prefs.getInt('quran_last_surah');
      lastAyah = prefs.getInt('quran_last_ayah');
      lastPage = prefs.getInt('mushaf_last_page');
      });
    }
  }

  void openSurah(int number, String name, {int? scrollTo}) async {
    final index = jsonDecode(await rootBundle.loadString('assets/mushaf/surah_pages.json')) as List<dynamic>;
    final entry = index.firstWhere((s) => s['number'] == number);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MushafPageReader(initialPage: entry['page'] as int)));
    loadProgress();

  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _forest,
    appBar: AppBar(backgroundColor: _forest, foregroundColor: _ivory,
      centerTitle: true, title: const Text('القرآن الكريم', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
    body: FutureBuilder<List<dynamic>>(future: surahs, builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Text('تعذر فتح المصحف', style: TextStyle(color: _ivory)));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _gold));
      final all = snapshot.data!;
      final filtered = all.where((s) => (s['name'] as String).contains(search) ||
        (s['number'] as int).toString() == search).toList();
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 32), children: [
          Container(height: 160, decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 1.5),
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF075743), _forest]),
          ), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_stories_rounded, color: _gold, size: 64),
            SizedBox(height: 10),
            Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(color: _ivory, fontSize: 24)),
            Text('مصحفك معك في كل مكان', style: TextStyle(color: _gold)),
          ])),
          const SizedBox(height: 18),
          TextField(style: const TextStyle(color: _forest),
            onChanged: (v) => setState(() => search = v.trim()),
            decoration: InputDecoration(filled: true, fillColor: _ivory,
              hintText: 'ابحث عن سورة...', suffixIcon: const Icon(Icons.search, color: _forest),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))),
          const SizedBox(height: 18),
          if (lastPage != null && lastPage! >= 1 && lastPage! <= 604) ...[
            InkWell(onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MushafPageReader(initialPage: lastPage!)));
              loadProgress();
            },
              child: _GoldFrame(child: Row(children: [
                const CircleAvatar(backgroundColor: _forest,
                  child: Icon(Icons.play_arrow_rounded, color: _gold)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('متابعة القراءة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('الصفحة $lastPage من 604'),
                ])),
                const Icon(Icons.bookmark_rounded, color: _gold),
              ]))),
            const SizedBox(height: 18),
          ],
          const Text('فهرس السور', textAlign: TextAlign.center,
            style: TextStyle(color: _ivory, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final item in filtered)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(borderRadius: BorderRadius.circular(22),
                onTap: () => openSurah(item['number'] as int, item['name'].toString()),
                child: _GoldFrame(child: Row(children: [
                  Container(width: 48, height: 48, alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: _gold, width: 2)),
                    child: Text('${item['number']}', style: const TextStyle(
                      color: _forest, fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['name'].toString(), style: const TextStyle(
                      fontSize: 21, color: _forest, fontWeight: FontWeight.bold)),
                    Text('${(item['ayahs'] as List).length} آية', style: const TextStyle(color: Color(0xFF746B58))),
                  ])),
                  const Icon(Icons.menu_book_rounded, color: _gold),
                ]))),
              )),
        ])));
    }),
  );
}

class QuranSurahScreen extends StatefulWidget {
  const QuranSurahScreen({super.key, required this.number, required this.name, this.initialAyah});
  final int number;
  final String name;
  final int? initialAyah;
  @override
  State<QuranSurahScreen> createState() => _QuranSurahScreenState();
}

String _arabicDigits(int value) => value.toString().replaceAllMapped(RegExp(r'[0-9]'),
  (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m.group(0)!)]);

class _QuranSurahScreenState extends State<QuranSurahScreen> {
  late final Future<Map<String, dynamic>> surah = QuranService.fetchAll()
    .then((value) => value[widget.number - 1] as Map<String, dynamic>);
  final ScrollController scroll = ScrollController();
  double fontSize = 25;
  int? selectedAyah;

  @override
  void initState() {
    super.initState();
    selectedAyah = widget.initialAyah;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> bookmark(int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_surah', widget.number);
    await prefs.setInt('quran_last_ayah', ayah);
    if (mounted) {
      setState(() => selectedAyah = ayah);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ موضع القراءة عند الآية $ayah')));
    }
  }

  bool night = false;
  bool showControls = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: night ? const Color(0xFF102A25) : _ivory,
    appBar: AppBar(backgroundColor: _forest, foregroundColor: _ivory,
      centerTitle: true, title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(tooltip: 'الوضع الليلي', icon: Icon(night ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => setState(() => night = !night)),
        IconButton(tooltip: 'حجم الخط', icon: const Icon(Icons.text_fields),
          onPressed: () => setState(() => showControls = !showControls)),
      ]),
    body: FutureBuilder<Map<String, dynamic>>(future: surah, builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Text('تعذر فتح السورة'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _gold));
      final ayahs = snapshot.data!['ayahs'] as List<dynamic>;
      final ink = night ? _ivory : const Color(0xFF17231E);
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 750),
        child: Column(children: [
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(14), children: [
            Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _gold, width: 1.4),
                borderRadius: BorderRadius.circular(20),
                color: night ? const Color(0xFF17392F) : const Color(0xFFFFFCF2)),
              child: Column(children: [
                Text('۞ ${widget.name} ۞', textAlign: TextAlign.center,
                  style: TextStyle(color: night ? _gold : _forest, fontSize: 28, fontWeight: FontWeight.bold)),
                if (widget.number != 1 && widget.number != 9)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: fontSize))),
                const Divider(color: _gold),
                Directionality(textDirection: TextDirection.rtl,
                  child: Text.rich(TextSpan(children: [
                    for (var i = 0; i < ayahs.length; i++) ...[
                      TextSpan(text: '${ayahs[i]} ',
                        style: TextStyle(backgroundColor: selectedAyah == i + 1
                          ? _gold.withValues(alpha: .25) : null)),
                      TextSpan(
                        text: ' ﴿${_arabicDigits(i + 1)}﴾ ',
                        style: TextStyle(
                          color: night ? _gold : _forest,
                          fontSize: fontSize * .78,
                          fontWeight: FontWeight.w700,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = () => bookmark(i + 1),
                      ),
                      const TextSpan(text: '  '),
                    ],
                  ]), textAlign: TextAlign.justify,
                    style: TextStyle(fontSize: fontSize, height: 2.15, color: ink))),
              ])),
          ])),
          if (showControls) Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: night ? const Color(0xFF17392F) : _ivory,
              border: const Border(top: BorderSide(color: _gold))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(tooltip: 'تصغير الخط', onPressed: fontSize <= 20 ? null :
                  () => setState(() => fontSize -= 2), icon: Icon(Icons.text_decrease, color: ink)),
                Text('حجم الخط', style: TextStyle(color: ink)),
                IconButton(tooltip: 'تكبير الخط', onPressed: fontSize >= 37 ? null :
                  () => setState(() => fontSize += 2), icon: Icon(Icons.text_increase, color: ink)),
                IconButton(tooltip: 'حفظ آخر آية', onPressed: () => bookmark(selectedAyah ?? 1),
                  icon: const Icon(Icons.bookmark_rounded, color: _gold)),
              ]),
              Text('اضغط على رقم الآية لحفظ موضع القراءة',
                style: TextStyle(color: ink.withValues(alpha: .7), fontSize: 12)),
            ]),
          ),
        ])));
    }),
  );
}
