import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminContentEditor extends StatefulWidget {
  const AdminContentEditor({super.key, required this.document, required this.title,
    required this.fields, required this.collection, required this.publicFlag});
  final String document, title, collection, publicFlag;
  final List<(String, String)> fields;

  @override
  State<AdminContentEditor> createState() => _AdminContentEditorState();
}

class _AdminContentEditorState extends State<AdminContentEditor> {
  final Map<String, TextEditingController> controllers = {};
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      controllers[field.$1] = TextEditingController();
    }
    load();
  }

  Future<void> load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(widget.collection)
        .doc(widget.document).get();
      for (final field in widget.fields) {
        controllers[field.$1]!.text = (doc.data()?[field.$1] ?? '').toString();
      }
    } catch (_) {
      error = 'تعذر تحميل البيانات. تأكد من الاتصال والصلاحيات.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() { saving = true; error = null; });
    try {
      final data = <String, dynamic>{
        for (final field in widget.fields) field.$1: controllers[field.$1]!.text.trim(),
        widget.publicFlag: true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection(widget.collection)
        .doc(widget.document).set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التغييرات بنجاح')));
      }
    } catch (_) {
      if (mounted) setState(() => error = 'فشل الحفظ. راجع الاتصال وقواعد Firestore.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('عدّل البيانات واضغط حفظ لتظهر للمستخدمين مباشرة.',
            style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          for (final field in widget.fields) ...[
            TextField(
              controller: controllers[field.$1],
              minLines: field.$1 == 'prayer' ? 3 : 1,
              maxLines: field.$1 == 'prayer' ? 5 : 1,
              decoration: InputDecoration(labelText: field.$2,
                border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
          ],
          if (error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red))),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
          ),
        ]),
      )),
  );
}
