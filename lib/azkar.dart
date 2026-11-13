import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'react_quran_preview.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _paper = Color(0xFFFFF8E9);

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
    Dhikr('رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا وَرَسُولًا', 3, 'أبو داود والترمذي'),
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
      title: const Text('الأذكار', style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: _green,
      foregroundColor: Colors.white),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [Color(0xFF0D5A4A), Color(0xFF032B25)]),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _gold, width: 1.5),
            boxShadow: [BoxShadow(color: _green.withValues(alpha: .25), blurRadius: 22, offset: const Offset(0, 9))]),
          child: const Column(children: [
            Icon(Icons.auto_awesome_rounded, color: _gold, size: 33),
            SizedBox(height: 10),
            Text('ألا بذكر الله تطمئن القلوب',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 23,
                fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('أذكار يومك في مكان واحد',
              style: TextStyle(color: _gold, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 14),
        for (final entry in _groups.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              elevation: 3,
              shadowColor: _green.withValues(alpha: .15),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) =>
                    AzkarReader(title: entry.key, items: entry.value))),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: _gold.withValues(alpha: .65)),
                    borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                      child: Icon(_icon(entry.key), color: _gold, size: 27)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: const TextStyle(
                          color: _green, fontSize: 19,
                          fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('${entry.value.length} أذكار',
                          style: const TextStyle(color: Color(0xFF837C6D),
                            fontSize: 13)),
                      ])),
                    const Icon(Icons.chevron_left, color: _green),
                  ]),
                ),
              ),
            ),
          ),
      ],
    ),
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
  List<List<String>> imageManifest = const [];
  String get key => 'azkar_${widget.title}';

  @override
  void initState() { super.initState(); _load(); }

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
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(counts));
    await prefs.setInt('${key}_index', index);
  }

  void _move(int next) {
    if (next < 0 || next >= widget.items.length) return;
    setState(() => index = next);
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
      builder: (_) => ReactQuranPreview(initialPage: page)));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[index];
    final count = counts['$index'] ?? 0;
    final done = count >= item.target;
    final surah = _quranSurah(item);
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _green,
        foregroundColor: Colors.white),
      body: !loaded
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(children: [
                LinearProgressIndicator(
                  value: (index + count / item.target) /
                      widget.items.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(12),
                  backgroundColor: const Color(0xFFE9DEC6),
                  color: _green),
                const SizedBox(height: 10),
                Text('الذكر ${index + 1} من ${widget.items.length}',
                  style: const TextStyle(
                    color: _green, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(child: Center(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _gold, width: 1.5),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [BoxShadow(color: _green.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 8))]),
                  child: Column(children: [
                    if (surah != null) ...[
                      const Icon(Icons.menu_book_rounded, color: _gold, size: 36),
                      const SizedBox(height: 10),
                      const Text('آيات من المصحف العثماني', style: TextStyle(color: _green,
                          fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                    ],
                    // Keep Quran artwork, but never use incomplete pre-rendered
                    // images for ordinary adhkar. Their full text is the source of truth.
                    if (surah != null) ...[
                      if (item.source == 'سورة البقرة: 255') ...[
                        const Text('آية الكرسي',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _green, fontSize: 23,
                            fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                      ],
                      Image.asset(
                        'assets/azkar/${imageManifest.length > _groups.keys.toList().indexOf(widget.title) && imageManifest[_groups.keys.toList().indexOf(widget.title)].length > index ? imageManifest[_groups.keys.toList().indexOf(widget.title)][index] : 'missing.webp'}',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          _displayDhikr(item),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, height: 1.7, color: _green),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4E5C9),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _displayDhikr(item),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 25, height: 1.9, color: _green,
                            fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(item.source, style: const TextStyle(
                      color: Color(0xFF97723E), fontSize: 14)),
                    if (surah != null) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => _openMushaf(item),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('عرض الآيات في المصحف العثماني'),
                        style: TextButton.styleFrom(
                          foregroundColor: _green)),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),
                Center(child: InkWell(
                  onTap: _tap,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 150, height: 150,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF126452), Color(0xFF032E27)]),
                      shape: BoxShape.circle,
                      border: Border.all(color: _gold, width: 3),
                      boxShadow: [BoxShadow(color: _green.withValues(alpha: .24), blurRadius: 18, offset: const Offset(0, 8))]),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$count من ${item.target}',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 25,
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text(done ? 'اكتمل الذكر' : 'اضغط للعد',
                          style: const TextStyle(
                            color: _gold, fontSize: 14)),
                      ]),
                  ),
                )),
              ]),
            ))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: index == 0 ? null : () => _move(index - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _gold),
                    minimumSize: const Size.fromHeight(48)),
                  child: const Text('السابق'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: index == widget.items.length - 1
                      ? null : () => _move(index + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48)),
                  child: const Text('التالي'))),
              ]),
            ),
          ])),
    );
  }
}
