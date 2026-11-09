import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuranService {
  static Future<dynamic> fetch(String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('https://api.alquran.cloud/v1/$path'));
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const HttpException('تعذر تحميل القرآن');
      final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      if (json['code'] != 200) throw const FormatException('بيانات غير متاحة');
      return json['data'];
    } finally {
      client.close(force: true);
    }
  }
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late final Future<List<dynamic>> surahs = QuranService.fetch('surah').then(
    (value) => value as List<dynamic>);
  String search = '';
  int? lastSurah;
  int? lastAyah;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      lastSurah = prefs.getInt('quran_last_surah');
      lastAyah = prefs.getInt('quran_last_ayah');
    });
  }

  void openSurah(int number, String name, {int? scrollTo}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QuranSurahScreen(number: number, name: name, initialAyah: scrollTo)));
    loadProgress();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('القرآن الكريم')),
    body: FutureBuilder<List<dynamic>>(
      future: surahs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تعذر تحميل السور. تأكد من اتصال الإنترنت.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => setState(() {}), child: const Text('حاول مجددًا')),
          ]));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final filtered = all.where((item) {
          final surah = item as Map<String, dynamic>;
          return (surah['name'] as String).contains(search) ||
            (surah['number'] as int).toString() == search;
        }).toList();
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(color: const Color(0xFF0B4A3C), child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.menu_book_rounded, color: Color(0xFFD6B56C), size: 42),
                const SizedBox(height: 8),
                const Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(color: Color(0xFFF5EBD5), fontSize: 23)),
                const SizedBox(height: 7),
                const Text('اقرأ وارتقِ', style: TextStyle(color: Color(0xFFD6B56C), fontSize: 16)),
                if (lastSurah != null && lastSurah! >= 1 && lastSurah! <= all.length)
                  Padding(padding: const EdgeInsets.only(top: 14),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF5EBD5)),
                      onPressed: () => openSurah(lastSurah!,
                        (all[lastSurah! - 1] as Map<String, dynamic>)['name'].toString(),
                        scrollTo: lastAyah),
                      icon: const Icon(Icons.bookmark),
                      label: Text('متابعة القراءة: ${(all[lastSurah! - 1] as Map<String, dynamic>)['name']} - آية ${lastAyah ?? 1}'),
                    )),
              ]),
            )),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => search = value.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث باسم السورة أو رقمها',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            Text('سور القرآن الكريم (${filtered.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final item in filtered)
              Builder(builder: (context) {
                final surah = item as Map<String, dynamic>;
                final number = surah['number'] as int;
                final name = surah['name'].toString();
                return Card(child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0B4A3C),
                    child: Text('$number', style: const TextStyle(color: Color(0xFFD6B56C))),
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  subtitle: Text('${surah['numberOfAyahs']} آية • ${surah['revelationType'] == 'Meccan' ? 'مكية' : 'مدنية'}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => openSurah(number, name),
                ));
              }),
          ]),
        ));
      },
    ),
  );
}

class QuranSurahScreen extends StatefulWidget {
  const QuranSurahScreen({super.key, required this.number, required this.name, this.initialAyah});
  final int number;
  final String name;
  final int? initialAyah;
  @override
  State<QuranSurahScreen> createState() => _QuranSurahScreenState();
}

class _QuranSurahScreenState extends State<QuranSurahScreen> {
  late final Future<Map<String, dynamic>> surah = QuranService.fetch('surah/${widget.number}/ar.alafasy')
    .then((value) => value as Map<String, dynamic>);
  final ScrollController scroll = ScrollController();
  double fontSize = 25;
  int? selectedAyah;

  @override
  void initState() {
    super.initState();
    selectedAyah = widget.initialAyah;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> bookmark(int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_surah', widget.number);
    await prefs.setInt('quran_last_ayah', ayah);
    if (mounted) {
      setState(() => selectedAyah = ayah);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ موضع القراءة عند الآية $ayah')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name), actions: [
      IconButton(tooltip: 'تصغير الخط', onPressed: fontSize <= 20 ? null :
        () => setState(() => fontSize -= 2), icon: const Icon(Icons.text_decrease)),
      IconButton(tooltip: 'تكبير الخط', onPressed: fontSize >= 37 ? null :
        () => setState(() => fontSize += 2), icon: const Icon(Icons.text_increase)),
    ]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: surah,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل السورة. تأكد من الإنترنت.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final ayahs = snapshot.data!['ayahs'] as List<dynamic>;
        return Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: ListView(controller: scroll, padding: const EdgeInsets.all(18), children: [
            Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF0B4A3C),
                borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Text(widget.name, style: const TextStyle(color: Color(0xFFD6B56C),
                  fontSize: 28, fontWeight: FontWeight.bold)),
                if (widget.number != 1 && widget.number != 9)
                  const Padding(padding: EdgeInsets.only(top: 12),
                    child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      style: TextStyle(color: Color(0xFFF5EBD5), fontSize: 22))),
              ])),
            const SizedBox(height: 14),
            for (final item in ayahs)
              Builder(builder: (context) {
                final ayah = item as Map<String, dynamic>;
                final number = ayah['numberInSurah'] as int;
                return Card(
                  color: selectedAyah == number ? const Color(0xFFFFE8B3) :
                    Theme.of(context).cardColor,
                  child: Padding(padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(ayah['text'].toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: fontSize, height: 2.05,
                          color: selectedAyah == number ? const Color(0xFF173C32) : null)),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('الآية $number', style: TextStyle(
                          color: selectedAyah == number ? const Color(0xFF173C32) : null)),
                        TextButton.icon(
                          onPressed: () => bookmark(number),
                          icon: Icon(selectedAyah == number ? Icons.bookmark : Icons.bookmark_border),
                          label: const Text('حفظ موضع القراءة')),
                      ]),
                    ]),
                  ),
                );
              }),
          ]),
        ));
      },
    ),
  );
}
