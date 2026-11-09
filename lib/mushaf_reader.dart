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

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604);
    controller = PageController(initialPage: page - 1);
    _loadIndex();
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

  Widget _tool(IconData icon, String label, VoidCallback action, {bool emphasized = false}) =>
    InkWell(onTap: action, child: Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
        color: emphasized ? _green : Colors.transparent, shape: BoxShape.circle,
        border: emphasized ? Border.all(color: _gold, width: 2) : null),
        child: Icon(icon, color: emphasized ? _gold : const Color(0xFF80611C), size: 25)),
      Text(label, style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.bold)),
    ]));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: night ? const Color(0xFF10241F) : _green,
    appBar: controls ? AppBar(
      backgroundColor: _green, foregroundColor: _paper,
      centerTitle: true, title: Column(children: [
        Text(surahName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text('الجزء  |  الصفحة $page', style: const TextStyle(color: _gold, fontSize: 12)),
      ]),
      actions: [
        IconButton(tooltip: 'الوضع الليلي', icon: Icon(night ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => setState(() => night = !night)),
        IconButton(tooltip: 'إخفاء الأدوات', icon: const Icon(Icons.fullscreen),
          onPressed: () => setState(() => controls = false)),
      ],
    ) : null,
    body: SafeArea(child: GestureDetector(
      onTap: () => setState(() => controls = !controls),
      child: Column(children: [
        Expanded(child: PageView.builder(
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
        if (controls) Container(
          margin: const EdgeInsets.fromLTRB(9, 4, 9, 7),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: _paper,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _gold, width: 1.5)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _tool(Icons.share_outlined, 'مشاركة', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('مشاركة الصفحة ستتاح قريبًا')));
              }),
              _tool(Icons.menu_book_outlined, 'تفسير', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('التفسير سيُضاف قريبًا')));
              }),
              _tool(Icons.play_circle_fill_rounded, 'استماع', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الاستماع عبر الإنترنت سيُضاف قريبًا')));
              }, emphasized: true),
              _tool(Icons.bookmark_border_rounded, 'علامة', () async {
                await _savePage(page);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم حفظ الصفحة $page')));
                }
              }),
              _tool(Icons.copy_rounded, 'نسخ', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('نسخ النص سيُضاف قريبًا')));
              }),
            ]),
            const Divider(color: _gold),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(tooltip: 'الصفحة السابقة', onPressed: page <= 1 ? null :
                () => controller.animateToPage(page - 2,
                  duration: const Duration(milliseconds: 240), curve: Curves.easeInOut),
                icon: const Icon(Icons.chevron_right, color: _green)),
              Text('الصفحة $page من 604', style: const TextStyle(
                color: _green, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(tooltip: 'الصفحة التالية', onPressed: page >= 604 ? null :
                () => controller.animateToPage(page,
                  duration: const Duration(milliseconds: 240), curve: Curves.easeInOut),
                icon: const Icon(Icons.chevron_left, color: _green)),
            ]),
          ]),
        ),
      ]),
    )),
  );
}
