import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'quran.dart';

/// Locally bundled react-quran. No network or external website is needed.
class ReactQuranPreview extends StatefulWidget {
  const ReactQuranPreview({super.key, this.initialPage});
  final int? initialPage;

  @override
  State<ReactQuranPreview> createState() => _ReactQuranPreviewState();
}

class _ReactQuranPreviewState extends State<ReactQuranPreview> {
  WebViewController? controller;
  bool loading = true;
  bool readerReady = false;
  double zoom = 1.0;
  int? bookmark;
  String? error;
  int page = 1;
  bool darkReading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    darkReading = prefs.getBool('ottoman_mushaf_dark') ?? true;
    page = (widget.initialPage ?? prefs.getInt('react_quran_last_page') ?? 1).clamp(1, 604);
    zoom = (prefs.getDouble('react_quran_zoom') ?? 1.0).clamp(0.8, 1.8);
    bookmark = prefs.getInt('react_quran_bookmark');
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
            if (mounted) setState(() { loading = false; error = null; });
          }
          if (data['type'] == 'page' && data['page'] is num) {
            final next = ((data['page'] as num).toInt()).clamp(1, 604);
            if (mounted) setState(() => page = next);
            await prefs.setInt('react_quran_last_page', next);
          }
        } catch (_) { /* Ignore malformed page events. */ }
      });
    await web.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          try {
            await web.runJavaScript('window.setQuranPage && window.setQuranPage($page)');
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

  Future<void> _applyReadingTheme() async {
    final web = controller;
    if (web == null) return;
    final background = darkReading ? '#193B30' : '#FFF8E9';
    final foreground = darkReading ? '#F7EBD3' : '#17372E';
    await web.setBackgroundColor(darkReading
        ? const Color(0xFF193B30) : const Color(0xFFFFF8E9));
    try {
      await web.runJavaScript("""
        (() => {
          let style = document.getElementById('athr-ottoman-theme');
          if (!style) {
            style = document.createElement('style');
            style.id = 'athr-ottoman-theme';
            document.head.appendChild(style);
          }
          style.textContent = 'html, body, #root, .reader, .reader > div {' +
            'background-color: $background !important; color: $foreground !important;}' +
            '.reader, .reader *:not(button):not(input) {' +
            'color: $foreground !important;}' +
            '.reader svg text, .reader svg tspan { fill: $foreground !important; }';
        })();
      """);
    } catch (_) { /* Keep the reader usable if styling injection fails. */ }
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
        "document.querySelector('.reader > div')?.style.setProperty('zoom', '$zoom')");
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
    backgroundColor: darkReading ? const Color(0xFF193B30) : const Color(0xFFFFF8E9),
    appBar: AppBar(
      backgroundColor: const Color(0xFF073E35),
      foregroundColor: Colors.white,
      title: Text('$page / 604'),
      actions: [
        IconButton(
          tooltip: darkReading ? 'الوضع الفاتح' : 'الوضع الأخضر الداكن',
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
    ]),
  );
}
