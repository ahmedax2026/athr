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
    final isLong = _selected.length > 95;
    final isMedium = _selected.length > 28;
    final fontSize = isLong ? 26.0 : isMedium ? 25.0 : 34.0;
    final diameter = (MediaQuery.sizeOf(context).width - 66).clamp(220.0, 380.0);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('السبحة الإلكترونية')),
      body: !_loaded ? const Center(child: CircularProgressIndicator()) : SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Text('اختر الذكر', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(_selected),
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [..._defaults, ..._custom].map((v) => DropdownMenuItem(
                value: v, child: Text(v == _ibrahim ? 'الصلاة الإبراهيمية كاملة' : _plain(v),
                  maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) { if (v != null) { setState(() { _selected = v; if (_goal != 0 && (_counts[v] ?? 0) > _goal) _counts[v] = _goal; }); _save(); } },
            ),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              TextButton.icon(onPressed: _addCustom, icon: const Icon(Icons.add), label: const Text('إضافة تسبيحة')),
              if (_custom.contains(_selected)) TextButton.icon(
                onPressed: _deleteCustom, icon: const Icon(Icons.delete_outline), label: const Text('حذف الذكر الخاص')),
            ]),
          ]))),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _gold, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(children: [
              GestureDetector(
                onTap: _increment,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: diameter,
                  height: diameter,
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A493D),
                    border: Border.all(color: _gold, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Expanded(
                      child: SizedBox(width: diameter - 58,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: diameter - 58,
                            child: Text(_plain(_selected),
                              textAlign: TextAlign.center,
                              softWrap: true,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: const Color(0xFFFFE6AB),
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                                height: isLong ? 1.45 : 1.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('$count', style: const TextStyle(
                      color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
                    Text(_goal == 0 ? 'تسبيح مفتوح' : 'الهدف: $_goal',
                      style: const TextStyle(color: _gold, fontSize: 13)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text(_goal != 0 && count >= _goal ? 'اكتمل العدد المستهدف' : 'المس الدائرة للتسبيح',
                style: const TextStyle(color: _gold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                OutlinedButton.icon(onPressed: count == 0 ? null : () {
                  setState(() => _counts[_selected] = count - 1); _save();
                }, icon: const Icon(Icons.undo), label: const Text('تراجع'),
                  style: OutlinedButton.styleFrom(foregroundColor: _gold)),
                OutlinedButton.icon(onPressed: count == 0 ? null : () {
                  setState(() => _counts[_selected] = 0); _save();
                }, icon: const Icon(Icons.refresh), label: const Text('تصفير'),
                  style: OutlinedButton.styleFrom(foregroundColor: _gold)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          Text('العدد المستهدف', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final goal in [33, 100, 1000, 0])
              ChoiceChip(label: Text(goal == 0 ? 'مفتوح' : '$goal'),
                selected: _goal == goal,
                onSelected: (_) { setState(() { _goal = goal; if (goal != 0 && (_counts[_selected] ?? 0) > goal) _counts[_selected] = goal; }); _save(); }),
          ]),
          const SizedBox(height: 14),
          Card(child: ListTile(
            leading: const Icon(Icons.auto_awesome, color: _gold),
            title: const Text('إجمالي التسبيحات المحفوظة'),
            trailing: Text('${_counts.values.fold<int>(0, (sum, v) => sum + v)}',
              style: theme.textTheme.titleLarge),
          )),
        ]),
      ),
    );
  }
}
