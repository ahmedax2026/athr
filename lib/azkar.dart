import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'athr_qcf_mushaf_reader.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _paper = Color(0xFFF1E3C6);

class Dhikr {
  const Dhikr(this.text, this.target, this.source);
  final String text;
  final int target;
  final String source;
}
const _groups = <String, List<Dhikr>>{
  'أذكار الصباح': [
    Dhikr('آيَةُ الْكُرْسِيِّ: اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ', 1, 'سورة البقرة: 255'),
    Dhikr('قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ', 3, 'سورة الإخلاص'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ', 3, 'سورة الفلق'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ', 3, 'سورة الناس'),
    Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100, 'صحيح مسلم'),
    Dhikr('رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ\nصَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ\nنَبِيًّا وَرَسُولًا', 3, 'أبو داود والترمذي'),
  ],
  'أذكار المساء': [
    Dhikr('قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ', 3, 'سورة الإخلاص'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ', 3, 'سورة الفلق'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ', 3, 'سورة الناس'),
    Dhikr('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ', 3, 'صحيح مسلم'),
    Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100, 'صحيح مسلم'),
  ],
  'أذكار بعد الصلاة': [
    Dhikr('أَسْتَغْفِرُ اللَّهَ', 3, 'صحيح مسلم'),
    Dhikr('اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ', 1, 'صحيح مسلم'),
    Dhikr('سُبْحَانَ اللَّهِ', 33, 'الصحيحان'),
    Dhikr('الْحَمْدُ لِلَّهِ', 33, 'الصحيحان'),
    Dhikr('اللَّهُ أَكْبَرُ', 33, 'الصحيحان'),
    Dhikr('لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', 1, 'صحيح مسلم'),
  ],
  'أذكار النوم': [
    Dhikr('بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا', 1, 'صحيح البخاري'),
    Dhikr('سُبْحَانَ اللَّهِ', 33, 'الصحيحان'),
    Dhikr('الْحَمْدُ لِلَّهِ', 33, 'الصحيحان'),
    Dhikr('اللَّهُ أَكْبَرُ', 34, 'الصحيحان'),
  ],
  'أذكار الاستيقاظ': [
    Dhikr('الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ', 1, 'صحيح البخاري'),
  ],
  'أدعية متنوعة': [
    Dhikr('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 1, 'سورة البقرة: 201'),
    Dhikr('رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ', 1, 'سورة إبراهيم: 41'),
  ],
};

int? _quranSurah(Dhikr item) {
  if (item.source == 'سورة الإخلاص') return 112;
  if (item.source == 'سورة الفلق') return 113;
  if (item.source == 'سورة الناس') return 114;
  if (item.source.startsWith('سورة البقرة: 255')) return 2;
  if (item.source.startsWith('سورة البقرة: 201')) return 2;
  if (item.source.startsWith('سورة إبراهيم: 41')) return 14;
  return null;
}

int _firstVerse(Dhikr item) {
  if (item.source.endsWith(': 255')) return 255;
  if (item.source.endsWith(': 201')) return 201;
  if (item.source.endsWith(': 41')) return 41;
  return 1;
}

int _pageForDhikr(Dhikr item) {
  final surah = _quranSurah(item);
  if (surah == 112 || surah == 113 || surah == 114) return 604;
  if (surah == 14) return 260;
  if (_firstVerse(item) == 255) return 42;
  if (_firstVerse(item) == 201) return 31;
  return 1;
}

String _displayDhikr(Dhikr item) => item.text;

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});

  IconData _icon(String title) {
    if (title.contains('الصباح')) return Icons.wb_sunny_outlined;
    if (title.contains('المساء')) return Icons.nightlight_outlined;
    if (title.contains('الصلاة')) return Icons.mosque_outlined;
    if (title.contains('النوم')) return Icons.bedtime_outlined;
    if (title.contains('الاستيقاظ')) return Icons.wb_twilight_outlined;
    return Icons.volunteer_activism_outlined;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      title: const Text('روضة الأذكار',
        style: TextStyle(fontWeight: FontWeight.w900)),
      centerTitle: true,
      backgroundColor: _green,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(child: LayoutBuilder(builder: (context, bounds) {
      final compact = bounds.maxHeight < 520;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, compact ? 7 : 14, 12, 10),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: compact ? 9 : 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF146651), Color(0xFF073E35), Color(0xFF022E29)],
                begin: Alignment.topRight, end: Alignment.bottomLeft),
              border: Border.all(color: _gold, width: 1.5),
              borderRadius: BorderRadius.circular(21),
              boxShadow: [BoxShadow(
                color: _green.withValues(alpha: .16), blurRadius: 15,
                offset: const Offset(0, 6))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: compact ? 20 : 28,
                color: _gold),
              const SizedBox(height: 4),
              Text('ألا بذكر الله تطمئن القلوب',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white,
                  fontSize: compact ? 17 : 21,
                  fontWeight: FontWeight.w900)),
              const Text('اختر وردك اليومي',
                style: TextStyle(color: _gold, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(child: LayoutBuilder(builder: (context, grid) =>
            GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: (grid.maxHeight - 20) / 3),
            itemCount: _groups.length,
            itemBuilder: (context, i) {
              final entry = _groups.entries.elementAt(i);
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) =>
                      AzkarReader(title: entry.key, items: entry.value))),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: i.isEven
                            ? [const Color(0xFF105B49), const Color(0xFF04362F)]
                            : [const Color(0xFF0B493E), const Color(0xFF022F2A)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft),
                      border: Border.all(color: _gold, width: 1.25),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(
                        color: _green.withValues(alpha: .18),
                        blurRadius: 12, offset: const Offset(0, 5))]),
                    child: LayoutBuilder(builder: (context, tile) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_icon(entry.key),
                            size: (tile.maxHeight * .26).clamp(22.0, 36.0),
                            color: _gold),
                          SizedBox(height: compact ? 4 : 7),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(entry.key,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w900, fontSize: 17)),
                            )),
                          SizedBox(height: compact ? 2 : 5),
                          Text('${entry.value.length} أذكار',
                            style: const TextStyle(color: _gold, fontSize: 11)),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ))),
        ]),
      );
    })),
  );
}

