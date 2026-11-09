import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const adminUid = '7g22L1RQBEcN7JtAYqv92J0qiAs2';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text,
      );
      if (result.user?.uid != adminUid) {
        await FirebaseAuth.instance.signOut();
        throw Exception('هذا الحساب لا يملك صلاحية الإدارة');
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AdminDashboardScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'تعذّر تسجيل الدخول. راجع بيانات الحساب وصلاحياته.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('دخول الإدارة')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 64),
        const SizedBox(height: 16),
        const Text('لوحة إدارة أثر لا ينقطع', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'جارٍ الدخول...' : 'تسجيل الدخول')),
      ]),
    )),
  );
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.data?.uid != adminUid) {
        return const Scaffold(body: Center(child: Text('غير مصرح بالدخول إلى لوحة الإدارة')));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة الإدارة'), actions: [
          IconButton(tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.of(context).pop();
            }),
        ]),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('cases').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الحالات. راجع صلاحيات Firestore.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final cases = snapshot.data!.docs;
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text('إدارة حالات فك كرب', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const CaseEditorScreen())),
                icon: const Icon(Icons.add), label: const Text('إضافة حالة جديدة')),
              const SizedBox(height: 12),
              if (cases.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لم تتم إضافة حالات بعد')),
              for (final doc in cases)
                Card(child: ListTile(
                  title: Text((doc.data()['title'] ?? 'حالة بدون عنوان').toString()),
                  subtitle: Text('المطلوب: ${doc.data()['goal'] ?? 0} ج.م | المحصل: ${doc.data()['collected'] ?? 0} ج.م'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CaseEditorScreen(caseId: doc.id, existing: doc.data()))),
                )),
            ]);
          },
        ),
      );
    },
  );
}

class CaseEditorScreen extends StatefulWidget {
  const CaseEditorScreen({super.key, this.caseId, this.existing});
  final String? caseId;
  final Map<String, dynamic>? existing;
  @override
  State<CaseEditorScreen> createState() => _CaseEditorScreenState();
}

class _CaseEditorScreenState extends State<CaseEditorScreen> {
  late final title = TextEditingController(text: (widget.existing?['title'] ?? '').toString());
  late final details = TextEditingController(text: (widget.existing?['details'] ?? '').toString());
  late final goal = TextEditingController(text: (widget.existing?['goal'] ?? '').toString());
  late final collected = TextEditingController(text: (widget.existing?['collected'] ?? 0).toString());
  late final payment = TextEditingController(text: (widget.existing?['payment'] ?? '').toString());
  late bool published = widget.existing?['status'] == 'published';
  bool busy = false;

  @override
  void dispose() {
    for (final c in [title, details, goal, collected, payment]) { c.dispose(); }
    super.dispose();
  }

  Future<void> save() async {
    final target = double.tryParse(goal.text.trim());
    final raised = double.tryParse(collected.text.trim());
    if (title.text.trim().isEmpty || target == null || target <= 0 ||
        raised == null || raised < 0 || raised > target) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل عنوانًا ومبالغ صحيحة؛ المحصل لا يتجاوز المطلوب')));
      return;
    }
    setState(() => busy = true);
    try {
      final data = <String, dynamic>{
        'title': title.text.trim(),
        'details': details.text.trim(),
        'goal': target,
        'collected': raised,
        'payment': payment.text.trim(),
        'status': published ? 'published' : 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final collection = FirebaseFirestore.instance.collection('cases');
      if (widget.caseId == null) {
        await collection.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await collection.doc(widget.caseId).update(data);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل الحفظ. تحقق من الاتصال والصلاحيات')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.caseId == null ? 'إضافة حالة' : 'تعديل الحالة')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الحالة')),
        TextField(controller: details, maxLines: 4, decoration: const InputDecoration(labelText: 'تفاصيل الحالة')),
        TextField(controller: goal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المطلوب بالجنيه')),
        TextField(controller: collected, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المحصل بالجنيه')),
        TextField(controller: payment, maxLines: 3, decoration: const InputDecoration(labelText: 'طرق التبرع وأرقام التحويل')),
        SwitchListTile(title: const Text('نشر الحالة للمستخدمين'), value: published,
          onChanged: (v) => setState(() => published = v)),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'جارٍ الحفظ...' : 'حفظ الحالة')),
      ]),
    )),
  );
}

class PublicCasesScreen extends StatelessWidget {
  const PublicCasesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('فك كرب')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('cases')
        .where('status', isEqualTo: 'published').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الحالات حاليًا'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final cases = snapshot.data!.docs;
        if (cases.isEmpty) return const Center(child: Text('لا توجد حالات منشورة حاليًا'));
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final doc in cases)
            _PublicCaseCard(data: doc.data()),
        ]);
      },
    ),
  );
}

class _PublicCaseCard extends StatelessWidget {
  const _PublicCaseCard({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final goal = (data['goal'] as num?)?.toDouble() ?? 0;
    final collected = (data['collected'] as num?)?.toDouble() ?? 0;
    final fraction = goal <= 0 ? 0.0 : (collected / goal).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text((data['title'] ?? '').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text((data['details'] ?? '').toString()),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: fraction, minHeight: 10, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 12),
          Text('تم جمع: ${collected.toStringAsFixed(0)} ج.م من ${goal.toStringAsFixed(0)} ج.م'),
          Text('المتبقي: ${(goal - collected).clamp(0, double.infinity).toStringAsFixed(0)} ج.م'),
          Text('نسبة الإنجاز: ${(fraction * 100).toStringAsFixed(0)}%'),
          const Divider(height: 24),
          const Text('طرق التبرع', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText((data['payment'] ?? 'لم تُحدد بعد').toString()),
          const SizedBox(height: 8),
          const Text('يرجى التأكد من بيانات التحويل قبل إرسال أي مبلغ.',
            style: TextStyle(fontSize: 12)),
        ],
      )),
    );
  }
}
