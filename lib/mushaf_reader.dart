import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF063F32);
const _gold = Color(0xFFC5A052);
const _paper = Color(0xFFFFF8E7);

class MushafPageReader extends StatefulWidget {
  const MushafPageReader({super.key, required this.initialPage, this.firstPage = 1, this.lastPage = 604, this.onPage});
  final int initialPage, firstPage, lastPage;
  final ValueChanged<int>? onPage;
  @override
  State<MushafPageReader> createState() => _MushafPageReaderState();
}

class _MushafPageReaderState extends State<MushafPageReader> {
  late final PageController controller;
  int page = 1;
  bool controls = false;
  bool night = false;
  bool eyeComfort = false;
  List<dynamic> surahs = [];
  int? bookmarkedPage;
  bool zoomed = false;
  bool enlargedMode = false;
  bool fullScreen = false;
  final TransformationController zoomController = TransformationController();

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(widget.firstPage, widget.lastPage);
    controller = PageController(initialPage: page - widget.firstPage);
    _loadIndex();
    _restoreBookmark();
    _restoreMode();
    _restoreEyeComfort();
  }

  Future<void> _restoreEyeComfort() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => eyeComfort = prefs.getBool('quran_eye_comfort') ?? false);
  }

  Future<void> _toggleEyeComfort() async {
    final next = !eyeComfort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_eye_comfort', next);
    if (mounted) setState(() => eyeComfort = next);
  }

  Future<void> _restoreBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => bookmarkedPage = prefs.getInt('mushaf_bookmark_page'));
  }

  Future<void> _restoreMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => enlargedMode = prefs.getBool('mushaf_large_mode') ?? false);
  }

  Future<void> _setMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mushaf_large_mode', value);
    if (!mounted) return;
    zoomController.value = Matrix4.identity();
    setState(() { enlargedMode = value; zoomed = false; });
  }

  Future<void> _toggleFullScreen() async {
    final next = !fullScreen;
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() { fullScreen = next; controls = !next; });
  }

  Future<void> _bookmark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_bookmark_page', page);
    if (mounted) setState(() => bookmarkedPage = page);
  }

  void _changeZoom(double factor) {
    final current = zoomController.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 5.0);
    final size = MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height / 2);
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    zoomController.value = matrix;
    setState(() => zoomed = next > 1.01);
  }

  void _resetZoom() {
    zoomController.value = Matrix4.identity();
    setState(() => zoomed = false);
  }

  void _jump(int value) {
    controller.animateToPage(value.clamp(widget.firstPage, widget.lastPage) - widget.firstPage,
      duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  Future<void> _chooseJuz() async {
    const starts = [
      1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
      201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
      402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
    ];
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .72,
        child: ListView.builder(
          itemCount: starts.length,
          itemBuilder: (ctx, i) => ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('الجزء ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: Text('صفحة ${starts[i]}'),
            onTap: () => Navigator.pop(ctx, starts[i]),
          ),
        ),
      )),
    );
    if (selected != null) _jump(selected);
  }

  Future<void> _choosePage() async {
    final result = await showDialog<int>(context: context, builder: (ctx) {
      var value = page;
      return StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('الصفحة $value من 604'),
          Slider(value: value.toDouble(), min: 1, max: 604, divisions: 603,
            onChanged: (v) => update(() => value = v.round())),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, value),
          child: const Text('انتقال'))]));
    });
    if (result != null) _jump(result);
  }

  Future<void> _chooseSurah() async {
    final result = await showModalBottomSheet<int>(context: context,
      isScrollControlled: true, builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .72,
        child: ListView.builder(itemCount: surahs.length, itemBuilder: (ctx, i) {
          final item = surahs[i];
          return ListTile(title: Text('سورة ${item['name']}'),
            trailing: Text('ص ${item['page']}'),
            onTap: () => Navigator.pop(ctx, item['page'] as int));
        }))));
    if (result != null) _jump(result);
  }

  Future<void> _loadIndex() async {
    final data = jsonDecode(await rootBundle.loadString('assets/mushaf/surah_pages.json'));
    if (mounted) setState(() => surahs = data as List<dynamic>);
  }

  Future<void> _savePage(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('mushaf_last_page', value);
    if (!mounted) return;
    setState(() => page = value);
  }

  String get surahName {
    String name = 'القرآن الكريم';
    for (final entry in surahs) {
      if ((entry['page'] as int) > page) break;
      name = 'سورة ${entry['name']}';
    }
    return name;
  }

  @override
  void dispose() {
    if (fullScreen) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    controller.dispose();
    zoomController.dispose();
    super.dispose();
  }

  Widget _overlayAction(IconData icon, String label, VoidCallback action) =>
    InkWell(onTap: action, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 27),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ])));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: night ? const Color(0xFF10241F) : _green,
    appBar: null,
    body: Stack(children: [
        Positioned.fill(child: Directionality(textDirection: TextDirection.rtl, child: PageView.builder(
          controller: controller,
          reverse: false,
          physics: zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          itemCount: widget.lastPage - widget.firstPage + 1,
          onPageChanged: (index) {
            zoomController.value = Matrix4.identity();
            if (zoomed) setState(() => zoomed = false);
            _savePage(widget.firstPage + index);
            widget.onPage?.call(widget.firstPage + index);
          },
          itemBuilder: (context, index) {
            final child = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => controls = !controls),
              child: InteractiveViewer(
                transformationController: index + widget.firstPage == page ? zoomController : null,
                minScale: 1, maxScale: 5,
                panEnabled: zoomed,
                onInteractionEnd: (_) {
                  if (index + widget.firstPage != page) return;
                  final active = zoomController.value.getMaxScaleOnAxis() > 1.01;
                  if (mounted && zoomed != active) setState(() => zoomed = active);
                },
                child: SizedBox.expand(child: ColoredBox(color: _paper,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      eyeComfort ? const Color(0xFFF2E1C0) : Colors.white,
                      BlendMode.multiply),
                    child: Image.asset('assets/mushaf/${(index + widget.firstPage).toString().padLeft(3, '0')}.webp',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stack) =>
                      const Center(child: Text('تعذر فتح صفحة المصحف')))))),
              ),
            );
            return child;
          },
        ))),
        if (controls) Positioned(top: 74, left: 12, right: 12,
          child: SafeArea(bottom: false, child: Material(
            color: const Color(0xEC063F32),
            borderRadius: BorderRadius.circular(18),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(tooltip: eyeComfort ? 'إيقاف راحة العين' : 'راحة العين',
                  onPressed: _toggleEyeComfort,
                  icon: Icon(eyeComfort ? Icons.visibility : Icons.visibility_outlined, color: _gold)),
                IconButton(tooltip: 'تكبير', onPressed: () => _changeZoom(1.35),
                  icon: const Icon(Icons.zoom_in, color: Colors.white)),
                IconButton(tooltip: 'تصغير', onPressed: () => _changeZoom(1 / 1.35),
                  icon: const Icon(Icons.zoom_out, color: Colors.white)),
                IconButton(tooltip: 'إعادة ضبط', onPressed: _resetZoom,
                  icon: const Icon(Icons.center_focus_strong, color: Colors.white)),
                IconButton(tooltip: fullScreen ? 'إلغاء ملء الشاشة' : 'ملء الشاشة',
                  onPressed: _toggleFullScreen,
                  icon: Icon(fullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white)),
                IconButton(tooltip: 'تغيير وضع القراءة',
                  onPressed: () => _setMode(!enlargedMode),
                  icon: Icon(enlargedMode ? Icons.menu_book : Icons.text_fields, color: _gold)),
              ])),
          ))),
        if (controls) Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(bottom: false, child: Container(color: const Color(0xD9000000), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Column(children: [
                Text(surahName, style: const TextStyle(color: Colors.white, fontSize: 20)),
                Text('الصفحة $page من ${widget.lastPage}', style: const TextStyle(color: _gold)),
              ])),
              IconButton(icon: const Icon(Icons.brightness_6, color: Colors.white),
                onPressed: () => setState(() => night = !night)),
            ])))),
        if (controls) Positioned(bottom: 0, left: 0, right: 0, child: SafeArea(top: false, child: Container(
          margin: const EdgeInsets.fromLTRB(9, 4, 9, 7),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xE9000000),
            border: Border.all(color: _gold, width: .5)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _overlayAction(Icons.menu_book, 'الفهرس', _chooseSurah),
              _overlayAction(Icons.layers, 'الأجزاء', _chooseJuz),
              _overlayAction(Icons.article_outlined, 'الصفحات', _choosePage),
              _overlayAction(Icons.search, 'بحث', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('البحث في النص متاح من فهرس القرآن')));
              }),
            ]),
            const Divider(color: _gold),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _overlayAction(Icons.bookmark_add_outlined, 'حفظ علامة', _bookmark),
              _overlayAction(Icons.bookmark, 'العلامة', () {
                if (bookmarkedPage != null) _jump(bookmarkedPage!);
              }),
              _overlayAction(Icons.chevron_right, 'السابق', () => _jump(page - 1)),
              _overlayAction(Icons.chevron_left, 'التالي', () => _jump(page + 1)),
            ]),
          ]),
        ))),
      ]),
  );
}