class AzkarReader extends StatefulWidget {
  const AzkarReader({super.key, required this.title, required this.items});
  final String title;
  final List<Dhikr> items;
  @override
  State<AzkarReader> createState() => _AzkarReaderState();
}

class _AzkarReaderState extends State<AzkarReader> {
  int index = 0;
  Map<String, int> counts = {};
  bool loaded = false;
  bool completionShown = false;
  final PageController _pages = PageController();
  List<List<String>> imageManifest = const [];
  String get key => 'azkar_${widget.title}';

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _pages.dispose(); super.dispose(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(prefs.getString(key) ?? '{}')
        as Map<String, dynamic>;
    List<List<String>> cards = const [];
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/azkar/manifest.json')) as List<dynamic>;
      cards = raw.map((group) => (group as List<dynamic>).map((item) => item.toString()).toList()).toList();
    } catch (_) { /* Keep readable text if assets are missing. */ }
    // The 12-hour cycle starts only after all counters were completed.
    final finishedAt = prefs.getInt('${key}_completed_at');
    final resetEligible = (widget.title == 'أذكار الصباح' || widget.title == 'أذكار المساء') &&
        finishedAt != null &&
        DateTime.now().millisecondsSinceEpoch - finishedAt >= const Duration(hours: 12).inMilliseconds;
    if (resetEligible) {
      data.clear();
      await prefs.remove('${key}_completed_at');
      await prefs.remove(key);
      await prefs.setInt('${key}_index', 0);
    }
    if (!mounted) return;
    setState(() {
      imageManifest = cards;
      counts = data.map((k, v) => MapEntry(k, (v as num).toInt()));
      index = resetEligible ? 0 : (prefs.getInt('${key}_index') ?? 0)
          .clamp(0, widget.items.length - 1);
      loaded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(index);
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(counts));
    await prefs.setInt('${key}_index', index);
  }

  void _move(int next) {
    if (next < 0 || next >= widget.items.length) return;
    setState(() => index = next);
    if (_pages.hasClients) {
      _pages.animateToPage(next, duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic);
    }
    _save();
  }

