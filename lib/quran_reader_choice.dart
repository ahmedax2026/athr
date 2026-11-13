import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'react_quran_preview.dart';
import 'mushaf_reader.dart';

/// Reader selector: the current Ottoman reader and the bundled Madani page
/// images. No remote pages are downloaded.
class QuranReaderChoice extends StatefulWidget {
  const QuranReaderChoice({
    super.key,
    required this.initialPage,
    this.firstPage = 1,
    this.lastPage = 604,
    this.onPage,
  });
  final int initialPage, firstPage, lastPage;
  final ValueChanged<int>? onPage;

  @override
  State<QuranReaderChoice> createState() => _QuranReaderChoiceState();
}

class _QuranReaderChoiceState extends State<QuranReaderChoice> {
  String? choice;
  late int currentPage;

  @override
  void didUpdateWidget(covariant QuranReaderChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage) currentPage = widget.initialPage;
  }

  @override
  void initState() {
    super.initState();
    currentPage = widget.initialPage.clamp(widget.firstPage, widget.lastPage);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => choice = prefs.getString('quran_reader_style') ?? 'ottoman');
    }
  }

  Future<void> _select(String next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quran_reader_style', next);
    if (mounted) setState(() => choice = next);
  }

  @override
  Widget build(BuildContext context) {
    if (choice == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final reader = choice == 'madani'
        ? MushafPageReader(
            key: ValueKey('madani_${widget.firstPage}_${widget.lastPage}'),
            initialPage: currentPage,
            firstPage: widget.firstPage,
            lastPage: widget.lastPage,
            onPage: (page) { currentPage = page; widget.onPage?.call(page); },
          )
        : ReactQuranPreview(
            key: ValueKey('ottoman_${widget.firstPage}_${widget.lastPage}'),
            initialPage: currentPage,
            firstPage: widget.firstPage,
            lastPage: widget.lastPage,
            onPage: (page) { currentPage = page; widget.onPage?.call(page); },
          );
    return Stack(children: [
      Positioned.fill(child: reader),
      Positioned(
        right: 12,
        bottom: widget.lastPage < 604 ? 85 : 18,
        child: SafeArea(top: false, child: Material(
          color: const Color(0xFF073E35),
          borderRadius: BorderRadius.circular(30),
          elevation: 5,
          child: PopupMenuButton<String>(
            tooltip: 'اختيار المصحف',
            icon: const Icon(Icons.auto_stories, color: Color(0xFFD6B56C)),
            onSelected: _select,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'ottoman',
                checked: choice == 'ottoman',
                child: const Text('المصحف العثماني'),
              ),
              CheckedPopupMenuItem(
                value: 'madani',
                checked: choice == 'madani',
                child: const Text('المصحف المدني المصور'),
              ),
            ],
          ),
        ))),
      ),
    ]);
  }
}
