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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text(existing == null ? 'إضافة قسم' : 'تعديل القسم'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 60, decoration: const InputDecoration(labelText: 'اسم القسم')),
          TextField(controller: description, maxLength: 120, decoration: const InputDecoration(labelText: 'الوصف')),
          TextField(controller: body, maxLength: 20000, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'المحتوى النصي')),
          SwitchListTile(title: const Text('إظهار للمستخدمين'), value: visible, onChanged: (v) => update(() => visible = v)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
            Navigator.pop(ctx, <String, dynamic>{
              'id': existing?['id'] ?? FirebaseFirestore.instance.collection('content').doc().id,
              'title': title.text.trim(), 'description': description.text.trim(),
              'body': body.text.trim(), 'visible': visible,
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

  Future<void> mutate(void Function(List<Map<String, dynamic>>) change) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final doc = await tx.get(ref);
        final items = sectionItems(doc.data());
        change(items);
        tx.set(ref, {'items': items, 'published': true, 'updatedAt': FieldValue.serverTimestamp()});
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الأقسام. تحقق من الاتصال والصلاحيات والحد الأقصى.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الأقسام الجديدة')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : () => edit(null),
      icon: const Icon(Icons.add), label: const Text('إضافة قسم')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الأقسام'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = sectionItems(snapshot.data?.data());
        if (items.isEmpty) return const Center(child: Text('يمكنك إضافة قسم نصي جديد من الزر بالأسفل'));
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
              onTap: busy ? null : () => edit(item),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () async {
                final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                  title: const Text('حذف القسم؟'),
                  content: const Text('سيتم حذف محتواه من القائمة المنشورة.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
                if (yes == true && mounted) await mutate((all) => all.removeWhere((e) => e['id'] == item['id']));
              }),
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

class DynamicSectionCards extends StatefulWidget {
  const DynamicSectionCards({super.key});
  @override
  State<DynamicSectionCards> createState() => _DynamicSectionCardsState();
}

class _DynamicSectionCardsState extends State<DynamicSectionCards> {
  late final stream = FirebaseFirestore.instance.collection('content').doc('custom_sections').snapshots();
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: stream,
    builder: (context, snapshot) {
      final data = snapshot.data?.data();
      if (data?['published'] != true) return const SizedBox.shrink();
      final items = sectionItems(data).where((e) => e['visible'] != false);
      return Column(children: [
        for (final item in items)
          Card(child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(item['title'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(item['description']?.toString() ?? ''),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
              appBar: AppBar(title: Text(item['title'].toString())),
              body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
                SelectableText(item['body']?.toString() ?? '', style: const TextStyle(fontSize: 19, height: 1.9)),
              ])),
            ))),
          )),
      ]);
    },
  );
}
