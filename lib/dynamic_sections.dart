import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DynamicSectionsAdmin extends StatefulWidget {
  const DynamicSectionsAdmin({super.key});
  @override
  State<DynamicSectionsAdmin> createState() => _DynamicSectionsAdminState();
}

class _DynamicSectionsAdminState extends State<DynamicSectionsAdmin> {
  final ref = FirebaseFirestore.instance.collection('content').doc('custom_sections');
  bool busy = false;

  Future<void> edit(Map<String, dynamic>? existing) async {
    final title = TextEditingController(text: existing?['title']?.toString());
    final description = TextEditingController(text: existing?['description']?.toString());
    final body = TextEditingController(text: existing?['body']?.toString());
    bool visible = existing?['visible'] != false;
    String icon = sectionIcons.containsKey(existing?['icon']) ? existing!['icon'].toString() : 'book';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text(existing == null ? 'إضافة قسم' : 'تعديل القسم'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 60, decoration: const InputDecoration(labelText: 'اسم القسم')),
          TextField(controller: description, maxLength: 120, decoration: const InputDecoration(labelText: 'الوصف')),
          TextField(controller: body, maxLength: 20000, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'المحتوى النصي')),
          DropdownButtonFormField<String>(initialValue: icon,
            decoration: const InputDecoration(labelText: 'أيقونة القسم'),
            items: [for (final entry in sectionIcons.entries) DropdownMenuItem(value: entry.key,
              child: Row(children: [Icon(entry.value.$2), const SizedBox(width: 8), Text(entry.value.$1)]))],
            onChanged: (v) { if (v != null) update(() => icon = v); }),
          SwitchListTile(title: const Text('إظهار للمستخدمين'), value: visible, onChanged: (v) => update(() => visible = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty) return;
            Navigator.pop(ctx, <String, dynamic>{
              'id': existing?['id'] ?? FirebaseFirestore.instance.collection('content').doc().id,
              'title': title.text.trim(), 'description': description.text.trim(),
              'body': body.text.trim(), 'visible': visible, 'icon': icon,
              if (existing?['cards'] is List) 'cards': existing!['cards'],
            });
          }, child: const Text('حفظ')),
        ],
      )),
    );
    // The closing dialog can still own the controllers during its animation.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    title.dispose(); description.dispose(); body.dispose();
    if (result == null || !mounted) return;
    await mutate((items) {
      final index = items.indexWhere((item) => item['id'] == result['id']);
      if (index < 0) {
        if (items.length >= 20) { throw StateError('الحد الأقصى 20 قسمًا'); }
        items.add(result);
      } else { items[index] = result; }
    });
  }

  Future<void> mutate(void Function(List<Map<String, dynamic>>) change, {bool propagate = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final doc = await tx.get(ref);
        final items = sectionItems(doc.data());
        change(items);
        if (utf8.encode(jsonEncode(items)).length > 850000) throw StateError('size');
        tx.set(ref, {'items': items, 'published': true, 'updatedAt': FieldValue.serverTimestamp()});
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الأقسام. تحقق من الاتصال والصلاحيات والحد الأقصى.')));
      if (propagate) rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الأقسام الجديدة'), actions: [
      IconButton(tooltip: 'ترتيب جميع أقسام الرئيسية', icon: const Icon(Icons.sort_rounded),
        onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HomeSectionOrderAdmin()))),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => edit(null),
      icon: const Icon(Icons.add), label: const Text('إضافة قسم')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الأقسام'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = sectionItems(snapshot.data?.data());
        if (items.isEmpty) return const Center(child: Text('أضف قسمًا جديدًا، أو استخدم زر الترتيب أعلى الشاشة لترتيب الأقسام الأصلية.'));
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) {
            if (busy) return;
            final ids = items.map((e) => e['id']).toList();
            if (newIndex > oldIndex) newIndex--;
            ids.insert(newIndex, ids.removeAt(oldIndex));
            mutate((current) {
              final byId = {for (final item in current) item['id']: item};
              current
                ..clear()
                ..addAll(ids.where(byId.containsKey).map((id) => byId.remove(id)!))
                ..addAll(byId.values);
            });
          },
          itemBuilder: (context, i) {
            final item = items[i];
            return Card(key: ValueKey(item['id']), child: ListTile(
              leading: Icon(item['visible'] == false ? Icons.visibility_off : Icons.article_outlined),
              title: Text(item['title'].toString()),
              subtitle: Text(item['visible'] == false ? 'مخفي' : 'منشور'),
              onTap: busy ? null : () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => SectionContentAdmin(section: item, onSave: (cards) async {
                  await mutate((all) {
                    final index = all.indexWhere((e) => e['id'] == item['id']);
                    if (index < 0) throw StateError('missing');
                    all[index] = {...all[index], 'cards': cards, 'body': ''};
                  }, propagate: true);
                }))),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'تعديل الاسم والأيقونة', icon: const Icon(Icons.edit_outlined), onPressed: busy ? null : () => edit(item)),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () async {
                final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('حذف القسم؟'),
                  content: const Text('سيتم حذف محتواه من القائمة المنشورة.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
                if (yes == true && mounted) await mutate((all) => all.removeWhere((e) => e['id'] == item['id']));
              })]),
            ));
          },
        );
      },
    ),
  );
}

