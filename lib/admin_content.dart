import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'prayer_admin_policy.dart';

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
  bool _isSwitch(String key) => key == 'enabled' || key == 'showPhoto' || key.startsWith('show_') || key.startsWith('allow') || key == 'showMemorial';
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
      if (!mounted) return;
      for (final field in widget.fields) {
        final value = doc.data()?[field.$1];
        controllers[field.$1]!.text = _isSwitch(field.$1)
            ? (value.toString() != 'false').toString()
            : (value ?? (field.$1 == 'tapCount' ? '3' : field.$1 == 'adhanLateMinutes' ? '2' : field.$1 == 'testDelaySeconds' ? '10' : PrayerAdminPolicy.clockDefaults[field.$1] ?? '')).toString();
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
    if (loading || saving) return;
    for (final key in PrayerAdminPolicy.clockDefaults.keys) {
      if (controllers.containsKey(key) && !PrayerAdminPolicy.validClock(controllers[key]!.text)) {
        setState(() => error = 'اختر وقتًا صحيحًا لكل تذكير.');
        return;
      }
    }
    if (controllers.containsKey('testDelaySeconds')) {
      final seconds = int.tryParse(controllers['testDelaySeconds']!.text.trim());
      if (seconds == null || seconds < 5 || seconds > 120) {
        setState(() => error = 'مدة الاختبار من 5 إلى 120 ثانية.');
        return;
      }
    }
    if (controllers.containsKey('adhanLateMinutes')) {
      final minutes = int.tryParse(controllers['adhanLateMinutes']!.text.trim());
      if (minutes == null || minutes < 1 || minutes > 10) {
        setState(() => error = 'أدخل مهلة تأخير الأذان من دقيقة إلى 10 دقائق.');
        return;
      }
    }
    if (controllers.containsKey('followupMinutes')) {
      final raw = controllers['followupMinutes']!.text.trim();
      final minutes = int.tryParse(raw);
      if (raw.isNotEmpty && (minutes == null || minutes < 5 || minutes > 120)) {
        setState(() => error = 'أدخل مدة صحيحة من 5 إلى 120 دقيقة.');
        return;
      }
    }
    setState(() { saving = true; error = null; });
    try {
      final data = <String, dynamic>{
        for (final field in widget.fields) field.$1: _isSwitch(field.$1)
            ? controllers[field.$1]!.text != 'false'
            : controllers[field.$1]!.text.trim(),
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
            if (_isSwitch(field.$1))
              Card(child: SwitchListTile.adaptive(
                title: Text(field.$2.split(':').first),
                value: controllers[field.$1]!.text != 'false',
                onChanged: saving ? null : (value) => setState(() => controllers[field.$1]!.text = value.toString()),
              ))
            else if (PrayerAdminPolicy.clockDefaults.containsKey(field.$1))
              Card(child: ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: Text(field.$2),
                subtitle: Text(controllers[field.$1]!.text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: saving ? null : () async {
                  final current = controllers[field.$1]!.text.split(':');
                  final picked = await showTimePicker(context: context,
                    initialTime: TimeOfDay(hour: int.tryParse(current.first) ?? 8, minute: int.tryParse(current.last) ?? 0));
                  if (picked != null && mounted) {
                    setState(() => controllers[field.$1]!.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                  }
                },
              ))
            else if (field.$1 == 'tapCount')
              DropdownButtonFormField<String>(
                initialValue: List.generate(10, (index) => '${index + 1}').contains(controllers[field.$1]!.text) ? controllers[field.$1]!.text : '3',
                decoration: const InputDecoration(labelText: 'عدد ضغطات القلب', border: OutlineInputBorder()),
                items: List.generate(10, (index) => DropdownMenuItem(value: '${index + 1}', child: Text('${index + 1}'))),
                onChanged: saving ? null : (value) { if (value != null) { controllers[field.$1]!.text = value; } },
              )
            else TextField(
              controller: controllers[field.$1],
              keyboardType: ['adhanLateMinutes', 'testDelaySeconds'].contains(field.$1) ? TextInputType.number : null,
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
            onPressed: saving || error == 'تعذر تحميل البيانات. تأكد من الاتصال والصلاحيات.' ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
          ),
        ]),
      )),
  );
}
