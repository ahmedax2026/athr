import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF063F32);
const _gold = Color(0xFFC5A052);
const _paper = Color(0xFFFFF8E7);

class MushafPageReader extends StatefulWidget {
  const MushafPageReader({super.key, required this.initialPage});
  final int initialPage;
  @override
  State<MushafPageReader> createState() => _MushafPageReaderState();
}

class _MushafPageReaderState extends State<MushafPageReader> {
  late final PageController controller;
  int page = 1;
  bool controls = true;
  bool night = false;
  List<dynamic> surahs = [];
  int? bookmarkedPage;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604);
    controller = PageController(initialPage: page - 1);
    _loadIndex();
    _restoreBookmark();
  }

  Future<void> _restoreBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => bookmarkedPage = prefs.getInt('mushaf_bookmark_page'));
  }

  Future<void> _bookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_bookmark_page', page);
    if (mounted) setState(() => bookmarkedPage = page);
  }

  void _jump(int value) {
    controller.animateToPage(value.clamp(1, 604) - 1,
      duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  Future<void> _choosePage() async {
    final result = await showDialog<int>(context: context, builder: (ctx) {
      var value = page;
      return StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الصفحة $value من 604'),
          Slider(value: value.toDouble(), min: 1, max: 604, divisions: 603,
            onChanged: (v) => update(() => value = v.round())),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, value),
          child: const Text('انتقال'))]));
    });
    if (result != null) _jump(result);
  }

  Future<void> _chooseSurah() async {
    final result = await showModalBottomSheet<int>(context: context,
      isScrollControlled: true, builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .72,
        child: ListView.builder(itemCount: surahs.length, itemBuilder: (ctx, i) {
          final item = surahs[i];
          return ListTile(title: Text('سورة ${item['name']}'),
            trailing: Text('ص ${item['page']}'),
            onTap: () => Navigator.pop(ctx, item['page'] as int));
        }))));
    if (result != null) _jump(result);
  }

  Future<void> _loadIndex() async {
    final data = jsonDecode(await rootBundle.loadString('assets/mushaf/surah_pages.json'));
    if (mounted) setState(() => surahs = data as List<dynamic>);
  }

  Future<void> _savePage(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_last_page', value);
    if (!mounted) return;
    setState(() => page = value);
  }

  String get surahName {
    String name = 'القرآن الكريم';
    for (final entry in surahs) {
      if ((entry['page'] as int) > page) break;
      name = 'سورة ${entry['name']}';
    }
    return name;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _overlayAction(IconData icon, String label, VoidCallback action) =>
    InkWell(onTap: action, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 27),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ])));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: night ? const Color(0xFF10241F) : _green,
    appBar: null,
    body: SafeArea(child: GestureDetector(
      onTap: () => setState(() => controls = !controls),
      child: Stack(children: [
        Positioned.fill(child: PageView.builder(
          controller: controller,
          reverse: true,
          itemCount: 604,
          onPageChanged: (index) => _savePage(index + 1),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: _gold, width: 1.5),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.all(5),
              child: Image.asset('assets/mushaf/${(index + 1).toString().padLeft(3, '0')}.webp',
                fit: BoxFit.contain, filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stack) =>
                  const Center(child: Text('تعذر فتح صفحة المصحف'))),
            ),
          ),
        )),
        if (controls) Positioned(top: 0, left: 0, right: 0,
          child: Container(color: const Color(0xD9000000), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Column(children: [
                Text(surahName, style: const TextStyle(color: Colors.white, fontSize: 20)),
                Text('الصفحة $page من 604', style: const TextStyle(color: _gold)),
              ])),
              IconButton(icon: const Icon(Icons.brightness_6, color: Colors.white),
                onPressed: () => setState(() => night = !night)),
            ]))),
        if (controls) Positioned(bottom: 0, left: 0, right: 0, child: Container(
          margin: const EdgeInsets.fromLTRB(9, 4, 9, 7),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xE9000000),
            border: Border.all(color: _gold, width: .5)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _overlayAction(Icons.menu_book, 'الفهرس', _chooseSurah),
              _overlayAction(Icons.layers, 'الأجزاء', _choosePage),
              _overlayAction(Icons.article_outlined, 'الصفحات', _choosePage),
              _overlayAction(Icons.search, 'بحث', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('البحث في النص متاح من فهرس القرآن')));
              }),
            ]),
            const Divider(color: _gold),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _overlayAction(Icons.bookmark_add_outlined, 'حفظ علامة', _bookmark),
              _overlayAction(Icons.bookmark, 'العلامة', () {
                if (bookmarkedPage != null) _jump(bookmarkedPage!);
              }),
              _overlayAction(Icons.chevron_right, 'السابق', () => _jump(page - 1)),
              _overlayAction(Icons.chevron_left, 'التالي', () => _jump(page + 1)),
            ]),
          ]),
        )),
      ]),
    )),
  );
}
