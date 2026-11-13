import 'package:flutter/material.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure Flutter Quran reader; no JavaScript, WebView or network traffic.
class AthrQcfReader extends StatefulWidget {
  const AthrQcfReader({
    super.key,
    this.initialPage,
    this.firstPage = 1,
    this.lastPage = 604,
    this.onPage,
  }) : assert(firstPage >= 1 && lastPage <= 604 && firstPage <= lastPage);

  final int? initialPage;
  final int firstPage;
  final int lastPage;
  final ValueChanged<int>? onPage;

  @override
  State<AthrQcfReader> createState() => _AthrQcfReaderState();
}

class _AthrQcfReaderState extends State<AthrQcfReader> {
  static const _green = Color(0xFF073E35);
  static const _gold = Color(0xFFD6B56C);
  static const _beige = Color(0xFFF0E6D1);
  static const _paper = Color(0xFFFFFCF5);
  static const _ink = Color(0xFF29231E);

  PageController? _controller;
  int _page = 1;
  int? _bookmark;
  bool _comfortable = false;
  bool _dark = false;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final page = (widget.initialPage ??
            prefs.getInt('react_quran_last_page') ??
            widget.firstPage)
        .clamp(widget.firstPage, widget.lastPage)
        .toInt();
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmark = prefs.getInt('react_quran_bookmark');
      _comfortable = prefs.getBool('athr_qcf_eye_comfort') ?? false;
      _dark = prefs.getBool('athr_qcf_dark') ?? false;
      _controller = PageController(initialPage: page - 1);
      _reading = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _changed(int newPage) async {
    if (newPage < widget.firstPage || newPage > widget.lastPage) {
      final edge = newPage < widget.firstPage ? widget.firstPage : widget.lastPage;
      if (_controller?.hasClients ?? false) _controller!.jumpToPage(edge - 1);
      return;
    }
    if (mounted) setState(() => _page = newPage);
    widget.onPage?.call(newPage);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('react_quran_last_page', newPage);
  }

  Future<void> _toggleComfort() async {
    setState(() => _comfortable = !_comfortable);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_qcf_eye_comfort', _comfortable);
  }

  Future<void> _toggleDark() async {
    setState(() => _dark = !_dark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_qcf_dark', _dark);
  }

  Future<void> _saveBookmark() async {
    final newBookmark = _bookmark == _page ? null : _page;
    final prefs = await SharedPreferences.getInstance();
    if (newBookmark == null) {
      await prefs.remove('react_quran_bookmark');
    } else {
      await prefs.setInt('react_quran_bookmark', newBookmark);
    }
    if (mounted) setState(() => _bookmark = newBookmark);
  }

  void _jump(int page) {
    if (page < widget.firstPage || page > widget.lastPage) return;
    _controller?.jumpToPage(page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final background = _dark
        ? const Color(0xFF242B27)
        : (_comfortable ? _beige : _paper);
    final foreground = _dark ? const Color(0xFFF6EBD6) : _green;
    final verseInk = _dark ? const Color(0xFFF7EDD9) : _ink;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text('المصحف الشريف • صفحة $_page',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: _comfortable ? 'إيقاف راحة العين' : 'راحة العين',
            icon: Icon(_comfortable ? Icons.visibility : Icons.visibility_outlined,
                color: _comfortable ? _gold : Colors.white),
            onPressed: _toggleComfort,
          ),
          IconButton(
            tooltip: 'الوضع الليلي',
            icon: const Icon(Icons.dark_mode_outlined),
            onPressed: _toggleDark,
          ),
          IconButton(
            tooltip: _bookmark == _page ? 'إزالة العلامة' : 'حفظ الصفحة',
            icon: Icon(_bookmark == _page
                ? Icons.bookmark : Icons.bookmark_border, color: _gold),
            onPressed: _saveBookmark,
          ),
          if (_bookmark != null)
            IconButton(
              tooltip: 'الانتقال للعلامة',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => _jump(_bookmark!),
            ),
        ],
      ),
      body: !_reading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Column(
              children: [
                Expanded(
                  child: QuranPageView(
                    pageController: _controller!,
                    enableTwoPageLayout: false,
                    scrollDirection: Axis.horizontal,
                    pageSnapping: true,
                    pagePadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 3),
                    pageBackgroundColor: background,
                    // Explicit contrast: library defaults can inherit the app's
                    // light verse color even when the Quran page is beige.
                    // Set ONLY the color to preserve QCF font/layout.
                    ayahStyle: TextStyle(color: verseInk),
                    isDarkMode: _dark,
                    onPageChanged: _changed,
                    topBarBuilder: (context, pageNumber) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الجزء ${getCurrentJuzNumberForPage(pageNumber)}',
                              style: TextStyle(color: foreground, fontSize: 11)),
                          Text('صفحة $pageNumber',
                              style: TextStyle(color: foreground, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'الصفحة السابقة',
                          onPressed: _page > widget.firstPage
                              ? () => _jump(_page - 1) : null,
                          icon: Icon(Icons.chevron_right, color: foreground),
                        ),
                        Text('$_page / 604',
                            style: TextStyle(color: foreground, fontSize: 12)),
                        IconButton(
                          tooltip: 'الصفحة التالية',
                          onPressed: _page < widget.lastPage
                              ? () => _jump(_page + 1) : null,
                          icon: Icon(Icons.chevron_left, color: foreground),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
