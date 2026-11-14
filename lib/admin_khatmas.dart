import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminKhatmasScreen extends StatelessWidget {
  const AdminKhatmasScreen({super.key});

  Future<void> close(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إغلاق الختمة؟'),
      content: const Text('سيتم إيقاف المشاركة دون حذف سجل التلاوة.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إغلاق')),
      ],
    ));
    if (yes != true || !context.mounted) return;
    try {
      await ref.update({'closed': true, 'closedAt': FieldValue.serverTimestamp()});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الختمة')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الإغلاق. تحقق من الصلاحيات.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الختمات')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('khatmas').limit(100).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('تعذر تحميل الختمات. تحقق من قواعد Firestore.'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('لا توجد ختمات'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('عرض حتى 100 ختمة وإدارة إغلاقها دون حذف بياناتها.'),
          for (final doc in docs) Card(child: ExpansionTile(
            title: Text((doc.data()['title'] ?? 'ختمة').toString()),
            subtitle: Text('المشاركون: ${doc.data()['memberCount'] ?? 0} • ${doc.data()['closed'] == true ? 'مغلقة' : 'مفتوحة'}'),
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: doc.reference.collection('members').snapshots(),
                builder: (context, members) {
                  if (members.hasError) return const Text('تعذر عرض المشاركين');
                  if (!members.hasData) return const LinearProgressIndicator();
                  return Column(children: [
                    for (final m in members.data!.docs) ListTile(
                      title: Text((m.data()['name'] ?? 'مشارك').toString()),
                      subtitle: Text('المكتمل: ${(m.data()['completed'] as List?)?.length ?? 0} من ${(m.data()['parts'] as List?)?.length ?? 0}'),
                    ),
                  ]);
                },
              ),
              if (doc.data()['closed'] != true)
                OutlinedButton(onPressed: () => close(context, doc.reference), child: const Text('إغلاق الختمة')),
            ],
          )),
        ]);
      },
    ),
  );
}
