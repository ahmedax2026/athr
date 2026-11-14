import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _green = Color(0xFF073E35);
const _gold = Color(0xFFD6B56C);
const _ibrahim = 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ.\n\nاللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ.';
// Strip Arabic vowel marks, shadda and tanween from tasbeeh labels.
String _plain(String value) => value.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '').trim();

const _defaults = <String>[
  'سُبْحَانَ اللَّهِ', 'الْحَمْدُ لِلَّهِ', 'اللَّهُ أَكْبَرُ',
  'لَا إِلَهَ إِلَّا اللَّهُ', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  'سُبْحَانَ اللَّهِ الْعَظِيمِ', 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', _ibrahim,
];

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});
  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  List<String> _custom = [];
  Map<String, int> _counts = {};
  String _selected = _defaults.first;
  int _goal = 33;
  bool _loaded = false;
  String get _storagePrefix {
    final user = FirebaseAuth.instance.currentUser;
    return user == null ? 'tasbeeh_local_' : 'tasbeeh_${user.uid}_';
  }
  String _key(String suffix) => '$_storagePrefix$suffix';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final custom = (jsonDecode(prefs.getString(_key('custom')) ?? '[]') as List).cast<String>();
      final raw = (jsonDecode(prefs.getString(_key('counts')) ?? '{}') as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _custom = custom;
        _counts = raw.map((key, value) => MapEntry(key, (value as num).toInt()));
        final saved = prefs.getString(_key('selected'));
        if (saved != null && [..._defaults, ...custom].contains(saved)) _selected = saved;
        _goal = prefs.getInt(_key('goal')) ?? 33;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key('custom'), jsonEncode(_custom));
    await prefs.setString(_key('counts'), jsonEncode(_counts));
    await prefs.setString(_key('selected'), _selected);
    await prefs.setInt(_key('goal'), _goal);
  }

  void _increment() {
    if (_goal != 0 && (_counts[_selected] ?? 0) >= _goal) return;
    setState(() => _counts[_selected] = (_counts[_selected] ?? 0) + 1);
    _save();
  }

  Future<void> _addCustom() async {
    var entered = '';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة ذكر خاص'),
        content: TextField(onChanged: (v) => entered = v, maxLines: 4, maxLength: 500,
          decoration: const InputDecoration(labelText: 'اكتب الذكر أو الدعاء كاملًا', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, entered.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (!mounted) return;
    if (value == null || _plain(value).isEmpty ||
        [..._defaults, ..._custom].any((v) => _plain(v) == _plain(value))) {
      return;
    }
    final clean = _plain(value);
    setState(() { _custom.add(clean); _selected = clean; });
    _save();
  }

  Future<void> _deleteCustom() async {
    if (!_custom.contains(_selected)) return;
    final old = _selected;
    setState(() { _custom.remove(old); _counts.remove(old); _selected = _defaults.first; });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final count = _counts[_selected] ?? 0;
    final total = _counts.values.fold<int>(0, (sum, v) => sum + v);
    final isLong = _selected.length > 95;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0DE),
      appBar: AppBar(
        title: const Text('السبحة الإلكترونية'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SafeArea(child: LayoutBuilder(builder: (context, area) {
              final compact = area.maxHeight < 580;
              final gap = compact ? 5.0 : 10.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 16,
                  vertical: compact ? 6 : 12),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _gold),
                      borderRadius: BorderRadius.circular(17)),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        key: ValueKey(_selected),
                        initialValue: _selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'اختر الذكر',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10)),
                        items: [..._defaults, ..._custom].map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v == _ibrahim ? 'الصلاة الإبراهيمية كاملة' : _plain(v),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selected = value;
                            if (_goal != 0 && (_counts[value] ?? 0) > _goal) {
                              _counts[value] = _goal;
                            }
                          });
                          _save();
                        },
                      )),
                      IconButton(
                        onPressed: _addCustom,
                        tooltip: 'إضافة ذكر',
                        icon: const Icon(Icons.add_circle_outline, color: _green)),
                      if (_custom.contains(_selected))
                        IconButton(
                          onPressed: _deleteCustom,
                          tooltip: 'حذف الذكر',
                          icon: const Icon(Icons.delete_outline, color: _green)),
                    ]),
                  ),
                  SizedBox(height: gap),
                  Expanded(child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF155E4B), Color(0xFF06362E)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: _gold, width: 1.4)),
                    child: LayoutBuilder(builder: (context, inner) {
                      // Premium compact dial: never exceed 240 dp, and always
                      // fit the available vertical space without scrolling.
                      final diameter = (inner.maxWidth * .66)
                          .clamp(120.0, 240.0);
                      return Column(children: [
                        Expanded(child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GestureDetector(
                              onTap: _increment,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: diameter,
                                height: diameter,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A493D),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _gold, width: 2.5),
                                  boxShadow: const [BoxShadow(
                                    color: Color(0x55000000), blurRadius: 17,
                                    offset: Offset(0, 6))]),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                        width: diameter - 43,
                                        child: Text(_plain(_selected),
                                          textDirection: TextDirection.rtl,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: const Color(0xFFFFE6AB),
                                            fontSize: isLong ? 20 : 27,
                                            fontWeight: FontWeight.w700,
                                            height: 1.3)),
                                      ),
                                    )),
                                    Text('$count', style: const TextStyle(
                                      color: Colors.white, fontSize: 34,
                                      fontWeight: FontWeight.w900)),
                                    Text(_goal == 0 ? 'تسبيح مفتوح' : 'الهدف: $_goal',
                                      style: const TextStyle(
                                        color: _gold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )),
                        Padding(
                          padding: EdgeInsets.only(bottom: compact ? 6 : 12),
                          child: Text(
                            _goal != 0 && count >= _goal
                                ? 'أتممت العدد المستهدف'
                                : 'اضغط على الدائرة للتسبيح',
                            style: const TextStyle(
                              color: _gold, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                        ),
                      ]);
                    }),
                  )),
                  SizedBox(height: gap),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: count == 0 ? null : () {
                        setState(() => _counts[_selected] = count - 1);
                        _save();
                      },
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('تراجع'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        minimumSize: const Size.fromHeight(42)))),
                    const SizedBox(width: 9),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: count == 0 ? null : () {
                        setState(() => _counts[_selected] = 0);
                        _save();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('تصفير'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        minimumSize: const Size.fromHeight(42)))),
                  ]),
                  SizedBox(height: gap),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final goal in [33, 100, 1000, 0])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text(goal == 0 ? 'مفتوح' : '$goal'),
                            selected: _goal == goal,
                            onSelected: (_) {
                              setState(() {
                                _goal = goal;
                                if (goal != 0 && (_counts[_selected] ?? 0) > goal) {
                                  _counts[_selected] = goal;
                                }
                              });
                              _save();
                            }),
                        ),
                    ]),
                  ),
                  SizedBox(height: gap),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.auto_awesome, color: _green, size: 17),
                    const SizedBox(width: 8),
                    Text('إجمالي التسبيحات: $total',
                      style: const TextStyle(
                        color: _green, fontWeight: FontWeight.w800)),
                  ]),
                ]),
              );
            })),
    );
  }
}
