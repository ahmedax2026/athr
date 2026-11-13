import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_engine/quran_engine.dart';

const _green = Color(0xFF073E35);
const _paper = Color(0xFFFFF8E8);
const _gold = Color(0xFFB38B42);

class EngineQuranScreen extends StatefulWidget {
  const EngineQuranScreen({super.key});
  @override
  State<EngineQuranScreen> createState() => _EngineQuranScreenState();
}

class _EngineQuranScreenState extends State<EngineQuranScreen> {
  late final Future<Engine> engineFuture = _load();
  int selected = 1;
  double fontSize = 27;

  Future<Engine> _load() async {
    Future<dynamic> data(String name) async =>
        jsonDecode(await rootBundle.loadString('assets/tajweed/$name'));
    return Engine.fromJson(
      quranJson: await data('quran.json') as List,
      juzJson: await data('juz.json') as List,
      recitersJson: await data('reciters.json') as List,
      tajweedRulesJson: await data('tajweed-rules.json') as Map<String, dynamic>,
      tajweedAnnotationsJson: await data('tajweed-annotations.json') as List,
    );
  }

  Color _color(String? hex) {
    if (hex == null) return const Color(0xFF18291F);
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    return value == null || clean.length != 6
        ? const Color(0xFF18291F) : Color(0xFF000000 | value);
  }

  List<InlineSpan> _verse(Engine engine, Ayah verse) {
    final spans = <InlineSpan>[];
    final text = verse.textArabic;
    var pos = 0;
    final annotated = engine.tajweedSpans(selected, verse.id)
      ..sort((a, b) => a.start.compareTo(b.start));
    for (final span in annotated) {
      if (span.start < pos || span.end > text.length || span.end <= span.start) continue;
      if (span.start > pos) spans.add(TextSpan(text: text.substring(pos, span.start)));
      spans.add(TextSpan(text: text.substring(span.start, span.end),
          style: TextStyle(color: _color(span.colorHex))));
      pos = span.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    spans.add(TextSpan(text: ' ﴿${verse.id}﴾ ',
        style: TextStyle(color: _gold, fontSize: fontSize * .65,
            fontWeight: FontWeight.bold)));
    return spans;
  }

  Future<void> _index(Engine engine) async {
    final choice = await showModalBottomSheet<int>(
      context: context, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .8,
        child: ListView.builder(itemCount: 114, itemBuilder: (ctx, i) {
          final surah = engine.surah(i + 1)!;
          return ListTile(
            leading: CircleAvatar(backgroundColor: _green,
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white))),
            title: Text(surah.nameArabic, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Text('${surah.numberOfAyahs} آية • ${surah.type == 'madinan' ? 'مدنية' : 'مكية'}'),
            onTap: () => Navigator.pop(ctx, i + 1),
          );
        }),
      )),
    );
    if (choice != null) setState(() => selected = choice);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(backgroundColor: _green, foregroundColor: Colors.white,
      title: const Text('القرآن الكريم • التجويد'),
      actions: [
        IconButton(tooltip: 'تصغير', onPressed: () => setState(() => fontSize = (fontSize - 2).clamp(20, 42)),
          icon: const Icon(Icons.text_decrease)),
        IconButton(tooltip: 'تكبير', onPressed: () => setState(() => fontSize = (fontSize + 2).clamp(20, 42)),
          icon: const Icon(Icons.text_increase)),
      ]),
    body: FutureBuilder<Engine>(future: engineFuture, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: Text('تعذر تحميل مكتبة القرآن: ${snapshot.error}'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final engine = snapshot.data!;
      final surah = engine.surah(selected)!;
      return Column(children: [
        Padding(padding: const EdgeInsets.all(10),
          child: OutlinedButton.icon(
            onPressed: () => _index(engine),
            icon: const Icon(Icons.menu_book),
            label: Text('${surah.id} • سورة ${surah.nameArabic}  |  فهرس السور',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(foregroundColor: _green,
              minimumSize: const Size.fromHeight(54)),
          )),
        Expanded(child: ListView(key: ValueKey(selected),
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 36),
          children: [
            Container(padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _gold)),
              child: Text('سورة ${surah.nameArabic}', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
            const SizedBox(height: 18),
            Text.rich(TextSpan(children: [
              for (final ayah in surah.ayahs) ..._verse(engine, ayah),
            ]), textDirection: TextDirection.rtl, textAlign: TextAlign.justify,
              style: TextStyle(color: const Color(0xFF18291F),
                fontSize: fontSize, height: 1.85)),
          ])),
      ]);
    }),
  );
}
