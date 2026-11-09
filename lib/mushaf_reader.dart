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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: night ? const Color(0xFF10241F) : _paper,
    appBar: controls ? AppBar(
      backgroundColor: _green, foregroundColor: _paper,
      centerTitle: true, title: Column(children: [
        Text(surahName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text('الصفحة $page من 604', style: const TextStyle(color: _gold, fontSize: 12)),
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
                borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(color: _green, border: Border(top: BorderSide(color: _gold))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(tooltip: 'الصفحة السابقة', onPressed: page <= 1 ? null :
              () => controller.animateToPage(page - 2, duration: const Duration(milliseconds: 240), curve: Curves.easeInOut),
              icon: const Icon(Icons.chevron_right, color: _paper)),
            Text('الصفحة $page / 604', style: const TextStyle(color: _paper, fontWeight: FontWeight.bold)),
            IconButton(tooltip: 'الصفحة التالية', onPressed: page >= 604 ? null :
              () => controller.animateToPage(page, duration: const Duration(milliseconds: 240), curve: Curves.easeInOut),
              icon: const Icon(Icons.chevron_left, color: _paper)),
            IconButton(tooltip: 'حفظ الصفحة', onPressed: () async {
              await _savePage(page);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم حفظ الصفحة $page')));
            }, icon: const Icon(Icons.bookmark, color: _gold)),
          ]),
        ),
      ]),
    )),
  );
}