List<Map<String, dynamic>> sectionItems(Map<String, dynamic>? data) {
  final raw = data?['items'];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((e) => e['id'] is String && e['title'] is String).take(20).toList();
}


const sectionIcons = <String, (String, IconData)>{
  'book': ('كتاب', Icons.menu_book_rounded),
  'heart': ('قلب', Icons.favorite_border_rounded),
  'dua': ('دعاء', Icons.volunteer_activism_rounded),
  'star': ('نجمة', Icons.auto_awesome_rounded),
  'mosque': ('مسجد', Icons.mosque_outlined),
  'sun': ('شمس', Icons.wb_sunny_outlined),
  'moon': ('هلال', Icons.nightlight_outlined),
  'headphone': ('صوتيات', Icons.headphones_rounded),
};
IconData customSectionIcon(Map<String, dynamic> item) => sectionIcons[item['icon']]?.$2 ?? Icons.menu_book_outlined;

const homeSectionNames = <String, String>{
  'quran': 'القرآن الكريم', 'azkar': 'الأذكار', 'khatma': 'الختمات الجماعية',
  'prayer': 'مواقيت الصلاة', 'tasbeeh': 'السبحة', 'relief': 'فك كرب',
};
List<String> unifiedSectionOrder(Map<String, dynamic> home, List<Map<String, dynamic>> custom) {
  final all = [...homeSectionNames.keys, ...custom.map((x) => 'custom:${x['id']}')];
  final old = (home['sectionOrder'] ?? '').toString().split(',').map((s) => s.trim());
  return [...old, ...all].where(all.contains).toSet().toList();
}

class HomeSectionOrderAdmin extends StatefulWidget {
  const HomeSectionOrderAdmin({super.key});
  @override
  State<HomeSectionOrderAdmin> createState() => _HomeSectionOrderAdminState();
}
class _HomeSectionOrderAdminState extends State<HomeSectionOrderAdmin> {
  final home = FirebaseFirestore.instance.collection('content').doc('home');
  final custom = FirebaseFirestore.instance.collection('content').doc('custom_sections');
  List<String> order = [];
  Map<String, String> names = {};
  Map<String, bool> visible = {};
  bool busy = true;
  bool ready = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final data = (await home.get()).data() ?? {};
      final items = sectionItems((await custom.get()).data());
      if (!mounted) return;
      setState(() {
        order = unifiedSectionOrder(data, items);
        names = {...homeSectionNames, for (final item in items) 'custom:${item['id']}': item['title'].toString()};
        for (final id in homeSectionNames.keys) {
          names[id] = (data['title_$id'] ?? names[id]).toString();
          visible[id] = data['show_$id'].toString() != 'false';
        }
        for (final item in items) { visible['custom:${item['id']}'] = item['visible'] != false; }
        ready = true;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل ترتيب الأقسام')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final h = await tx.get(home);
        final c = await tx.get(custom);
        final items = sectionItems(c.data());
        final actual = unifiedSectionOrder({'sectionOrder': order.join(',')}, items);
        tx.set(home, {'published': true, 'sectionOrder': actual.join(','),
          for (final id in homeSectionNames.keys) if (visible.containsKey(id)) 'show_$id': visible[id]}, SetOptions(merge: true));
        if (c.exists) {
          for (final item in items) {
            final id = 'custom:${item['id']}';
            if (visible.containsKey(id)) item['visible'] = visible[id];
          }
          tx.set(custom, {'items': items, 'published': true}, SetOptions(merge: true));
        }
        // Reading both documents prevents lost updates during a concurrent save.
        if (!h.exists) { /* merge creates the home document */ }
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الترتيب')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ترتيب أقسام الرئيسية')),
    body: Column(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('اسحب الأقسام لتغيير الترتيب، واستخدم المفتاح للإظهار أو الإخفاء. التواصل يبقى في النهاية.')),
      if (busy) const LinearProgressIndicator(),
      Expanded(child: ReorderableListView.builder(itemCount: order.length,
        onReorder: (from, to) { if (busy) return; setState(() { if (to > from) to--; order.insert(to, order.removeAt(from)); }); },
        itemBuilder: (context, index) {
          final id = order[index];
          return Card(key: ValueKey(id), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(leading: Icon(id.startsWith('custom:') ? Icons.auto_awesome_outlined : Icons.apps_rounded),
              title: Text(names[id] ?? id), subtitle: Text(id.startsWith('custom:') ? 'قسم إضافي' : 'قسم أصلي'),
              trailing: Switch(value: visible[id] ?? true, onChanged: busy ? null : (v) => setState(() => visible[id] = v))));
        })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity,
        child: FilledButton(onPressed: busy || !ready ? null : save, child: const Text('حفظ ترتيب الأقسام'))))),
    ]),
  );
}

