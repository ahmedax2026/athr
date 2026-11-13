import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _paper = Color(0xFFFFF8E9);

class Dhikr {
  const Dhikr(this.text, this.target, this.source);
  final String text;
  final int target;
  final String source;
}
const _groups = <String, List<Dhikr>>{
  'أذكار الصباح': [
    Dhikr('آيَةُ الْكُرْسِيِّ: اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ', 1, 'سورة البقرة: 255'),
    Dhikr('قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ', 3, 'سورة الإخلاص'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ', 3, 'سورة الفلق'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ', 3, 'سورة الناس'),
    Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100, 'صحيح مسلم'),
    Dhikr('رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا', 3, 'أبو داود والترمذي'),
  ],
  'أذكار المساء': [
    Dhikr('قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ', 3, 'سورة الإخلاص'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ', 3, 'سورة الفلق'),
    Dhikr('قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ', 3, 'سورة الناس'),
    Dhikr('أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ', 3, 'صحيح مسلم'),
    Dhikr('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100, 'صحيح مسلم'),
  ],
  'أذكار بعد الصلاة': [
    Dhikr('أَسْتَغْفِرُ اللَّهَ', 3, 'صحيح مسلم'),
    Dhikr('اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ', 1, 'صحيح مسلم'),
    Dhikr('سُبْحَانَ اللَّهِ', 33, 'الصحيحان'),
    Dhikr('الْحَمْدُ لِلَّهِ', 33, 'الصحيحان'),
    Dhikr('اللَّهُ أَكْبَرُ', 33, 'الصحيحان'),
    Dhikr('لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', 1, 'صحيح مسلم'),
  ],
  'أذكار النوم': [
    Dhikr('بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا', 1, 'صحيح البخاري'),
    Dhikr('سُبْحَانَ اللَّهِ', 33, 'الصحيحان'),
    Dhikr('الْحَمْدُ لِلَّهِ', 33, 'الصحيحان'),
    Dhikr('اللَّهُ أَكْبَرُ', 34, 'الصحيحان'),
  ],
  'أذكار الاستيقاظ': [
    Dhikr('الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ', 1, 'صحيح البخاري'),
  ],
  'أدعية متنوعة': [
    Dhikr('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 1, 'سورة البقرة: 201'),
    Dhikr('رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ', 1, 'سورة إبراهيم: 41'),
  ],
};

class AzkarScreen extends StatelessWidget {
  const AzkarScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(title: const Text('حصن المسلم • الأذكار'), backgroundColor: _green, foregroundColor: Colors.white),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(24), border: Border.all(color: _gold, width: 1.5)),
        child: const Column(children: [
          Icon(Icons.auto_awesome, color: _gold, size: 32),
          SizedBox(height: 8),
          Text('أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ', textAlign: TextAlign.center,
            style: TextStyle(color: _paper, fontSize: 21, fontWeight: FontWeight.bold)),
          SizedBox(height: 7),
          Text('اذكر الله بقلب مطمئن', style: TextStyle(color: _gold)),
        ])),
      const SizedBox(height: 16),
      for (final entry in _groups.entries)
        Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _gold)),
          child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(backgroundColor: _green, child: Icon(Icons.favorite_outline, color: _gold)),
            title: Text(entry.key, style: const TextStyle(color: _green, fontSize: 19, fontWeight: FontWeight.bold)),
            subtitle: Text('${entry.value.length} أذكار • عداد تلقائي'),
            trailing: const Icon(Icons.chevron_left, color: _green),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AzkarReader(title: entry.key, items: entry.value))),
          )),
    ]),
  );
}

class AzkarReader extends StatefulWidget {
  const AzkarReader({super.key, required this.title, required this.items});
  final String title;
  final List<Dhikr> items;
  @override State<AzkarReader> createState() => _AzkarReaderState();
}
class _AzkarReaderState extends State<AzkarReader> {
  int index = 0;
  Map<String, int> counts = {};
  bool loaded = false;
  String get key => 'azkar_${widget.title}';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      counts = data.map((k, v) => MapEntry(k, (v as num).toInt()));
      index = (prefs.getInt('${key}_index') ?? 0).clamp(0, widget.items.length - 1);
      loaded = true;
    });
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(counts));
    await prefs.setInt('${key}_index', index);
  }
  void _tap() {
    final item = widget.items[index];
    final current = counts['$index'] ?? 0;
    if (current >= item.target) return;
    setState(() => counts['$index'] = current + 1);
    if (current + 1 == item.target && index < widget.items.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (!mounted || index >= widget.items.length - 1) return;
        setState(() => index++);
        _save();
      });
    }
    _save();
  }
  @override Widget build(BuildContext context) {
    final item = widget.items[index];
    final count = counts['$index'] ?? 0;
    final done = count >= item.target;
    return Scaffold(backgroundColor: _paper,
      appBar: AppBar(title: Text(widget.title), backgroundColor: _green, foregroundColor: Colors.white),
      body: !loaded ? const Center(child: CircularProgressIndicator()) :
        SafeArea(child: LayoutBuilder(builder: (context, size) {
          final diameter = (size.maxWidth - 42).clamp(220.0, 390.0);
          return Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: LinearProgressIndicator(
              value: (index + count / item.target) / widget.items.length,
              minHeight: 7, borderRadius: BorderRadius.circular(10),
              backgroundColor: const Color(0xFFE5D8B7), color: _green)),
            Text('الذكر ${index + 1} من ${widget.items.length}', style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
            Expanded(child: Center(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(18), width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold)),
                  child: Column(children: [
                    Text(item.text, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 22, height: 1.85, color: _green)),
                    const SizedBox(height: 10),
                    Text(item.source, style: const TextStyle(color: Color(0xFF94702F), fontSize: 13)),
                  ])),
                const SizedBox(height: 16),
                GestureDetector(onTap: _tap, child: Container(
                  width: diameter * .65, height: diameter * .65,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _green,
                    border: Border.all(color: _gold, width: 3)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.favorite, color: _gold, size: 26),
                    Text('$count / ${item.target}', style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.bold)),
                    Text(done ? 'اكتمل الذكر ✓' : 'اضغط للتسبيح', style: const TextStyle(color: _gold)),
                  ]),
                )),
              ])))),
            Padding(padding: const EdgeInsets.fromLTRB(14, 5, 14, 15), child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: index == 0 ? null : () {setState(() => index--); _save();}, child: const Text('السابق'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: index == widget.items.length - 1 ? null : () {setState(() => index++); _save();},
                child: const Text('التالي'))),
            ])),
          ]);
        })),
    );
  }
}
