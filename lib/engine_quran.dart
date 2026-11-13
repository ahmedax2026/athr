import 'package:flutter/material.dart';
import 'package:alfurqan/alfurqan.dart';
import 'package:alfurqan/constant.dart';
import 'package:alfurqan/data/dart/types.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFB68B45);
const _paper = Color(0xFFFFF8E9);

class EngineQuranScreen extends StatefulWidget {
  const EngineQuranScreen({super.key});
  @override State<EngineQuranScreen> createState() => _EngineQuranScreenState();
}
class _EngineQuranScreenState extends State<EngineQuranScreen> {
  int selected = 1;
  double fontSize = 28;
  bool showTajweed = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
      selected = (p.getInt('alfurqan_last_surah') ?? 1).clamp(1, 114);
      fontSize = p.getDouble('alfurqan_font_size') ?? 28;
      });
    }
  }
  Future<void> _select(int n) async {
    setState(() => selected = n);
    final p = await SharedPreferences.getInstance();
    await p.setInt('alfurqan_last_surah', n);
  }
  Future<void> _index() async {
    var search = '';
    final choice = await showModalBottomSheet<int>(context: context, isScrollControlled: true,
      backgroundColor: _paper, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        final chapters = List.generate(114, (i) => AlQuran.chapter(i + 1))
          .where((c) => c.nameArabic.contains(search) || c.id.toString() == search).toList();
        return SafeArea(child: SizedBox(height: MediaQuery.sizeOf(ctx).height * .83,
          child: Column(children: [
            const SizedBox(height: 15),
            const Text('فهرس سور القرآن الكريم', style: TextStyle(color: _green, fontSize: 23, fontWeight: FontWeight.bold)),
            Padding(padding: const EdgeInsets.all(14), child: TextField(
              onChanged: (s) => refresh(() => search = s.trim()),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث باسم السورة أو رقمها',
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18))))),
            Expanded(child: ListView.builder(itemCount: chapters.length, itemBuilder: (ctx, i) {
              final c = chapters[i];
              return Card(color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: _gold)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: _green,
                    child: Text('${c.id}', style: const TextStyle(color: _paper))),
                  title: Text('سورة ${c.nameArabic}', style: const TextStyle(color: _green, fontSize: 19, fontWeight: FontWeight.bold)),
                  subtitle: Text('${c.versesCount} آية • ${c.revelationPlace == ChapterRevelationPlace.madinah ? 'مدنية' : 'مكية'} • صفحة ${c.pages.first}'),
                  trailing: const Icon(Icons.chevron_left, color: _gold),
                  onTap: () => Navigator.pop(ctx, c.id),
                ));
            })),
          ])));
      }));
    if (choice != null) _select(choice);
  }
  // Alfurqan encodes tajweed tags as HTML entities. Decode markup before
  // interpreting it, so escaped tags are never displayed as Quranic text.
  String _decodeMarkup(String value) {
    var decoded = value;
    for (var i = 0; i < 2; i++) {
      decoded = decoded
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'");
    }
    return decoded;
  }

  Color _ruleColor(String tag) {
    final rule = tag.toLowerCase();
    if (rule.contains('ghunnah') || rule.contains('idgham') ||
        rule.contains('ikhfa') || rule.contains('iqlab')) {
      return const Color(0xFF2778B5);
    }
    if (rule.contains('madd')) return const Color(0xFFC54E49);
    if (rule.contains('qalqalah')) return const Color(0xFF35845D);
    return _green;
  }

  List<InlineSpan> _spans(String input) {
    final decoded = _decodeMarkup(input);
    final tags = RegExp(r'<[^>]*>');
    final spans = <InlineSpan>[];
    final colors = <Color>[_green];
    var pos = 0;
    for (final match in tags.allMatches(decoded)) {
      if (match.start > pos) {
        spans.add(TextSpan(
          text: decoded.substring(pos, match.start),
          style: TextStyle(color: colors.last),
        ));
      }
      final tag = match.group(0)!;
      if (tag.startsWith('</')) {
        if (colors.length > 1) colors.removeLast();
      } else if (!tag.endsWith('/>')) {
        colors.add(_ruleColor(tag));
      }
      pos = match.end;
    }
    if (pos < decoded.length) {
      spans.add(TextSpan(
        text: decoded.substring(pos),
        style: TextStyle(color: colors.last),
      ));
    }
    return spans;
  }
  @override Widget build(BuildContext context) {
    final surah = AlQuran.chapter(selected);
    final verses = AlQuran.versesByChapter(selected,
      mode: showTajweed ? VerseMode.uthmaniTajweed : VerseMode.uthmani);
    return Scaffold(backgroundColor: _paper,
      appBar: AppBar(backgroundColor: _green, foregroundColor: Colors.white,
        title: const Text('القرآن الكريم • التجويد'),
        actions: [
          IconButton(tooltip: 'تصغير الخط', onPressed: () => setState(() => fontSize = (fontSize - 2).clamp(20, 42)),
            icon: const Icon(Icons.text_decrease)),
          IconButton(tooltip: 'تكبير الخط', onPressed: () => setState(() => fontSize = (fontSize + 2).clamp(20, 42)),
            icon: const Icon(Icons.text_increase)),
          IconButton(tooltip: 'فهرس السور', onPressed: _index, icon: const Icon(Icons.list_alt)),
        ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: OutlinedButton.icon(
          onPressed: _index, icon: const Icon(Icons.menu_book),
          label: Text('سورة ${surah.nameArabic}  •  فهرس السور'),
          style: OutlinedButton.styleFrom(foregroundColor: _green, minimumSize: const Size.fromHeight(48)))),
        Expanded(child: ListView(key: ValueKey(selected), padding: const EdgeInsets.fromLTRB(16, 5, 16, 30),
          children: [
            Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(
              color: _green, borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold)),
              child: Text('سورة ${surah.nameArabic}', textAlign: TextAlign.center,
                style: const TextStyle(color: _paper, fontSize: 25, fontWeight: FontWeight.bold))),
            const SizedBox(height: 14),
            for (final verse in verses)
              Padding(padding: const EdgeInsets.symmetric(vertical: 9),
                child: Text.rich(TextSpan(children: [
                  ..._spans(verse.text),
                  TextSpan(text: ' ﴿${AlQuran.arabicNumber(int.parse(verse.verseKey.split(':').last))}﴾',
                    style: TextStyle(color: _gold, fontSize: fontSize * .72)),
                ]), textDirection: TextDirection.rtl, textAlign: TextAlign.center,
                  style: TextStyle(color: _green, fontSize: fontSize, height: 1.85))),
          ])),
      ]),
    );
  }
}
