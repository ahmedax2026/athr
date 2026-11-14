import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'athr_qcf_mushaf_reader.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _paper = Color(0xFFF1E3C6);

class Dhikr {
  const Dhikr(this.text, this.target, this.source, {this.assetIndex, this.image, this.id});
  final int? assetIndex;
  final String? image;
  final String? id;
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

/// Each group is independently versioned; a valid cached group is never
/// replaced by an incomplete response. Original bundled cards remain usable.
class AzkarCatalog {
  static final groups = ValueNotifier<Map<String, List<Dhikr>>>(_defaults());
  static Map<String, List<Dhikr>> _defaults() => {
    for (final entry in _groups.entries) entry.key: [
      for (final pair in entry.value.asMap().entries)
        Dhikr(pair.value.text, pair.value.target, pair.value.source, assetIndex: pair.key, id: 'original_${pair.key}'),
    ],
  };
  static String docId(String title) => 'azkar_group_${_groups.keys.toList().indexOf(title)}';
  static List<Map<String, dynamic>> encode(List<Dhikr> items) => [
    for (final item in items) {'id': item.id, 'text': item.text, 'target': item.target,
      'source': item.source, if (item.assetIndex != null) 'assetIndex': item.assetIndex,
      if (item.image != null) 'image': item.image},
  ];
  static List<Dhikr>? decode(dynamic raw, String title) {
    if (raw is! List || raw.isEmpty || raw.length > 60) return null;
    final items = <Dhikr>[], seen = <String>{};
    for (final row in raw) {
      if (row is! Map) return null;
      final id = row['id'], text = row['text'], target = row['target'], source = row['source'];
      final asset = row['assetIndex'], image = row['image'];
      if (id is! String || id.length > 80 || !seen.add(id) || text is! String ||
          text.trim().isEmpty || text.length > 4000 || target is! int || target < 1 || target > 1000 ||
          source is! String || source.length > 300) return null;
      if (asset != null && (asset is! int || asset < 0 || asset >= _groups[title]!.length)) return null;
      if (image != null) {
        if (image is! String || image.length > 150000) return null;
        try {
          final bytes = base64Decode(image);
          if (bytes.length < 3 || bytes[0] != 255 || bytes[1] != 216 || bytes[2] != 255) return null;
        } catch (_) { return null; }
      }
      items.add(Dhikr(text, target, source, id: id, assetIndex: asset as int?, image: image as String?));
    }
    return items;
  }
  static Future<void>? _refreshing;
  static Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  static Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = _defaults();
      for (final title in _groups.keys) {
        try {
          final raw = prefs.getString(docId(title));
          if (raw != null) {
            final items = decode(jsonDecode(raw), title);
            if (items != null) cached[title] = items;
          }
        } catch (_) {}
      }
      groups.value = cached;
      if (Firebase.apps.isEmpty) return;
      for (final title in _groups.keys) {
        try {
          final snap = await FirebaseFirestore.instance.collection('content').doc(docId(title)).get()
              .timeout(const Duration(seconds: 4));
          final data = snap.data();
          if (data == null || data['published'] != true) continue;
          final items = decode(data['items'], title);
          if (items == null) continue;
          final payload = jsonEncode(encode(items));
          if (prefs.getString(docId(title)) == payload) continue;
          await prefs.setString(docId(title), payload);
          groups.value = {...groups.value, title: items};
        } catch (_) {}
      }
    } catch (_) {}
  }
}

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
    body: ValueListenableBuilder<Map<String, List<Dhikr>>>(valueListenable: AzkarCatalog.groups, builder: (context, groups, _) => SafeArea(child: LayoutBuilder(builder: (context, bounds) {
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
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final entry = groups.entries.elementAt(i);
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
    }))),
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
  String _countKey(int i) => widget.items[i].id ?? 'original_$i';

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
      counts = {for (final entry in data.entries) if (entry.value is num)
        int.tryParse(entry.key) != null ? 'original_${entry.key}' : entry.key: (entry.value as num).toInt()};
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
    final current = counts[_countKey(currentIndex)] ?? 0;
    if (current >= item.target) return;
    setState(() => counts[_countKey(currentIndex)] = current + 1);
    _save();
    if (current + 1 == item.target &&
        widget.items.asMap().entries.every(
          (entry) => (counts[_countKey(entry.key)] ?? 0) >= entry.value.target)) {
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
    final original = widget.items[itemIndex].assetIndex;
    if (original == null || original < 0 || original >= images.length) return null;
    return 'assets/azkar/${images[original]}';
  }

  Widget _dhikrText(Dhikr item) => SingleChildScrollView(
    padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(item.text, textAlign: TextAlign.center, style: const TextStyle(color: _green, fontSize: 25, height: 1.8, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(item.source, textAlign: TextAlign.center, style: const TextStyle(color: _green, fontSize: 13)),
    ]),
  );

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
            child: item.image != null
                ? Image.memory(base64Decode(item.image!), fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _dhikrText(item))
                : asset != null
                ? Image.asset(asset, fit: BoxFit.contain, width: double.infinity,
                    height: double.infinity, filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => _dhikrText(item))
                : _dhikrText(item),
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

  @override
  Widget build(BuildContext context) {
    final item = widget.items[index];
    final count = counts[_countKey(index)] ?? 0;
    final done = count >= item.target;
    final completed = widget.items.asMap().entries.where((entry) =>
        (counts[_countKey(entry.key)] ?? 0) >= entry.value.target).length;
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
                    Expanded(child: FilledButton.icon(
                      onPressed: index == 0 ? null : () => _move(index - 1),
                      icon: const Icon(Icons.chevron_right_rounded, size: 24),
                      label: const Text('السابق',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD6B56C),
                        foregroundColor: _green,
                        disabledBackgroundColor: const Color(0xFFE9DEBF),
                        disabledForegroundColor: const Color(0xFF817B68),
                        side: const BorderSide(color: _green, width: 1.2),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(51)))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton.icon(
                      onPressed: index == widget.items.length - 1
                          ? null : () => _move(index + 1),
                      icon: const Icon(Icons.chevron_left_rounded, size: 24),
                      label: const Text('التالي',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD8E1D6),
                        disabledForegroundColor: const Color(0xFF627569),
                        side: const BorderSide(color: _gold, width: 1.6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size.fromHeight(51)))),
                  ]),
                ]),
              );
            })),
    );
  }
}

