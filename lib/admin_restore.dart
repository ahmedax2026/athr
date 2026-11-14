import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRestoreScreen extends StatefulWidget {
  const AdminRestoreScreen({super.key});
  @override
  State<AdminRestoreScreen> createState() => _AdminRestoreScreenState();
}
class _AdminRestoreScreenState extends State<AdminRestoreScreen> {
  bool busy = false;
  static const targets = {
    'welcome': 'شاشة الدعاء والترحيب',
    'home': 'الصفحة الرئيسية',
    'custom_sections': 'الأقسام المضافة',
  };
  final db = FirebaseFirestore.instance;

  Future<void> restore(List<String> keys, {bool undo = false}) async {
    if (busy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(undo ? 'استعادة النسخة السابقة؟' : 'استعادة الإعدادات الأصلية؟'),
      content: const Text('لن يتم حذف حسابات المستخدمين أو الختمات أو حالات فك كرب أو إعدادات التواصل.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الاستعادة')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await db.runTransaction((tx) async {
        final refs = keys.map((key) => db.collection('content').doc(key)).toList();
        final backups = keys.map((key) => db.collection('settings').doc('restore_backup_$key')).toList();
        final current = <DocumentSnapshot<Map<String, dynamic>>>[];
        final previous = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final ref in refs) {
          current.add(await tx.get(ref));
        }
        for (final ref in backups) {
          previous.add(await tx.get(ref));
        }
        for (var i = 0; i < refs.length; i++) {
          if (undo) {
            final saved = previous[i].data();
            if (saved == null) { throw StateError('لا توجد نسخة سابقة'); }
            final value = saved['data'];
            if (saved['exists'] == true && value is Map) {
              tx.set(refs[i], Map<String, dynamic>.from(value));
            } else {
              tx.delete(refs[i]);
            }
          } else {
            tx.delete(refs[i]);
          }
          tx.set(backups[i], {
            'exists': current[i].exists,
            'data': current[i].data(),
            'public': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الاستعادة. تظهر الإعدادات بعد المزامنة أو إعادة فتح التطبيق.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذرت الاستعادة. تحقق من الاتصال أو توفر نسخة سابقة والصلاحيات.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('النسخ الاحتياطية والاستعادة')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('استعادة إعدادات العرض والمحتوى الديناميكي دون حذف بيانات المستخدمين. تُحفظ نسخة من الحالة الحالية قبل الاستعادة.'),
      const SizedBox(height: 16),
      for (final entry in targets.entries) Card(child: Column(children: [
        ListTile(title: Text(entry.value), leading: const Icon(Icons.restore)),
        Wrap(children: [
          TextButton(onPressed: busy ? null : () => restore([entry.key]), child: const Text('الإعدادات الأصلية')),
          TextButton(onPressed: busy ? null : () => restore([entry.key], undo: true), child: const Text('النسخة السابقة')),
        ]),
      ])),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : () => restore(targets.keys.toList()), icon: const Icon(Icons.restore), label: const Text('استعادة الإعدادات الأصلية للجميع')),
      OutlinedButton(onPressed: busy ? null : () => restore(targets.keys.toList(), undo: true), child: const Text('استعادة النسخ السابقة للجميع')),
    ]),
  );
}
