import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native QCF Madani Mushaf. No webview, networking, or external font downloads.
class AthrQcfMushafReader extends StatefulWidget {
  const AthrQcfMushafReader({
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
  State<AthrQcfMushafReader> createState() => _AthrQcfMushafReaderState();
}

class _AthrQcfMushafReaderState extends State<AthrQcfMushafReader> {
  static const _green = Color(0xFF073E35);
  static const _gold = Color(0xFFD6B56C);
  static const _paper = Color(0xFFFFFCF5);
  static const _beige = Color(0xFFF0E6D1);
  static const _ink = Color(0xFF29231E);

  PageController? _controller;
  int _page = 1;
  int? _bookmark;
  bool _eyeComfort = false;
  bool _dark = false;
  DateTime? _lastBoundaryAlert;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final requested = widget.initialPage ??
        prefs.getInt('react_quran_last_page') ??
        widget.firstPage;
    final page = requested.clamp(widget.firstPage, widget.lastPage).toInt();
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmark = prefs.getInt('react_quran_bookmark');
      _eyeComfort = prefs.getBool('athr_qcf_eye_comfort') ?? false;
      _dark = prefs.getBool('athr_qcf_dark') ?? false;
      _controller = PageController(initialPage: page - widget.firstPage);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onPage(int page) async {
    if (page < widget.firstPage || page > widget.lastPage) return;
    if (mounted) setState(() => _page = page);
    widget.onPage?.call(page);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('react_quran_last_page', page);
  }

  bool get _isLimitedReading =>
      widget.firstPage > 1 || widget.lastPage < 604;

  void _showPartBoundary() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastBoundaryAlert != null &&
        now.difference(_lastBoundaryAlert!) < const Duration(seconds: 2)) {
      return;
    }
    _lastBoundaryAlert = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text(
          'انتهت صفحات الجزء الحالي. ارجع إلى قائمة الأجزاء واختر الجزء التالي.',
          textDirection: TextDirection.rtl,
        ),
        duration: Duration(seconds: 3),
      ));
  }

  void _jump(int page) {
    if (page < widget.firstPage || page > widget.lastPage) {
      if (_isLimitedReading) _showPartBoundary();
      return;
    }
    if (_controller?.hasClients ?? false) {
      _controller!.jumpToPage(page - widget.firstPage);
    }
  }

  Future<void> _openIndex() async {
    final picked = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const _QcfMushafIndex()));
    if (picked == null || !mounted) return;
    if (picked < widget.firstPage || picked > widget.lastPage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الصفحة خارج الجزء المحدد للختمة')));
      return;
    }
    _jump(picked);
  }

  Future<void> _toggleComfort() async {
    final next = !_eyeComfort;
    setState(() => _eyeComfort = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_qcf_eye_comfort', next);
  }

  Future<void> _toggleDark() async {
    final next = !_dark;
    setState(() => _dark = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_qcf_dark', next);
  }

  Future<void> _saveBookmark() async {
    final next = _bookmark == _page ? null : _page;
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove('react_quran_bookmark');
    } else {
      await prefs.setInt('react_quran_bookmark', next);
    }
    if (mounted) setState(() => _bookmark = next);
  }

  @override
  Widget build(BuildContext context) {
    final background = _dark
        ? const Color(0xFF262925)
        : _eyeComfort ? _beige : _paper;
    final foreground = _dark ? const Color(0xFFF6EBD6) : _ink;
    final theme = QcfThemeData(
      pageBackgroundColor: background,
      verseTextColor: foreground,
      verseNumberColor: _dark ? _gold : const Color(0xFF765C35),
      basmalaColor: foreground,
      headerTextColor: foreground,
      // Preserve the QCF glyph shapes while giving lines enough vertical
      // room to occupy the page rather than leaving a blank lower half.
      // Scale is relative to the actual reader viewport below.
      verseHeight: 1.82,
      verseNumberHeight: 1.22,
      letterSpacing: 0,
      wordSpacing: 0,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text('المصحف الشريف • صفحة $_page',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: 'فهرس السور والأجزاء',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: _openIndex,
            ),
            IconButton(
              tooltip: _eyeComfort ? 'إيقاف راحة العين' : 'راحة العين',
              icon: Icon(_eyeComfort ? Icons.visibility : Icons.visibility_outlined,
                  color: _eyeComfort ? _gold : Colors.white),
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
          ],
        ),
        body: _controller == null
          ? const Center(child: CircularProgressIndicator(color: _green))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // QcfPage normally measures the whole phone, including
                      // the top and bottom bars, then wraps long glyph lines.
                      // Give it the real page viewport to keep a single page
                      // readable without oversized isolated words.
                      final viewport = MediaQuery.of(context).copyWith(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      );
                      return MediaQuery(
                        data: viewport,
                        child: widget.firstPage == 1 &&
                                widget.lastPage == 604
                            ? PageviewQuran(
                                controller: _controller,
                                initialPageNumber: _page,
                                sp: 0.82,
                                h: 1.14,
                                theme: theme,
                                onPageChanged: _onPage,
                              )
                            : NotificationListener<OverscrollNotification>(
                                onNotification: (notification) {
                                  if (_page == widget.firstPage ||
                                      _page == widget.lastPage) {
                                    WidgetsBinding.instance.addPostFrameCallback(
                                      (_) => _showPartBoundary(),
                                    );
                                  }
                                  return false;
                                },
                                child: PageView.builder(
                                  controller: _controller,
                                  itemCount:
                                      widget.lastPage - widget.firstPage + 1,
                                  onPageChanged: (index) =>
                                      _onPage(widget.firstPage + index),
                                  itemBuilder: (context, index) => QcfPage(
                                    pageNumber: widget.firstPage + index,
                                    sp: 0.82,
                                    h: 1.14,
                                    theme: theme,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'الصفحة السابقة',
                          onPressed: _page > widget.firstPage || _isLimitedReading
                              ? () => _jump(_page - 1) : null,
                          icon: Icon(Icons.chevron_right, color: foreground),
                        ),
                        Text('$_page / 604', style: TextStyle(
                          color: foreground, fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'الصفحة التالية',
                          onPressed: _page < widget.lastPage || _isLimitedReading
                              ? () => _jump(_page + 1) : null,
                          icon: Icon(Icons.chevron_left, color: foreground),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _QcfMushafIndex extends StatefulWidget {
  const _QcfMushafIndex();

  @override
  State<_QcfMushafIndex> createState() => _QcfMushafIndexState();
}

class _QcfMushafIndexState extends State<_QcfMushafIndex> {
  static const _green = Color(0xFF073E35);
  static const _beige = Color(0xFFF7F1E4);
  static const _juzPages = <int>[
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582
  ];

  bool _showJuz = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim();
    final surahs = List<int>.generate(114, (i) => i + 1)
      .where((n) => getSurahNameArabic(n).contains(query) ||
          n.toString() == query || query.isEmpty).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _beige,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text('فهرس المصحف'),
          centerTitle: true,
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('السور')),
                ButtonSegment(value: true, label: Text('الأجزاء')),
              ],
              selected: {_showJuz},
              onSelectionChanged: (v) => setState(() => _showJuz = v.first),
            ),
          ),
          if (!_showJuz)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ابحث عن سورة',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _showJuz ? 30 : surahs.length,
              itemBuilder: (context, index) {
                final number = _showJuz ? index + 1 : surahs[index];
                final page = _showJuz
                    ? _juzPages[index] : getPageNumber(number, 1);
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(_showJuz
                        ? 'الجزء $number' : 'سورة ${getSurahNameArabic(number)}',
                        style: const TextStyle(
                          color: _green, fontWeight: FontWeight.w700)),
                    subtitle: Text('صفحة $page'),
                    leading: CircleAvatar(
                      backgroundColor: _beige,
                      child: Text('$number',
                          style: const TextStyle(color: _green))),
                    trailing: const Icon(Icons.chevron_left, color: _green),
                    onTap: () => Navigator.of(context).pop(page),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
