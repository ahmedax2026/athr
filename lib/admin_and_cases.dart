import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_content.dart';

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
              const Text('التحكم في التطبيق', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Card(child: ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('وسائل التواصل'),
                subtitle: const Text('واتساب وفيسبوك وماسنجر وتليجرام'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminContentEditor(
                    collection: 'settings', document: 'contact', publicFlag: 'public',
                    title: 'إدارة التواصل',
                    fields: [
                      ('whatsapp', 'رقم واتساب بصيغة دولية'),
                      ('facebook', 'رابط فيسبوك'),
                      ('messenger', 'رابط ماسنجر'),
                      ('telegram', 'رابط تليجرام'),
                    ],
                  ))),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.favorite_outline),
                title: const Text('شاشة الترحيب'),
                subtitle: const Text('الصورة والدعاء وعدد الضغطات وإظهار الشاشة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminContentEditor(
                    collection: 'content', document: 'welcome', publicFlag: 'published',
                    title: 'إدارة شاشة الترحيب',
                    fields: [
                      ('title', 'عنوان شاشة الترحيب'),
                      ('subtitle', 'الوصف القصير'),
                      ('name', 'اسم صاحب الصدقة الجارية'),
                      ('prayer', 'الدعاء'),
                      ('tapCount', 'عدد الضغطات من 1 إلى 10 (الافتراضي 3)'),
                      ('enabled', 'إظهار الشاشة: true أو false'),
                      ('showPhoto', 'إظهار الصورة: true أو false'),
                      ('photoUrl', 'رابط HTTPS للصورة (فارغ للصورة الأصلية)'),
                      ('buttonText', 'النص داخل القلب'),
                      ('completion', 'رسالة إتمام الدعاء'),
                    ],
                  ))),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('الصفحة الرئيسية'),
                subtitle: const Text('عنوان الترحيب والعبارة التعريفية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminContentEditor(
                    collection: 'content', document: 'home', publicFlag: 'published',
                    title: 'إدارة الصفحة الرئيسية',
                    fields: [
                      ('greeting', 'رسالة الترحيب'),
                      ('tagline', 'العبارة أسفل العنوان'),
                    ],
                  ))),
              )),
              const SizedBox(height: 24),
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
  late final imageUrl = TextEditingController(text: (widget.existing?['imageUrl'] ?? '').toString());
  late final vodafoneCash = TextEditingController(text: (widget.existing?['vodafoneCash'] ?? '').toString());
  late final instapay = TextEditingController(text: (widget.existing?['instapay'] ?? '').toString());
  late bool published = widget.existing?['status'] == 'published';
  bool busy = false;

  @override
  void dispose() {
    for (final c in [title, details, goal, collected, payment, imageUrl, vodafoneCash, instapay]) { c.dispose(); }
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
        'imageUrl': imageUrl.text.trim(),
        'vodafoneCash': vodafoneCash.text.trim(),
        'instapay': instapay.text.trim(),
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
        const SizedBox(height: 18),
        const Text('صورة الحالة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: imageUrl, keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'رابط صورة الحالة (HTTPS)',
            helperText: 'أضف رابط صورة منشورة بموافقة صاحبها', border: OutlineInputBorder())),
        const SizedBox(height: 18),
        const Text('طرق التبرع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(controller: vodafoneCash, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم فودافون كاش', prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: instapay,
          decoration: const InputDecoration(labelText: 'عنوان إنستا باي أو رقم التحويل', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: payment, maxLines: 3, decoration: const InputDecoration(labelText: 'طرق أخرى للتبرع (اختياري)', border: OutlineInputBorder())),
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

  Widget _paymentTile(BuildContext context, String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم نسخ $title بنجاح')));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              SelectableText(value, textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ])),
            const Icon(Icons.copy_rounded),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = (data['goal'] as num?)?.toDouble() ?? 0;
    final collected = (data['collected'] as num?)?.toDouble() ?? 0;
    final fraction = goal <= 0 ? 0.0 : (collected / goal).clamp(0.0, 1.0);
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final vodafone = (data['vodafoneCash'] ?? '').toString().trim();
    final instapay = (data['instapay'] ?? '').toString().trim();
    final other = (data['payment'] ?? '').toString().trim();
    final validImage = Uri.tryParse(imageUrl);
    final showImage = validImage != null && validImage.scheme == 'https' && validImage.host.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (showImage) ...[
            ClipRRect(borderRadius: BorderRadius.circular(14),
              child: Image.network(imageUrl, height: 210, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 100, child: Center(child: Icon(Icons.broken_image_outlined))))),
            const SizedBox(height: 14),
          ],
          Text((data['title'] ?? '').toString(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text((data['details'] ?? '').toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.6)),
          const SizedBox(height: 18),
          LinearProgressIndicator(value: fraction, minHeight: 12,
            borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 12),
          Text('تم جمع: ${collected.toStringAsFixed(0)} ج.م من ${goal.toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('المتبقي: ${(goal - collected).clamp(0, double.infinity).toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text('نسبة الإنجاز: ${(fraction * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w700)),
          const Divider(height: 30),
          const Text('طرق التبرع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (vodafone.isNotEmpty)
            _paymentTile(context, 'فودافون كاش', vodafone, Icons.phone_android),
          if (instapay.isNotEmpty)
            _paymentTile(context, 'إنستا باي', instapay, Icons.account_balance_wallet_outlined),
          if (other.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(other, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
          if (vodafone.isEmpty && instapay.isEmpty && other.isEmpty)
            const Text('لم تُحدد طرق التبرع بعد'),
          const SizedBox(height: 14),
          const Text('يرجى التأكد من بيانات التحويل قبل إرسال أي مبلغ.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      )),
    );
  }
}
