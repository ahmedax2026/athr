import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Experimental integration with the author's react-quran demo.
/// This preview needs internet; an offline React bundle is a separate step.
class ReactQuranPreview extends StatefulWidget {
  const ReactQuranPreview({super.key});

  @override
  State<ReactQuranPreview> createState() => _ReactQuranPreviewState();
}

class _ReactQuranPreviewState extends State<ReactQuranPreview> {
  late final WebViewController controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFF8E9))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { loading = true; error = null; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => loading = false);
        },
        onWebResourceError: (failure) {
          if (failure.isForMainFrame == true && mounted) {
            setState(() { loading = false; error = failure.description; });
          }
        },
      ))
      ..loadRequest(Uri.parse('https://react-quran1.vercel.app/'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF8E9),
    appBar: AppBar(
      backgroundColor: const Color(0xFF073E35),
      foregroundColor: Colors.white,
      title: const Text('تجربة مصحف React'),
      actions: [
        IconButton(
          tooltip: 'إعادة التحميل',
          onPressed: () => controller.reload(),
          icon: const Icon(Icons.refresh)),
      ],
    ),
    body: Stack(children: [
      WebViewWidget(controller: controller),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null)
        Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 44),
            const SizedBox(height: 12),
            const Text('تعذر تحميل التجربة. تأكد من الاتصال بالإنترنت.'),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => controller.reload(),
              child: const Text('إعادة المحاولة')),
          ]),
        )),
    ]),
  );
}
