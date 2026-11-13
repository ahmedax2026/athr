import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Locally bundled react-quran. No network or external website is needed.
class ReactQuranPreview extends StatefulWidget {
  const ReactQuranPreview({super.key, this.initialPage});
  final int? initialPage;

  @override
  State<ReactQuranPreview> createState() => _ReactQuranPreviewState();
}

class _ReactQuranPreviewState extends State<ReactQuranPreview> {
  late final WebViewController controller;
  bool loading = true;
  String? error;
  int page = 1;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    page = (widget.initialPage ?? prefs.getInt('react_quran_last_page') ?? 1).clamp(1, 604);
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFF8E9))
      ..addJavaScriptChannel('ReactQuranBridge', onMessageReceived: (message) async {
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          if (data['type'] == 'page' && data['page'] is num) {
            final next = ((data['page'] as num).toInt()).clamp(1, 604);
            page = next;
            await prefs.setInt('react_quran_last_page', next);
          }
        } catch (_) { /* Ignore malformed page events. */ }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) async {
          try {
            await controller.runJavaScript('window.setQuranPage && window.setQuranPage($page)');
          } catch (_) { /* Show bundled page even if JS bridge is unavailable. */ }
          if (mounted) setState(() => loading = false);
        },
        onWebResourceError: (failure) {
          if (failure.isForMainFrame == true && mounted) {
            setState(() { loading = false; error = failure.description; });
          }
        },
      ));
    if (!mounted) return;
    setState(() {});
    try {
      await controller.loadFlutterAsset('assets/react_quran/index.html');
    } catch (failure) {
      if (mounted) setState(() { loading = false; error = '$failure'; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8E9),
    appBar: AppBar(
      backgroundColor: const Color(0xFF073E35),
      foregroundColor: Colors.white,
      title: const Text('المصحف العثماني'),
      actions: [
        IconButton(
          tooltip: 'إعادة التحميل',
          onPressed: () => controller.reload(),
          icon: const Icon(Icons.refresh)),
      ],
    ),
    body: Stack(children: [
      if (!loading || error == null) WebViewWidget(controller: controller),
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
