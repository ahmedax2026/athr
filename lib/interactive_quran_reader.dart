import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran.dart';
import 'athr_qcf_reader.dart';

class InteractiveQuranReader extends StatefulWidget {
  const InteractiveQuranReader({super.key, required this.surahNumber});
  final int surahNumber;
  @override
  State<InteractiveQuranReader> createState() => _InteractiveQuranReaderState();
}

class _InteractiveQuranReaderState extends State<InteractiveQuranReader> {
  late final Future<List<dynamic>> _chapters = QuranService.fetchAll();
  double fontSize = 29;
  bool night = false;
  int? selected;
  int? bookmarked;
  late int surahNumber;
  final ScrollController scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    surahNumber = widget.surahNumber;
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      fontSize = (p.getDouble('interactive_quran_font') ?? 29).clamp(21, 43);
      night = p.getBool('interactive_quran_night') ?? false;
      if (p.getInt('quran_last_surah') == surahNumber) {
        bookmarked = p.getInt('quran_last_ayah');
      }
    });
  }

  Future<void> _saveBookmark() async {
    if (selected == null) {
      _message('اضغط على آية أولًا لتحديدها');
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt('quran_last_surah', surahNumber);
    await p.setInt('quran_last_ayah', selected!);
    if (mounted) {
      setState(() => bookmarked = selected);
      _message('تم حفظ الآية $selected');
    }
  }

  Future<void> _saveAppearance() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('interactive_quran_font', fontSize);
    await p.setBool('interactive_quran_night', night);
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _copy(List<dynamic> verses) async {
    if (selected == null) { _message('حدد آية أولًا'); return; }
    final text = verses[selected! - 1].toString();
    await Clipboard.setData(ClipboardData(text: '$text ﴿$selected﴾'));
    _message('تم نسخ الآية $selected');
  }

  void _changeSurah(int delta) {
    final next = surahNumber + delta;
    if (next < 1 || next > 114) return;
    setState(() { surahNumber = next; selected = null; bookmarked = null; });
    if (scroll.hasClients) scroll.jumpTo(0);
    _restore();
  }

  @override
  void dispose() { scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final paper = night ? const Color(0xFF192A25) : const Color(0xFFFFF9E9);
    final ink = night ? const Color(0xFFF4E9CE) : const Color(0xFF191C18);
    return FutureBuilder<List<dynamic>>(future: _chapters, builder: (context, snapshot) {
      if (snapshot.hasError) return const Scaffold(body: Center(child: Text('تعذر فتح النص القرآني')));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final chapters = snapshot.data!;
      final surah = chapters[surahNumber - 1] as Map<String, dynamic>;
      final verses = surah['ayahs'] as List<dynamic>;
      final name = surah['name'].toString();
      return Scaffold(
        backgroundColor: const Color(0xFF063D30),
        appBar: AppBar(backgroundColor: const Color(0xFF063D30),
          foregroundColor: const Color(0xFFFFF8E6), centerTitle: true,
          title: Column(children: [
            Text('سورة $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('المصحف التفاعلي', style: TextStyle(fontSize: 12, color: Color(0xFFE1C17A))),
          ]),
          actions: [
            IconButton(tooltip: 'الوضع الليلي', onPressed: () {
              setState(() => night = !night); _saveAppearance();
            }, icon: Icon(night ? Icons.light_mode_outlined : Icons.dark_mode_outlined)),
            PopupMenuButton<String>(onSelected: (value) async {
              if (value == 'paper') {
                final index = jsonDecode(await rootBundle.loadString('assets/mushaf/surah_pages.json')) as List<dynamic>;
                final page = index.firstWhere((s) => s['number'] == surahNumber)['page'] as int;
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => AthrQcfReader(initialPage: page)));
              }
            }, itemBuilder: (_) => const [
              PopupMenuItem(value: 'paper', child: Text('المصحف الورقي (الصفحات الأصلية)')),
            ]),
          ]),
        body: SafeArea(child: Column(children: [
          Expanded(child: Container(
            margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
            decoration: BoxDecoration(color: paper,
              border: Border.all(color: const Color(0xFFC9A75C), width: 2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
            child: Directionality(textDirection: TextDirection.rtl,
              child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                children: [
                  Center(child: Text('۞  سُورَةُ $name  ۞',
                    style: TextStyle(fontSize: 27, color: night ? const Color(0xFFE6C37C) : const Color(0xFF8A672C),
                      fontWeight: FontWeight.bold))),
                  const SizedBox(height: 14),
                  if (surahNumber != 1 && surahNumber != 9)
                    Center(child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize * .85,
                        color: ink, height: 2))),
                  const SizedBox(height: 20),
                  // Inline text wraps naturally across lines, like a reading mushaf.
                  Text.rich(TextSpan(children: [
                    for (var i = 0; i < verses.length; i++)
                      TextSpan(children: [
                        TextSpan(text: '${verses[i]} ', style: TextStyle(
                          backgroundColor: selected == i + 1
                            ? const Color(0x553DBB78) : null),
                          recognizer: null),
                        WidgetSpan(alignment: PlaceholderAlignment.middle,
                          child: InkWell(onTap: () => setState(() => selected = i + 1),
                            child: Container(margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFB18B3D), width: 1.5)),
                              child: Text('${i + 1}', style: TextStyle(
                                color: night ? const Color(0xFFE1C17A) : const Color(0xFF795A20),
                                fontSize: fontSize * .52))))),
                        const TextSpan(text: ' '),
                      ]),
                  ]), textAlign: TextAlign.justify,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: fontSize, height: 2.05, color: ink)),
                  const SizedBox(height: 28),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => _changeSurah(-1), child: const Text('السورة السابقة')),
                    TextButton(onPressed: () => _changeSurah(1), child: const Text('السورة التالية')),
                  ]),
                ])))),
          Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF7E4),
              border: Border.all(color: const Color(0xFFC9A75C)),
              borderRadius: BorderRadius.circular(19)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _action(Icons.copy_outlined, 'نسخ', () => _copy(verses)),
                _action(Icons.bookmark_border, 'علامة', _saveBookmark),
                _action(Icons.play_circle_fill_rounded, 'استماع',
                  () => _message('الاستماع يحتاج إضافة مصدر تلاوة')),
                _action(Icons.menu_book_outlined, 'تفسير',
                  () => _message('التفسير يحتاج إضافة مصدر موثوق')),
                _action(Icons.share_outlined, 'مشاركة', () async {
                  if (selected == null) { _message('حدد آية أولًا'); return; }
                  await Clipboard.setData(ClipboardData(
                    text: '${verses[selected! - 1]} ﴿$selected﴾ — سورة $name'));
                  _message('تم نسخ الآية للمشاركة');
                }),
              ]),
              const Divider(color: Color(0xFFC9A75C)),
              Row(children: [
                const Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(onPressed: () {
                  setState(() => fontSize = (fontSize - 2).clamp(21, 43)); _saveAppearance();
                }, icon: const Icon(Icons.remove_circle_outline)),
                Expanded(child: Slider(value: fontSize, min: 21, max: 43,
                  activeColor: const Color(0xFF94702E), onChanged: (value) {
                    setState(() => fontSize = value); _saveAppearance();
                  })),
                IconButton(onPressed: () {
                  setState(() => fontSize = (fontSize + 2).clamp(21, 43)); _saveAppearance();
                }, icon: const Icon(Icons.add_circle_outline)),
              ]),
              Text(selected == null ? 'اضغط على رقم الآية لتحديدها'
                : 'الآية $selected من ${verses.length}${bookmarked == selected ? ' • محفوظة' : ''}',
                style: const TextStyle(fontSize: 13)),
            ])),
        ])),
      );
    });
  }

  Widget _action(IconData icon, String label, VoidCallback callback) =>
    InkWell(onTap: callback, child: Column(children: [
      Icon(icon, size: 25, color: const Color(0xFF846523)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]));
}
