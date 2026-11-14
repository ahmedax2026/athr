import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_content.dart';
import 'admin_adhan.dart';
import 'admin_broadcast.dart';
import 'admin_analytics.dart';
import 'admin_khatmas.dart';
import 'admin_restore.dart';
import 'dynamic_sections.dart';

const adminUid = '7g22L1RQBEcN7JtAYqv92J0qiAs2';

/// Reuse the existing Firebase session whenever the administrator returns.
class AdminSessionScreen extends StatelessWidget {
  const AdminSessionScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, snapshot) {
      if (snapshot.data?.uid == adminUid) return const AdminDashboardScreen();
      if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const AdminLoginScreen();
    },
  );
}

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
      // AdminSessionScreen observes FirebaseAuth and opens the dashboard.
      // Do not replace the route: navigating back must preserve the session.
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
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, snapshot) {
      if (snapshot.data?.uid != adminUid) {
        return const Scaffold(body: Center(child: Text('غير مصرح بالدخول إلى لوحة الإدارة')));
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin'), actions: [
          IconButton(tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('تسجيل الخروج من الإدارة؟'),
                content: const Text('يمكنك الرجوع للرئيسية دون تسجيل الخروج إذا أردت متابعة إدارة التطبيق لاحقًا.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسجيل الخروج'))],
              ));
              if (confirm != true || !context.mounted) return;
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تسجيل الخروج. حاول مرة أخرى.')));
              }
            }),
        ]),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('cases').snapshots(),
          builder: (context, snapshot) {
            final cases = snapshot.data?.docs ?? [];
            return ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(leading:const Icon(Icons.analytics_outlined),title:const Text('إحصائيات التطبيق'),subtitle:const Text('المستخدمون الجدد والنشطون'),onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>const AdminAnalyticsScreen())))),
              Card(child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('إضافة وإدارة الأقسام'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DynamicSectionsAdmin())),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('النسخ الاحتياطية والاستعادة'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminRestoreScreen())),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('إدارة الختمات والمشاركين'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminKhatmasScreen())),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('إدارة أصوات الأذان'),
                subtitle: const Text('إضافة وتعديل أصوات MP3'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminAdhanScreen())),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('مركز الإشعارات'),
                subtitle: const Text('إرسال للجميع أو تجربة على جهازك'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminBroadcastScreen())),
              )),
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
                subtitle: const Text('عنوان التطبيق والاسم والدعاء'),
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
                      ('tapCount', 'عدد الضغطات من 1 إلى 10'),
                      ('enabled', 'إظهار الشاشة: true أو false'),
                      ('showPhoto', 'إظهار الصورة: true أو false'),
                      ('photoUrl', 'رابط HTTPS للصورة'),
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
                      ('appTitle', 'عنوان التطبيق في الرئيسية'),
                      ('showMemorial', 'بطاقة الوالد: true أو false'),
                      ('sectionOrder', 'ترتيب الأقسام: quran,azkar,khatma,prayer,tasbeeh,relief'),
                      ('show_quran', 'إظهار القرآن: true أو false'),
                      ('title_quran', 'اسم قسم القرآن'),
                      ('subtitle_quran', 'وصف قسم القرآن'),
                      ('show_azkar', 'إظهار الأذكار: true أو false'),
                      ('title_azkar', 'اسم قسم الأذكار'),
                      ('subtitle_azkar', 'وصف قسم الأذكار'),
                      ('show_khatma', 'إظهار الختمات: true أو false'),
                      ('title_khatma', 'اسم قسم الختمات'),
                      ('subtitle_khatma', 'وصف قسم الختمات'),
                      ('show_prayer', 'إظهار الصلاة: true أو false'),
                      ('title_prayer', 'اسم قسم الصلاة'),
                      ('subtitle_prayer', 'وصف قسم الصلاة'),
                      ('show_tasbeeh', 'إظهار السبحة: true أو false'),
                      ('title_tasbeeh', 'اسم قسم السبحة'),
                      ('subtitle_tasbeeh', 'وصف قسم السبحة'),
                      ('show_relief', 'إظهار فك كرب: true أو false'),
                      ('title_relief', 'اسم قسم فك كرب'),
                      ('subtitle_relief', 'وصف قسم فك كرب'),
                    ],
                  ))),
              )),
              Card(child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('الإشعارات والأذان'),
                subtitle: const Text('التحكم في سياسة التنبيهات العامة'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AdminContentEditor(
                    collection: 'content', document: 'prayer_policy', publicFlag: 'published',
                    title: 'إدارة التنبيهات والأذان',
                    fields: [
                      ('allowAdhan', 'السماح بتشغيل الأذان'),
                      ('testDelaySeconds', 'مدة انتظار الاختبار بالثواني (5–120)'),
                      ('adhanLateMinutes', 'إلغاء الأذان إذا تأخر (بالدقائق، 1 إلى 10، الافتراضي 2)'),
                      ('allowAdvance', 'السماح بالتنبيه قبل الصلاة'),
                      ('allowFollowup', 'السماح بمتابعة الصلاة'),
                      ('allowQiyam', 'السماح بتنبيه قيام الليل'),
                      ('qiyamTime', 'موعد تذكير قيام الليل (بعد العشاء)'),
                      ('allowMorningAzkar', 'السماح بتذكير أذكار الصباح'),
                      ('morningAzkarTime', 'موعد أذكار الصباح'),
                      ('allowEveningAzkar', 'السماح بتذكير أذكار المساء'),
                      ('eveningAzkarTime', 'موعد أذكار المساء'),
                      ('allowDailyDua', 'السماح بتذكير الدعاء اليومي'),
                      ('dailyDuaTime', 'موعد الدعاء اليومي'),
                      ('followupMinutes', 'متابعة الصلاة بعد عدد دقائق (5 إلى 120)'),
                      ('prayerBody', 'نص تنبيه حلول الصلاة'),
                      ('followupBody', 'نص متابعة الصلاة'),
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
              if (snapshot.hasError) const Text('تعذر تحميل الحالات. راجع صلاحيات Firestore.'),
              if (!snapshot.hasData && !snapshot.hasError) const LinearProgressIndicator(),
              if (snapshot.hasData && cases.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لم تتم إضافة حالات بعد')),
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

const _reliefGreen = Color(0xFF073E35);
const _reliefGold = Color(0xFFC6A35F);
const _reliefInk = Color(0xFF183C33);
const _reliefCream = Color(0xFFF8F5EC);

class PublicCasesScreen extends StatefulWidget {
  const PublicCasesScreen({super.key});
  @override
  State<PublicCasesScreen> createState() => _PublicCasesScreenState();
}

class _PublicCasesScreenState extends State<PublicCasesScreen> {
  final PageController pager = PageController();
  int selected = 0;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> casesStream =
    FirebaseFirestore.instance.collection('cases')
      .where('status', isEqualTo: 'published').snapshots();

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _reliefCream,
    appBar: AppBar(
      title: const Text('فك كرب',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      centerTitle: true,
      backgroundColor: _reliefGreen,
      foregroundColor: Colors.white),
    body: SafeArea(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: casesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الحالات، حاول مرة أخرى',
            style: TextStyle(color: _reliefInk)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _reliefGreen));
        }
        final cases = snapshot.data!.docs;
        if (cases.isEmpty) {
          return const Center(child: Text('لا توجد حالات منشورة حاليًا',
            style: TextStyle(color: _reliefGreen, fontSize: 18,
              fontWeight: FontWeight.w800)));
        }
        final current = selected.clamp(0, cases.length - 1);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF12604D), _reliefGreen]),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: _reliefGold, width: 1.2)),
              child: const Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.volunteer_activism_rounded,
                    color: _reliefGold, size: 23),
                  SizedBox(width: 8),
                  Flexible(child: Text('فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 20))),
                ]),
                SizedBox(height: 3),
                Text('ساهم في تفريج كرب محتاج ولو بالقليل',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFF0DFBC),
                    fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 9),
            Expanded(child: PageView.builder(
              controller: pager,
              itemCount: cases.length,
              onPageChanged: (page) => setState(() => selected = page),
              itemBuilder: (context, index) => RepaintBoundary(
                child: _ReliefCaseCard(
                  key: ValueKey(cases[index].id),
                  data: cases[index].data())),
            )),
            if (cases.length > 1) SizedBox(height: 42,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'الحالة السابقة',
                    onPressed: current == 0 ? null : () => pager.animateToPage(
                      current - 1, duration: const Duration(milliseconds: 230),
                      curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_right_rounded,
                      color: _reliefGreen)),
                  Text('${current + 1} / ${cases.length}',
                    style: const TextStyle(color: _reliefGreen,
                      fontWeight: FontWeight.w900)),
                  IconButton(
                    tooltip: 'الحالة التالية',
                    onPressed: current == cases.length - 1 ? null :
                      () => pager.animateToPage(current + 1,
                        duration: const Duration(milliseconds: 230),
                        curve: Curves.easeOut),
                    icon: const Icon(Icons.chevron_left_rounded,
                      color: _reliefGreen)),
                ]),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text('اللهم فرّج همّ كل مهموم ونفّس كرب كل مكروب',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: _reliefGreen,
                  fontWeight: FontWeight.w700, fontSize: 11))),
          ]),
        );
      },
    )),
  );
}

