import 'package:flutter/material.dart';
import 'package:flutter_quran/flutter_quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight, native Flutter Quran reader. Kept isolated from app startup.
/// Retains the existing saved page/bookmark keys used by other Athr screens.
class AthrFlutterQuranReader extends StatefulWidget {
  const AthrFlutterQuranReader({
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
  State<AthrFlutterQuranReader> createState() => _AthrFlutterQuranReaderState();
}

class _AthrFlutterQuranReaderState extends State<AthrFlutterQuranReader> {
  static const _green = Color(0xFF073E35);
  static const _gold = Color(0xFFD6B56C);
  static Future<void>? _initialization;

  late final Future<void> _ready;
  int _page = 1;
  int? _bookmark;

  @override
  void initState() {
    super.initState();
    _ready = _prepare();
  }

  Future<void> _prepare() async {
    // Lazy initialization: opening the memorial/prayer heart must never
    // depend on the Quran package successfully loading.
    _initialization ??= FlutterQuran().init();
    await _initialization;
    final prefs = await SharedPreferences.getInstance();
    final page = (widget.initialPage ??
        prefs.getInt('react_quran_last_page') ??
        widget.firstPage).clamp(widget.firstPage, widget.lastPage).toInt();
    FlutterQuran().navigateToPage(page);
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmark = prefs.getInt('react_quran_bookmark');
    });
  }

  void _onPageChanged(int pageIndex) {
    // Package callback uses a page index; query the public 1-based page
    // number API to avoid an index mismatch when saving reading progress.
    final current = FlutterQuran().getCurrentPageNumber();
    final page = current >= 1 && current <= 604
        ? current
        : (pageIndex + 1).clamp(1, 604).toInt();
    if (page < widget.firstPage || page > widget.lastPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FlutterQuran().navigateToPage(
              page < widget.firstPage ? widget.firstPage : widget.lastPage);
        }
      });
      return;
    }
    if (!mounted) return;
    setState(() => _page = page);
    widget.onPage?.call(page);
    SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('react_quran_last_page', page));
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (_bookmark == _page) {
      await prefs.remove('react_quran_bookmark');
      if (mounted) setState(() => _bookmark = null);
    } else {
      await prefs.setInt('react_quran_bookmark', _page);
      if (mounted) setState(() => _bookmark = _page);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, state) {
      if (state.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('المصحف الشريف')),
          body: const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('تعذر فتح المصحف. أعد المحاولة.',
                textAlign: TextAlign.center),
          )),
        );
      }
      if (state.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(
          child: CircularProgressIndicator(color: _green),
        ));
      }
      // Package 0.0.5 explicitly opts out of Material 3 for its Quran
      // typography; scope it to the reader instead of changing Athr.
      return Theme(
        data: Theme.of(context).copyWith(useMaterial3: false),
        child: FlutterQuranScreen(
          useDefaultAppBar: false,
          appBar: AppBar(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            title: Text('المصحف الشريف • صفحة $_page',
                style: const TextStyle(fontSize: 16)),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'حفظ علامة الصفحة',
                onPressed: _toggleBookmark,
                icon: Icon(
                  _bookmark == _page ? Icons.bookmark : Icons.bookmark_border,
                  color: _gold,
                ),
              ),
              if (_bookmark != null)
                IconButton(
                  tooltip: 'العودة إلى العلامة',
                  icon: const Icon(Icons.bookmarks_outlined, color: _gold),
                  onPressed: () => FlutterQuran().navigateToPage(_bookmark!),
                ),
            ],
          ),
          onPageChanged: _onPageChanged,
        ),
      );
    },
  );
}