List<Map<String, dynamic>> sectionContent(Map<String, dynamic> section) {
  final raw = section['cards'];
  if (raw is List && raw.isNotEmpty) {
    final cards = raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).where((x) => x['id'] is String).take(40).toList();
    if (cards.isNotEmpty) return cards;
  }
  final body = (section['body'] ?? '').toString().trim();
  return body.isEmpty ? [] : [{'id': 'legacy', 'text': body, 'target': 0}];
}
class SectionContentAdmin extends StatefulWidget {
  const SectionContentAdmin({super.key, required this.section, required this.onSave});
  final Map<String, dynamic> section;
  final Future<void> Function(List<Map<String, dynamic>>) onSave;
  @override
  State<SectionContentAdmin> createState() => _SectionContentAdminState();
}
class _SectionContentAdminState extends State<SectionContentAdmin> {
  late final cards = sectionContent(widget.section);
  bool busy = false;
  Future<void> edit([int? index]) async {
    final old = index == null ? null : cards[index];
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SectionCardDialog(old: old));
    if (result == null || !mounted) return;
    setState(() { if (index == null) { cards.add(result); } else { cards[index] = result; } });
  }
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.onSave(cards);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ البطاقات أو تجاوز حجم الصور الحد المتاح')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('بطاقات ${widget.section['title']}')),
    body: Column(children: [
      if (busy) const LinearProgressIndicator(),
      if (cards.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('أضف نصًا أو صورة أو بطاقة بعدّاد اختياري.')),
      Expanded(child: ReorderableListView.builder(itemCount: cards.length,
        onReorder: (from, to) { if (busy) return; setState(() { if (to > from) to--; cards.insert(to, cards.removeAt(from)); }); },
        itemBuilder: (context, i) => Card(key: ValueKey(cards[i]['id']), child: ListTile(
          leading: IconButton(icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () => setState(() => cards.removeAt(i))),
          title: Text((cards[i]['text'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(cards[i]['image'] != null ? 'بطاقة مع صورة' : 'بطاقة نصية'),
          onTap: busy ? null : () => edit(i),
        )))),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: busy || cards.length >= 40 ? null : () => edit(),
          icon: const Icon(Icons.add), label: const Text('إضافة بطاقة'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(onPressed: busy ? null : save, child: const Text('حفظ ونشر'))),
      ]))),
    ]),
  );
}
class _SectionCardDialog extends StatefulWidget {
  const _SectionCardDialog({this.old});
  final Map<String, dynamic>? old;
  @override
  State<_SectionCardDialog> createState() => _SectionCardDialogState();
}
class _SectionCardDialogState extends State<_SectionCardDialog> {
  late final text = TextEditingController(text: (widget.old?['text'] ?? '').toString());
  late final count = TextEditingController(text: (widget.old?['target'] ?? 0).toString());
  late String? image = widget.old?['image'] as String?;
  bool picking = false;
  String? error;
  @override
  void dispose() { text.dispose(); count.dispose(); super.dispose(); }
  Future<void> pick() async {
    setState(() { picking = true; error = null; });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, maxHeight: 1400, imageQuality: 65);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 110000 || bytes.length < 3 || bytes[0] != 255 || bytes[1] != 216 || bytes[2] != 255) {
        setState(() => error = 'اختر صورة JPEG أصغر من 110 كيلوبايت بعد الضغط');
        return;
      }
      setState(() => image = base64Encode(bytes));
    } catch (_) { if (mounted) setState(() => error = 'تعذر اختيار الصورة'); }
    finally { if (mounted) setState(() => picking = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('محتوى البطاقة'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: text, maxLength: 20000, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'النص')),
      TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'التكرارات (0 بدون عداد)')),
      if (image != null) Image.memory(base64Decode(image!), height: 120, fit: BoxFit.contain),
      OutlinedButton.icon(onPressed: picking ? null : pick, icon: const Icon(Icons.image_outlined), label: const Text('اختيار صورة')),
      if (image != null) TextButton(onPressed: picking ? null : () => setState(() => image = null), child: const Text('إزالة الصورة')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
    ])),
    actions: [
      TextButton(onPressed: picking ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(onPressed: picking ? null : () {
        final target = int.tryParse(count.text.trim());
        if ((text.text.trim().isEmpty && image == null) || target == null || target < 0 || target > 1000) {
          setState(() => error = 'أدخل محتوى وعددًا بين 0 و1000'); return;
        }
        Navigator.pop(context, {'id': widget.old?['id'] ?? 'card_${DateTime.now().microsecondsSinceEpoch}',
          'text': text.text.trim(), 'target': target, if (image != null) 'image': image});
      }, child: const Text('اعتماد')),
    ],
  );
}
class CustomSectionReader extends StatefulWidget {
  const CustomSectionReader({super.key, required this.section});
  final Map<String, dynamic> section;
  @override
  State<CustomSectionReader> createState() => _CustomSectionReaderState();
}
class _CustomSectionReaderState extends State<CustomSectionReader> {
  static const green = Color(0xFF073E35), gold = Color(0xFFD6B56C), paper = Color(0xFFF1E3C6);
  late final cards = sectionContent(widget.section);
  final pages = PageController();
  Map<String, int> counts = {};
  int index = 0;
  String get storageKey => 'custom_counts_${widget.section['id']}';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString(storageKey) ?? '{}') as Map;
      if (mounted) setState(() => counts = {for (final e in raw.entries) if (e.value is int) e.key.toString(): e.value as int});
    } catch (_) {}
  }
  Future<void> increment(String id, int target) async {
    if ((counts[id] ?? 0) >= target) return;
    setState(() => counts[id] = (counts[id] ?? 0) + 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(counts));
  }
  @override
  void dispose() { pages.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final card = cards.isEmpty ? <String, dynamic>{} : cards[index];
    final id = card['id'].toString();
    final target = card['target'] is int ? card['target'] as int : 0;
    final n = (counts[id] ?? 0).clamp(0, target > 0 ? target : 0);
    return Scaffold(backgroundColor: paper, appBar: AppBar(title: Text(widget.section['title'].toString()), backgroundColor: green, foregroundColor: gold),
      body: SafeArea(child: cards.isEmpty ? const Center(child: Text('لا يوجد محتوى بعد')) : Padding(
        padding: const EdgeInsets.all(12), child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(16)),
            child: Text('البطاقة ${index + 1} / ${cards.length}', textAlign: TextAlign.center, style: const TextStyle(color: gold, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Expanded(child: PageView.builder(controller: pages, itemCount: cards.length,
            onPageChanged: (v) => setState(() => index = v), itemBuilder: (context, i) {
              final item = cards[i];
              final image = item['image'];
              return Container(margin: const EdgeInsets.all(3), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: paper, border: Border.all(color: gold, width: 1.5), borderRadius: BorderRadius.circular(22)),
                child: Column(children: [
                  if (image is String) Expanded(child: Image.memory(base64Decode(image), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink())),
                  if ((item['text'] ?? '').toString().isNotEmpty) Expanded(child: Center(child: SingleChildScrollView(
                    child: Text(item['text'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: green, fontSize: 23, fontWeight: FontWeight.w800, height: 1.8))))),
                ]));
            })),
          if (target > 0) Padding(padding: const EdgeInsets.all(6), child: FilledButton.icon(
            onPressed: n >= target ? null : () => increment(id, target), style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: gold),
            icon: Icon(n >= target ? Icons.check : Icons.touch_app_outlined), label: Text('$n / $target'))),
          Row(children: [
            Expanded(child: FilledButton(onPressed: index == 0 ? null : () => pages.previousPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut), child: const Text('السابق'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: index == cards.length - 1 ? null : () => pages.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut), child: const Text('التالي'))),
          ]),
        ]))));
  }
}
