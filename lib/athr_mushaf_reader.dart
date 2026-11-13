import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quran Library's native Medina-style Mushaf and built-in index.
/// Initialize lazily so an optional reader initialization failure cannot
/// prevent the memorial app itself from opening.
class AthrMushafReader extends StatefulWidget {
  const AthrMushafReader({
    super.key,
    this.initialPage,
    this.firstPage = 1,
    this.lastPage = 604,
    this.onPage,
  });

  final int? initialPage;
  final int firstPage;
  final int lastPage;
  final ValueChanged<int>? onPage;

  @override
  State<AthrMushafReader> createState() => _AthrMushafReaderState();
}

class _AthrMushafReaderState extends State<AthrMushafReader> {
  static const _green = Color(0xFF073E35);
  static const _paper = Color(0xFFFFFCF5);
  static const _beige = Color(0xFFF0E6D1);
  static const _ink = Color(0xFF29231E);

  static Future<void>? _libraryInit;
  bool _comfort = false;
  int _page = 1;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _prepare();
  }

  Future<void> _prepare() async {
    _libraryInit ??= QuranLibrary.init();
    await _libraryInit;
    final prefs = await SharedPreferences.getInstance();
    final chosen = (widget.initialPage ??
        prefs.getInt('react_quran_last_page') ??
        1).clamp(widget.firstPage, widget.lastPage).toInt();
    // The library uses page numbers for jumps but zero-based callbacks.
    QuranLibrary().jumpToPage(chosen);
    if (!mounted) return;
    setState(() {
      _page = chosen;
      _comfort = prefs.getBool('athr_mushaf_eye_comfort') ?? false;
    });
  }

  Future<void> _changed(int pageIndex) async {
    final page = pageIndex + 1;
    if (!mounted || page < widget.firstPage || page > widget.lastPage) {
      return;
    }
    setState(() => _page = page);
    widget.onPage?.call(page);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('react_quran_last_page', page);
  }

  Future<void> _toggleComfort() async {
    setState(() => _comfort = !_comfort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_mushaf_eye_comfort', _comfort);
  }

  @override
  Widget build(BuildContext context) {
    final paper = _comfort ? _beige : _paper;
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('المصحف الشريف')),
            body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('تعذر تهيئة المصحف. أعد فتحه بعد التحقق من ملفات المكتبة.\n${snapshot.error}',
                  textAlign: TextAlign.center),
            )),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _green)),
          );
        }
        return Theme(
          data: Theme.of(context).copyWith(
            useMaterial3: false, // Required by Quran Library for correct glyph shaping.
            scaffoldBackgroundColor: paper,
            colorScheme: ColorScheme.fromSeed(seedColor: _green,
                surface: paper, brightness: Brightness.light),
          ),
          child: Scaffold(
            backgroundColor: paper,
            appBar: AppBar(
              title: Text('المصحف الشريف • صفحة $_page',
                  style: const TextStyle(fontSize: 16)),
              centerTitle: true,
              backgroundColor: _green,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: _comfort ? 'إيقاف راحة العين' : 'راحة العين',
                  icon: Icon(_comfort ? Icons.visibility : Icons.visibility_outlined),
                  onPressed: _toggleComfort,
                ),
              ],
            ),
            body: widget.firstPage != 1 || widget.lastPage != 604
                ? QuranPagesScreen(
                    parentContext: context,
                    startPage: widget.firstPage,
                    endPage: widget.lastPage,
                    withPageView: true,
                    useDefaultAppBar: false,
                    backgroundColor: paper,
                    textColor: _ink,
                    onPageChanged: _changed,
                  )
                : QuranLibraryScreen(
                    parentContext: context,
                    pageIndex: _page - 1,
                    withPageView: true,
                    useDefaultAppBar: false,
                    isShowTabBar: true,
                    backgroundColor: paper,
                    textColor: _ink,
                    onPageChanged: _changed,
                  ),
          ),
        );
      },
    );
  }
}
