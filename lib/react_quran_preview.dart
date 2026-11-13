import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'quran.dart';

/// Locally bundled react-quran. No network or external website is needed.
class ReactQuranPreview extends StatefulWidget {
  const ReactQuranPreview({super.key, this.initialPage, this.firstPage = 1, this.lastPage = 604, this.onPage});
  final int? initialPage;
  final int firstPage, lastPage;
  final ValueChanged<int>? onPage;

  @override
  State<ReactQuranPreview> createState() => _ReactQuranPreviewState();
}

class _ReactQuranPreviewState extends State<ReactQuranPreview> {
  WebViewController? controller;
  bool loading = true;
  bool readerReady = false;
  bool readerConfigured = false;
  bool openingPageAcknowledged = false;
  double zoom = 1.0;
  int? bookmark;
  String? error;
  int page = 1;
  bool darkReading = false;
  String surahName = 'المصحف الشريف';
  int juzNumber = 1;
  static const _juzStarts = <int>[1,22,42,62,82,102,121,142,162,182,201,222,242,262,282,302,322,342,362,382,402,422,442,462,482,502,522,542,562,582];
  List<Map<String,dynamic>> _surahIndex = const [];
  void _updatePageCaption(int p) {
    String label = 'المصحف الشريف';
    for (final surah in _surahIndex) {
      final first = (surah['page'] as num?)?.toInt() ?? 1;
      if (first <= p) { label = surah['name']?.toString() ?? label; } else { break; }
    }
    surahName = label.startsWith('سورة') ? label : 'سورة $label';
    juzNumber = 1;
    for (var i=0; i<_juzStarts.length; i++) {
      if (p >= _juzStarts[i]) juzNumber = i+1;
    }
  }
  bool eyeComfort = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    darkReading = prefs.getBool('ottoman_mushaf_dark') ?? false;
    try {
      final decoded = jsonDecode(await rootBundle.loadString('assets/mushaf/surah_pages.json')) as List<dynamic>;
      _surahIndex = decoded.cast<Map<String, dynamic>>();
    } catch (_) { /* The Quran remains readable without index metadata. */ }
    eyeComfort = prefs.getBool('quran_eye_comfort') ?? false;
    page = (widget.initialPage ?? prefs.getInt('react_quran_last_page') ?? widget.firstPage).clamp(widget.firstPage, widget.lastPage);
    zoom = (prefs.getDouble('react_quran_zoom') ?? 1.0).clamp(0.8, 1.8);
    bookmark = prefs.getInt('react_quran_bookmark');
    _updatePageCaption(page);
    final web = WebViewController();
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.setBackgroundColor(darkReading ? const Color(0xFF193B30) : const Color(0xFFFFF8E9));
    await web.addJavaScriptChannel('ReactQuranBridge', onMessageReceived: (message) async {
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          if (data['type'] == 'error') {
            if (mounted) setState(() { loading = false; error = data['message']?.toString() ?? 'مشكلة في تشغيل المصحف'; });
          }
          if (data['type'] == 'ready') {
            readerReady = true;
            await _applyZoom();
            await _applyReadingTheme();
            await _configureReaderBounds();
            readerConfigured = true;
            if (mounted) setState(() { loading = false; error = null; });
          }
          if (data['type'] == 'partEnd' && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('انتهى الجزء. اضغط «أتممت قراءة الجزء» أسفل الصفحة.'),
              duration: Duration(seconds: 3)));
          }
          if (data['type'] == 'page' && data['page'] is num) {
            final reported = (data['page'] as num).toInt();
            // React initially renders page 1 before Flutter restores the
            // saved position. Never save that temporary startup page.
            if (!readerConfigured) return;
            if (!openingPageAcknowledged) {
              if (reported != page) return;
              openingPageAcknowledged = true;
            }
            final next = reported.clamp(widget.firstPage, widget.lastPage);
            if (reported != next) {
              await web.runJavaScript('window.setQuranPage && window.setQuranPage($next)');
            }
            if (mounted) setState(() { page = next; _updatePageCaption(next); });
            widget.onPage?.call(next);
            // Juz and khatma progress is tracked separately. Only normal
            // reading updates the main Quran resume position.
            if (widget.firstPage == 1 && widget.lastPage == 604 &&
                widget.onPage == null) {
              await prefs.setInt('react_quran_last_page', next);
            }
          }
        } catch (_) { /* Ignore malformed page events. */ }
      });
    await web.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          try {
            await _applyZoom();
            await _applyReadingTheme();
          } catch (_) { /* Show bundled page even if JS bridge is unavailable. */ }
          // Do not mistake a loaded HTML shell for a successfully rendered Quran.
          await Future<void>.delayed(const Duration(seconds: 3));
          if (mounted && !readerReady && error == null) {
            setState(() { loading = false; error = 'ملفات الصفحة اتفتحت، لكن نص المصحف لم يظهر. جرّب إعادة التحميل.'; });
          }
        },
        onWebResourceError: (failure) {
          if (failure.isForMainFrame == true && mounted) {
            setState(() { loading = false; error = failure.description; });
          }
        },
      ));
    if (!mounted) return;
    setState(() => controller = web);
    try {
      await web.loadFlutterAsset('assets/react_quran/index.html');
    } catch (failure) {
      if (mounted) setState(() { loading = false; error = '$failure'; });
    }
  }

  Future<void> _configureReaderBounds() async {
    final web = controller;
    if (web == null) return;
    try {
      await web.runJavaScript(
        'window.setQuranBounds && window.setQuranBounds(${widget.firstPage}, ${widget.lastPage})');
      await web.runJavaScript('window.setQuranPage && window.setQuranPage($page)');
    } catch (_) { /* Web reader has not initialized yet. */ }
  }

  Future<void> _applyReadingTheme() async {
    final web = controller;
    if (web == null) return;
    // The page is always light paper with dark Quran text. A previous
    // dark-theme override made the original cream page nearly illegible.
    final background = eyeComfort ? '#F1E4C6' : (darkReading ? '#E8D8BA' : '#FFF9EC');
    final foreground = eyeComfort ? '#332E25' : '#172820';
    await web.setBackgroundColor(eyeComfort
        ? const Color(0xFFF1E4C6) : (darkReading
          ? const Color(0xFFE8D8BA) : const Color(0xFFFFF9EC)));
    try {
      await web.runJavaScript("""
        (() => {
          let style = document.getElementById('athr-ottoman-theme');
          if (!style) {
            style = document.createElement('style');
            style.id = 'athr-ottoman-theme';
            document.head.appendChild(style);
          }
          style.textContent = 'html, body, #root, main, .reader, .page-surface {' +
            'background-color: $background !important; color: $foreground !important;}' +
            '.reader, .reader * { color: $foreground !important; }' +
            '.reader svg text, .reader svg tspan {' +
            'fill: $foreground !important; }';
        })();
      """);
    } catch (_) { /* Keep the reader usable if styling injection fails. */ }
  }

  Future<void> _toggleEyeComfort() async {
    setState(() => eyeComfort = !eyeComfort);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_eye_comfort', eyeComfort);
    await _applyReadingTheme();
  }

  Future<void> _toggleReadingTheme() async {
    setState(() => darkReading = !darkReading);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ottoman_mushaf_dark', darkReading);
    await _applyReadingTheme();
  }

  Future<void> _applyZoom() async {
    if (controller == null) return;
    try {
      await controller!.runJavaScript(
        'window.setQuranZoom && window.setQuranZoom($zoom)');
    } catch (_) {}
  }

  Future<void> _changeZoom(double delta) async {
    setState(() => zoom = (zoom + delta).clamp(0.8, 1.8));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('react_quran_zoom', zoom);
    await _applyZoom();
  }

  Future<void> _toggleBookmark() async {
    final next = bookmark == page ? null : page;
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove('react_quran_bookmark');
    } else {
      await prefs.setInt('react_quran_bookmark', next);
    }
    if (mounted) setState(() => bookmark = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: eyeComfort ? const Color(0xFFF1E4C6) : (darkReading ? const Color(0xFFE8D8BA) : const Color(0xFFFFF9EC)),
    appBar: AppBar(
      backgroundColor: const Color(0xFF073E35),
      foregroundColor: Colors.white,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(surahName, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        Text('الجزء $juzNumber • صفحة $page',
          style: const TextStyle(fontSize: 11, color: Color(0xFFE6D8B6))),
      ]),
      actions: [
        IconButton(
          tooltip: eyeComfort ? 'إيقاف راحة العين' : 'راحة العين',
          onPressed: _toggleEyeComfort,
          icon: Icon(eyeComfort ? Icons.visibility : Icons.visibility_outlined)),
        IconButton(
          tooltip: darkReading ? 'خلفية كريمية' : 'خلفية ورقية داكنة',
          onPressed: _toggleReadingTheme,
          icon: Icon(darkReading ? Icons.light_mode_outlined : Icons.dark_mode_outlined)),
        IconButton(
          tooltip: 'فهرس السور',
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => const QuranIndexScreen())),
          icon: const Icon(Icons.list_alt)),
        IconButton(
          tooltip: 'تصغير',
          onPressed: zoom <= 0.8 ? null : () => _changeZoom(-0.1),
          icon: const Icon(Icons.zoom_out)),
        IconButton(
          tooltip: 'تكبير',
          onPressed: zoom >= 1.8 ? null : () => _changeZoom(0.1),
          icon: const Icon(Icons.zoom_in)),
        IconButton(
          tooltip: bookmark == page ? 'إزالة العلامة' : 'حفظ العلامة',
          onPressed: _toggleBookmark,
          icon: Icon(bookmark == page ? Icons.bookmark : Icons.bookmark_border)),
      ],
    ),
    body: Stack(children: [
      if (controller != null && error == null) WebViewWidget(controller: controller!),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null)
        Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            const Text('تعذر عرض المصحف المحلي'),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
          ]),
        )),
      if ((widget.firstPage != 1 || widget.lastPage != 604) && page == widget.lastPage && !loading && error == null)
        Positioned(bottom: 18, left: 16, right: 16,
          child: SafeArea(top: false, child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('أتممت قراءة الجزء')))),
    ]),
  );
}