class AdminAzkarScreen extends StatefulWidget {
  const AdminAzkarScreen({super.key});
  @override
  State<AdminAzkarScreen> createState() => _AdminAzkarScreenState();
}
class _AdminAzkarScreenState extends State<AdminAzkarScreen> {
  String group = _groups.keys.first;
  List<Dhikr> items = [];
  bool busy = true;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { busy = true; error = null; });
    try {
      final snap = await FirebaseFirestore.instance.collection('content').doc(AzkarCatalog.docId(group)).get();
      final data = snap.data();
      final decoded = AzkarCatalog.decode(data?['items'], group);
      if (!mounted) return;
      setState(() => items = List.of(decoded ?? AzkarCatalog._defaults()[group]!));
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل الأذكار. أعد المحاولة قبل الحفظ.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> _edit([int? index]) async {
    final old = index == null ? null : items[index];
    final result = await showDialog<Dhikr>(context: context, builder: (_) => _AzkarEditDialog(item: old));
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) { items.add(result); } else { items[index] = result; }
    });
  }
  Future<void> _save() async {
    final data = AzkarCatalog.encode(items);
    if (AzkarCatalog.decode(data, group) == null || utf8.encode(jsonEncode(data)).length > 850000) {
      setState(() => error = 'القسم يحتاج ذكرًا واحدًا على الأقل، وحجم الصور الإجمالي يجب ألا يتجاوز الحد المتاح.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await FirebaseFirestore.instance.collection('content').doc(AzkarCatalog.docId(group)).set({
        'published': true, 'items': data, 'updatedAt': FieldValue.serverTimestamp(),
      });
      unawaited(AzkarCatalog.refresh());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر تحديث الأذكار')));
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التحديث');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الأذكار')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(
        initialValue: group, decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
        items: [for (final name in _groups.keys) DropdownMenuItem(value: name, child: Text(name))],
        onChanged: busy ? null : (name) async {
          if (name == null || name == group) return;
          final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('تغيير القسم؟'), content: const Text('أي تعديلات لم تحفظها ستفقد.'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة'))],
          ));
          if (confirm != true || !mounted) return;
          group = name;
          await _load();
        },
      )),
      if (busy) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      Expanded(child: ReorderableListView.builder(
        padding: const EdgeInsets.all(12), itemCount: items.length,
        onReorder: (from, to) {
          if (busy) return;
          setState(() { if (to > from) to--; final item = items.removeAt(from); items.insert(to, item); });
        },
        itemBuilder: (context, i) => Card(key: ValueKey(items[i].id), child: ListTile(
          title: Text(items[i].text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${items[i].target} تكرار • ${items[i].source}'),
          onTap: busy ? null : () => _edit(i),
          leading: IconButton(icon: const Icon(Icons.delete_outline), onPressed: busy || items.length <= 1 ? null : () async {
            final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('حذف الذكر من القائمة؟'), actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
              ],
            ));
            if (yes == true && mounted) setState(() => items.removeAt(i));
          }),
        )),
      )),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: busy || items.length >= 60 ? null : () => _edit(),
          icon: const Icon(Icons.add), label: const Text('إضافة ذكر'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(onPressed: busy || items.isEmpty ? null : _save, child: const Text('حفظ ونشر'))),
      ]))),
    ]),
  );
}
class _AzkarEditDialog extends StatefulWidget {
  const _AzkarEditDialog({this.item});
  final Dhikr? item;
  @override
  State<_AzkarEditDialog> createState() => _AzkarEditDialogState();
}
class _AzkarEditDialogState extends State<_AzkarEditDialog> {
  late final text = TextEditingController(text: widget.item?.text ?? '');
  late final source = TextEditingController(text: widget.item?.source ?? '');
  late final target = TextEditingController(text: (widget.item?.target ?? 1).toString());
  late String? image = widget.item?.image;
  late int? asset = widget.item?.assetIndex;
  bool picking = false;
  String? error;
  Future<void> _pick() async {
    setState(() { picking = true; error = null; });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 65);
      if (file == null || !mounted) return;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 110000 || bytes.length < 3 || bytes[0] != 255 || bytes[1] != 216 || bytes[2] != 255) {
        setState(() => error = 'اختر صورة JPEG أصغر من 110 كيلوبايت بعد الضغط');
        return;
      }
      setState(() { image = base64Encode(bytes); asset = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر اختيار الصورة');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }
  @override
  void dispose() { text.dispose(); source.dispose(); target.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('بيانات الذكر'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: text, maxLines: 5, maxLength: 4000, decoration: const InputDecoration(labelText: 'نص الذكر'),
        onChanged: (_) { if (asset != null || image != null) setState(() { asset = null; image = null; }); }),
      TextField(controller: source, maxLength: 300, decoration: const InputDecoration(labelText: 'المصدر')),
      TextField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد التكرارات')),
      if (image != null) Image.memory(base64Decode(image!), height: 120, fit: BoxFit.contain),
      if (asset != null) const Text('الصورة الأصلية محفوظة'),
      OutlinedButton.icon(onPressed: picking ? null : _pick, icon: const Icon(Icons.image_outlined), label: const Text('اختيار صورة')),
      if (image != null || asset != null) TextButton(onPressed: picking ? null : () => setState(() { image = null; asset = null; }), child: const Text('حذف الصورة وعرض النص')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
    ])),
    actions: [
      TextButton(onPressed: picking ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: picking ? null : () {
        final count = int.tryParse(target.text.trim());
        if (text.text.trim().isEmpty || count == null || count < 1 || count > 1000) {
          setState(() => error = 'أدخل النص وعدد تكرارات من 1 إلى 1000');
          return;
        }
        Navigator.pop(context, Dhikr(text.text.trim(), count, source.text.trim(),
          id: widget.item?.id ?? 'custom_${DateTime.now().microsecondsSinceEpoch}', assetIndex: asset, image: image));
      }, child: const Text('اعتماد')),
    ],
  );
}
