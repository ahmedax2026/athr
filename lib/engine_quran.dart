import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _paper = Color(0xFFFFF8E9);

/// Quran pages are rendered by the QCF package, never by custom HTML spans.
class EngineQuranScreen extends StatefulWidget {
  const EngineQuranScreen({super.key, this.initialPage});
  final int? initialPage;

  @override
  State<EngineQuranScreen> createState() => _EngineQuranScreenState();
}

class _EngineQuranScreenState extends State<EngineQuranScreen> {
  late final PageController _controller;
  late int _page;
  bool _tajweed = true;
  late final Future<void> _fontsReady;

  @override
  void initState() {
    super.initState();
    _fontsReady = QcfFontLoader.setupFontsAtStartup();
    _page = (widget.initialPage ?? 1).clamp(1, 604);
    _controller = PageController(initialPage: _page - 1);
    if (widget.initialPage == null) _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getInt('qcf_last_page') ?? 1).clamp(1, 604);
    if (!mounted) return;
    setState(() => _page = saved);
    if (_controller.hasClients) {
      _controller.jumpToPage(saved - 1);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(saved - 1);
        }
      });
    }
  }

  Future<void> _onPageChanged(int page) async {
    if (!mounted) return;
    setState(() => _page = page);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('qcf_last_page', page);
  }

  Future<void> _showIndex() async {
    var query = '';
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matches = <int>[
            for (var n = 1; n <= 114; n++)
              if (getSurahNameArabic(n).contains(query) ||
                  n.toString() == query) n,
          ];
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .83,
              child: Column(children: [
                const SizedBox(height: 18),
                const Text('فهرس السور', style: TextStyle(
                  color: _green, fontSize: 25, fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    textDirection: TextDirection.rtl,
                    onChanged: (value) => update(() => query = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم السورة أو رقمها',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                Expanded(child: ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final number = matches[index];
                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _gold)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _green,
                          child: Text('$number', style: const TextStyle(
                            color: Colors.white))),
                        title: Text('سورة ${getSurahNameArabic(number)}',
                          style: const TextStyle(color: _green,
                            fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text('${getVerseCount(number)} آية'),
                        trailing: const Icon(Icons.chevron_left, color: _green),
                        onTap: () => Navigator.pop(context, number),
                      ),
                    );
                  },
                )),
              ]),
            ),
          );
        },
      ),
    );
    if (chosen == null || !mounted) return;
    final page = getPageNumber(chosen, 1);
    _controller.jumpToPage(page - 1);
    _onPageChanged(page);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text('المصحف • صفحة $_page',
          style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: _tajweed ? 'إخفاء ألوان التجويد' : 'إظهار ألوان التجويد',
            onPressed: () => setState(() => _tajweed = !_tajweed),
            icon: Icon(_tajweed ? Icons.palette : Icons.palette_outlined)),
          IconButton(
            tooltip: 'فهرس السور',
            onPressed: _showIndex,
            icon: const Icon(Icons.menu_book_outlined)),
        ],
      ),
      body: SafeArea(child: FutureBuilder<void>(
        future: _fontsReady,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذر تجهيز خطوط المصحف',
                  style: TextStyle(color: _green, fontSize: 19)),
                const SizedBox(height: 12),
                Text('${snapshot.error}', textAlign: TextAlign.center),
              ]),
            ));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _green),
                SizedBox(height: 16),
                Text('جاري تجهيز خطوط المصحف...',
                  style: TextStyle(color: _green)),
              ],
            ));
          }
          return QuranPageView(
            pageController: _controller,
            highlights: const <HighlightVerse>[],
            isDarkMode: isDark,
            isTajweed: _tajweed,
            enableTwoPageLayout: false,
            deferNewPages: false,
            pageBackgroundColor: _paper,
            onPageChanged: _onPageChanged,
          );
        },
      )),
    );
  }
}