class _ReliefCaseCard extends StatelessWidget {
  const _ReliefCaseCard({super.key, required this.data});
  final Map<String, dynamic> data;

  List<String> get _photos {
    final result = <String>[];
    for (final field in ['images', 'imageUrls', 'attachments']) {
      final items = data[field];
      if (items is! List) continue;
      for (final item in items) {
        final value = item is String ? item :
          item is Map ? (item['url'] ?? '').toString() : '';
        final uri = Uri.tryParse(value);
        if (uri != null && uri.scheme == 'https' &&
            uri.host.isNotEmpty && !result.contains(value)) {
          result.add(value);
        }
      }
    }
    final old = (data['imageUrl'] ?? '').toString();
    final uri = Uri.tryParse(old);
    if (uri != null && uri.scheme == 'https' &&
        uri.host.isNotEmpty && !result.contains(old)) {
      result.insert(0, old);
    }
    return result.take(3).toList();
  }

  Future<void> _copy(BuildContext ctx, String title, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('تم نسخ $title')));
    }
  }

  Widget _payment(BuildContext ctx, String title, String value, IconData icon) =>
    Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: _reliefGold)),
      child: ListTile(
        onTap: () => _copy(ctx, title, value),
        leading: Icon(icon, color: _reliefGreen),
        title: Text(title, style: const TextStyle(
          color: _reliefGreen, fontWeight: FontWeight.w900)),
        subtitle: Text(value, textDirection: TextDirection.ltr,
          style: const TextStyle(color: _reliefInk,
            fontSize: 17, fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.copy_rounded, color: _reliefGreen),
      ),
    );

  void _showPayments(BuildContext context) {
    final vodafone = (data['vodafoneCash'] ?? '').toString().trim();
    final instapay = (data['instapay'] ?? '').toString().trim();
    final other = (data['payment'] ?? '').toString().trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _reliefCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('طرق المساهمة', textAlign: TextAlign.center,
              style: TextStyle(color: _reliefGreen,
                fontWeight: FontWeight.w900, fontSize: 23)),
            const SizedBox(height: 8),
            if (vodafone.isNotEmpty)
              _payment(ctx, 'فودافون كاش', vodafone,
                Icons.phone_android_rounded),
            if (instapay.isNotEmpty)
              _payment(ctx, 'إنستا باي', instapay,
                Icons.account_balance_wallet_outlined),
            if (other.isNotEmpty) Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(other, textAlign: TextAlign.center,
                style: const TextStyle(color: _reliefInk,
                  fontSize: 15, fontWeight: FontWeight.w700))),
            if (vodafone.isEmpty && instapay.isEmpty && other.isEmpty)
              const Padding(padding: EdgeInsets.all(15),
                child: Text('لم تُحدد طرق المساهمة بعد')),
            const SizedBox(height: 12),
            const Text('تأكد من بيانات التحويل قبل إرسال أي مبلغ',
              style: TextStyle(color: _reliefInk, fontSize: 12)),
          ],
        )),
      )),
    );
  }

  void _showImages(BuildContext context) {
    final images = _photos;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا توجد صور أو مستندات لهذه الحالة بعد')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: _reliefCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .72,
        child: Column(children: [
          const Text('صور ومستندات الحالة',
            style: TextStyle(color: _reliefGreen,
              fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Expanded(child: PageView.builder(
            itemCount: images.length,
            itemBuilder: (_, index) => InteractiveViewer(
              minScale: 1, maxScale: 5,
              child: Image.network(images[index],
                fit: BoxFit.contain,
                cacheWidth: 1600,
                errorBuilder: (_, error, stack) =>
                  const Center(child: Text('تعذر عرض المستند'))),
            ),
          )),
          const SizedBox(height: 8),
          const Text('اسحب للتنقل • كبّر الصورة بإصبعين',
            style: TextStyle(color: _reliefInk, fontSize: 12)),
          const SizedBox(height: 12),
        ]),
      )),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context, backgroundColor: _reliefCream,
      showDragHandle: true, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            Text((data['title'] ?? 'حالة مساعدة').toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _reliefGreen,
                fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text((data['details'] ?? '').toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _reliefInk,
                fontSize: 16, height: 1.6)),
          ],
        )),
      )),
    );
  }

  Widget _metric(String title, double amount) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF68736C),
          fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown,
        child: Text('${amount.toStringAsFixed(0)} ج.م',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _reliefGreen,
            fontSize: 18, fontWeight: FontWeight.w900))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final goal = (data['goal'] as num?)?.toDouble() ?? 0;
    final paid = (data['collected'] as num?)?.toDouble() ?? 0;
    final remaining = (goal - paid).clamp(0.0, double.infinity);
    final fraction = goal <= 0 ? 0.0 : (paid / goal).clamp(0.0, 1.0);
    final title = (data['title'] ?? 'حالة مساعدة').toString();
    final details = (data['details'] ?? '').toString().trim();
    final photoCount = _photos.length;
    return Center(child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: 356, height: 484,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFDFC893), width: 1.3),
            boxShadow: const [BoxShadow(
              color: Color(0x16073E35), blurRadius: 13,
              offset: Offset(0, 5))]),
          child: Column(children: [
            const Icon(Icons.favorite_rounded,
              color: _reliefGold, size: 30),
            const SizedBox(height: 8),
            Text(title,
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _reliefGreen,
                fontWeight: FontWeight.w900, fontSize: 24)),
            const SizedBox(height: 9),
            Text(details.isEmpty
                ? 'ساهم في تفريج كرب هذه الحالة' : details,
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _reliefInk, height: 1.6,
                fontSize: 14, fontWeight: FontWeight.w700)),
            if (details.length > 80) SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () => _showDetails(context),
                child: const Text('قراءة التفاصيل',
                  style: TextStyle(color: _reliefGreen,
                    fontWeight: FontWeight.w900)))),
            const Spacer(),
            Container(
              height: 78,
              decoration: BoxDecoration(
                color: _reliefCream,
                borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                _metric('الهدف', goal),
                const SizedBox(width: 1, height: 35,
                  child: ColoredBox(color: Color(0xFFE3D4B7))),
                _metric('تم جمعه', paid),
                const SizedBox(width: 1, height: 35,
                  child: ColoredBox(color: Color(0xFFE3D4B7))),
                _metric('المتبقي', remaining),
              ]),
            ),
            const SizedBox(height: 17),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: fraction, minHeight: 10,
                backgroundColor: const Color(0xFFECE4D7),
                color: const Color(0xFF16735C))),
            const SizedBox(height: 9),
            Text('تم تحقيق ${(fraction * 100).toStringAsFixed(0)}٪ من الهدف',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _reliefGreen,
                fontSize: 13, fontWeight: FontWeight.w900)),
            const Spacer(),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => _showPayments(context),
                icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
                label: const Text('ساهم الآن',
                  style: TextStyle(fontWeight: FontWeight.w900)),
                style: FilledButton.styleFrom(
                  backgroundColor: _reliefGreen, foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))))),
              const SizedBox(width: 9),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _showImages(context),
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: Text(photoCount == 0
                    ? 'المستندات' : 'المستندات ($photoCount)',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _reliefGreen,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  side: const BorderSide(color: _reliefGold, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))))),
            ]),
          ]),
        ),
      ),
    ));
  }
}