  void _showCompletion() {
    if (widget.title == 'أذكار الصباح' || widget.title == 'أذكار المساء') {
      SharedPreferences.getInstance().then((prefs) => prefs.setInt(
        '${key}_completed_at', DateTime.now().millisecondsSinceEpoch));
    }
    if (completionShown || !mounted) return;
    completionShown = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: _gold, width: 1.5),
        ),
        title: const Column(children: [
          Icon(Icons.auto_awesome_rounded, color: _gold, size: 52),
          SizedBox(height: 12),
          Text('تقبّل الله منك', textAlign: TextAlign.center,
            style: TextStyle(color: _gold, fontSize: 25,
              fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('مبارك إتمام الأذكار', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        ]),
        content: const Text(
          'اللهم اجعل ذكرك أنيسًا لقلوبنا، ونورًا لصدورنا، '
          'وسكينةً لنفوسنا، واغفر لنا ولوالدينا ولجميع المسلمين. '
          'اللهم أعنّا على ذكرك وشكرك وحسن عبادتك.',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 19, height: 1.85),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.favorite_outline),
            label: const Text('اللهم آمين'),
            style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: _green),
          ),
        ],
      ),
    ).whenComplete(() => completionShown = false);
  }

  void _tap() {
    final currentIndex = index;
    final item = widget.items[currentIndex];
    final current = counts['$currentIndex'] ?? 0;
    if (current >= item.target) return;
    setState(() => counts['$currentIndex'] = current + 1);
    _save();
    if (current + 1 == item.target &&
        widget.items.asMap().entries.every(
          (entry) => (counts['${entry.key}'] ?? 0) >= entry.value.target)) {
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _showCompletion();
      });
    }
    if (current + 1 == item.target &&
        currentIndex < widget.items.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 550), () {
        if (mounted && index == currentIndex) _move(currentIndex + 1);
      });
    }
  }

  void _openMushaf(Dhikr item) {
    final surah = _quranSurah(item);
    if (surah == null) return;
    final page = _pageForDhikr(item);
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AthrQcfMushafReader(initialPage: page)));
  }

  String? _imageFor(int itemIndex) {
    final groupIndex = _groups.keys.toList().indexOf(widget.title);
    if (groupIndex < 0 || groupIndex >= imageManifest.length) return null;
    final images = imageManifest[groupIndex];
    if (itemIndex < 0 || itemIndex >= images.length) return null;
    return 'assets/azkar/${images[itemIndex]}';
  }

  Widget _dhikrCard(Dhikr item, int itemIndex) {
    final surah = _quranSurah(item);
    final asset = _imageFor(itemIndex);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _gold, width: 1.5),
        boxShadow: [BoxShadow(
          color: _green.withValues(alpha: .11),
          blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
        child: Column(children: [
          Expanded(child: Center(
            child: asset != null
                ? Image.asset(asset,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, error, stack) => _fittedDhikrText(item))
                : _fittedDhikrText(item),
          )),
          if (surah != null)
            SizedBox(height: 30,
              child: TextButton.icon(
                onPressed: () => _openMushaf(item),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.menu_book_outlined, size: 16),
                label: const Text('عرض في المصحف',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              )),
        ]),
      ),
    );
  }

  Widget _fittedDhikrText(Dhikr item) => LayoutBuilder(
    builder: (context, size) => FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: size.maxWidth.isFinite ? size.maxWidth : 300,
        child: Text(_displayDhikr(item),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _green, fontSize: 27,
            height: 1.85, fontWeight: FontWeight.w600)),
      ),
    ));

  @override
  Widget build(BuildContext context) {
    final item = widget.items[index];
    final count = counts['$index'] ?? 0;
    final done = count >= item.target;
    final completed = widget.items.asMap().entries.where((entry) =>
        (counts['${entry.key}'] ?? 0) >= entry.value.target).length;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: Text(widget.title,
          style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: _green,
        foregroundColor: Colors.white),
      body: !loaded
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SafeArea(child: LayoutBuilder(builder: (context, area) {
              final compact = area.maxHeight < 510;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 8 : 12, compact ? 5 : 10,
                  compact ? 8 : 12, compact ? 6 : 12),
                child: Column(children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: compact ? 7 : 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF146753), Color(0xFF073E35),
                        Color(0xFF032B26)]),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: _gold)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الذكر ${index + 1} / ${widget.items.length}',
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800)),
                          Text('المكتمل $completed / ${widget.items.length}',
                            style: const TextStyle(color: _gold,
                              fontWeight: FontWeight.w800)),
                        ]),
                      const SizedBox(height: 7),
                      LinearProgressIndicator(
                        value: completed / widget.items.length,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: Colors.white24,
                        color: _gold),
                    ]),
                  ),
                  SizedBox(height: compact ? 3 : 7),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: widget.items.length,
                      onPageChanged: (page) {
                        if (page != index) {
                          setState(() => index = page);
                          _save();
                        }
                      },
                      itemBuilder: (context, page) =>
                          _dhikrCard(widget.items[page], page),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 7),
                  Center(child: Semantics(
                    button: true,
                    label: done ? 'اكتمل الذكر' : 'اضغط لتسجيل تسبيحة',
                    value: '$count من ${item.target}',
                    child: InkWell(
                      onTap: done ? null : _tap,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: compact ? 68 : 78,
                        height: compact ? 68 : 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _green,
                          border: Border.all(color: _gold, width: 2.4),
                          boxShadow: [BoxShadow(
                            color: _green.withValues(alpha: .24),
                            blurRadius: 12, offset: const Offset(0, 4))]),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(done ? Icons.check_rounded
                              : Icons.touch_app_rounded,
                              color: _gold, size: compact ? 17 : 20),
                            Text('$count / ${item.target}',
                              style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w900)),
                          ]),
                      ),
                    ),
                  )),
                  Center(child: Text(done ? 'اكتمل الذكر' : 'اضغط على السبحة للذكر',
                    style: const TextStyle(color: _green,
                      fontSize: 12, fontWeight: FontWeight.w800))),
                  SizedBox(height: compact ? 5 : 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: index == 0 ? null : () => _move(index - 1),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('السابق'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _gold),
                        minimumSize: const Size.fromHeight(43)))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(
                      onPressed: index == widget.items.length - 1
                          ? null : () => _move(index + 1),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('التالي'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(43)))),
                  ]),
                ]),
              );
            })),
    );
  }
}
