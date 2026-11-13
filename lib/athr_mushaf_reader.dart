import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Native Mushaf reader. No React, WebView or network request is used for reading.
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
  static const Color _emerald = Color(0xFF073E35);
  static const Color _gold = Color(0xFFD6B56C);
  static const Color _paper = Color(0xFFFFFCF4);
  static const Color _comfortPaper = Color(0xFFF0E6D1);
  static const Color _comfortInk = Color(0xFF413C31);

  bool _eyeComfort = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final page = (widget.initialPage ??
            prefs.getInt('react_quran_last_page') ??
            1)
        .clamp(widget.firstPage, widget.lastPage).toInt();
    // The library remembers its own reading position; jump explicitly
    // when entering from Athr's page, surah, bookmark or juz menus.
    QuranLibrary().jumpToPage(page);
    if (!mounted) return;
    setState(() {
      _eyeComfort = prefs.getBool('athr_mushaf_eye_comfort') ?? false;
      _loaded = true;
    });
  }

  Future<void> _pageChanged(int page) async {
    widget.onPage?.call(page);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('react_quran_last_page', page);
  }

  Future<void> _toggleComfort() async {
    final value = !_eyeComfort;
    setState(() => _eyeComfort = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('athr_mushaf_eye_comfort', value);
  }

  @override
  Widget build(BuildContext context) {
    final paper = _eyeComfort ? _comfortPaper : _paper;
    final ink = _eyeComfort ? _comfortInk : _emerald;
    return Theme(
      // The library requests Material 2 for correct Mushaf shaping.
      // Limit this override to the reader, not the rest of Athr.
      data: Theme.of(context).copyWith(
        useMaterial3: false,
        scaffoldBackgroundColor: paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: _emerald,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: paper,
        appBar: AppBar(
          backgroundColor: _emerald,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text('المصحف الشريف',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: _eyeComfort ? 'إيقاف راحة العين' : 'تفعيل راحة العين',
              icon: Icon(_eyeComfort
                  ? Icons.visibility
                  : Icons.visibility_outlined,
                color: _eyeComfort ? _gold : Colors.white),
              onPressed: _toggleComfort,
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator(color: _emerald))
            : ColoredBox(
                color: paper,
                child: widget.firstPage != 1 || widget.lastPage != 604
                    ? QuranPagesScreen(
                        key: ValueKey('juz-${widget.firstPage}-${widget.lastPage}-$_eyeComfort'),
                        parentContext: context,
                        startPage: widget.firstPage,
                        endPage: widget.lastPage,
                        withPageView: true,
                        onPageChanged: _pageChanged,
                        backgroundColor: paper,
                        textColor: ink,
                        useDefaultAppBar: false,
                      )
                    : QuranLibraryScreen(
                        key: ValueKey('mushaf-$_eyeComfort'),
                        parentContext: context,
                        withPageView: true,
                        useDefaultAppBar: false,
                        onPageChanged: _pageChanged,
                        isDark: false,
                        backgroundColor: paper,
                        textColor: ink,
                      ),
              ),
      ),
    );
  }
}
