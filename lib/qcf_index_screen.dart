import 'package:flutter/material.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart';

/// QCF-native index built from the package's bundled surah/page metadata.
/// Returns the chosen page so the existing reader can navigate in place.
class QcfIndexScreen extends StatefulWidget {
  const QcfIndexScreen({super.key});

  @override
  State<QcfIndexScreen> createState() => _QcfIndexScreenState();
}

class _QcfIndexScreenState extends State<QcfIndexScreen> {
  static const _green = Color(0xFF073E35);
  static const _gold = Color(0xFFD6B56C);
  static const _beige = Color(0xFFF7F1E4);
  static const _ink = Color(0xFF29231E);
  static const _juzPages = <int>[
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
    201, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582
  ];

  String _search = '';
  int _tab = 0;

  void _choosePage(int page) => Navigator.of(context).pop(page);

  @override
  Widget build(BuildContext context) {
    final query = _search.trim();
    final surahNumbers = List<int>.generate(114, (i) => i + 1)
        .where((n) => getSurahNameArabic(n).contains(query) ||
            n.toString() == query || query.isEmpty)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _beige,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text('فهرس المصحف',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            Container(
              color: _green,
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: Row(
                children: [
                  Expanded(child: _tabButton('السور', 0)),
                  const SizedBox(width: 9),
                  Expanded(child: _tabButton('الأجزاء', 1)),
                ],
              ),
            ),
            if (_tab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: TextField(
                  textDirection: TextDirection.rtl,
                  onChanged: (value) => setState(() => _search = value),
                  style: const TextStyle(color: _ink, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اسم السورة أو رقمها',
                    prefixIcon: const Icon(Icons.search, color: _green),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0D2B7))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0D2B7))),
                  ),
                ),
              ),
            Expanded(
              child: _tab == 0
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 9, 14, 18),
                      itemCount: surahNumbers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = surahNumbers[index];
                        final page = getPageNumber(n, 1);
                        return _entry(
                          number: n,
                          title: 'سورة ${getSurahNameArabic(n)}',
                          detail: '${getVerseCount(n)} آية  •  صفحة $page',
                          onTap: () => _choosePage(page),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                      itemCount: 30,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = index + 1;
                        final page = _juzPages[index];
                        return _entry(
                          number: n,
                          title: 'الجزء $n',
                          detail: 'يبدأ من صفحة $page',
                          onTap: () => _choosePage(page),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String text, int value) => Material(
    color: _tab == value ? _gold : const Color(0xFF1D5749),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() => _tab = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(text, textAlign: TextAlign.center,
          style: TextStyle(
            color: _tab == value ? _ink : Colors.white,
            fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    ),
  );

  Widget _entry({
    required int number,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE1D6BE))),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _beige,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold)),
              child: Text('$number',
                style: const TextStyle(color: _green,
                    fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(color: _ink,
                        fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(detail,
                    style: const TextStyle(color: Color(0xFF686156),
                        fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: _green),
          ],
        ),
      ),
    ),
  );
}
