import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw StateError('auth');
      final request = await client.getUrl(Uri.parse('https://athr-notifications.ahmedax0100.workers.dev/analytics'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(const Duration(seconds: 35));
      final raw = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('service ${response.statusCode}');
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => data = value);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر جلب الإحصائيات. تحقق من الاتصال وربط خدمة Analytics وصلاحيات القراءة.');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => loading = false);
    }
  }

  Widget metric(String label, String key, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text('${data?[key] ?? '—'}', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    )),
  );

  Widget rows(String key, String heading, {bool dates = false}) {
    final items = (data?[key] as List?) ?? [];
    var max = 1.0;
    for (final row in items) {
      final value = (row['count'] as num).toDouble();
      if (value > max) max = value;
    }
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (items.isEmpty) const Text('لا توجد بيانات للفترة الحالية'),
        for (final row in items) ...[
          Row(children: [
            Expanded(child: Text(dates && row['label'].toString().length == 8
              ? '${row['label'].toString().substring(6)}/${row['label'].toString().substring(4, 6)}'
              : row['label'].toString())),
            Text('${row['count']}'),
          ]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: (row['count'] as num).toDouble() / max),
          const SizedBox(height: 12),
        ],
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إحصائيات التطبيق'), actions: [
      IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
    ]),
    body: RefreshIndicator(onRefresh: load, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        const Text('Google Analytics • بيانات مجمعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const Text('المستخدمون ليسوا عدد التنزيلات. التقارير اليومية قد تتأخر، والتحديث المباشر يغطي آخر 30 دقيقة.'),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
        if (data != null) ...[
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2, children: [
              metric('إجمالي المستخدمين منذ التفعيل', 'total', Icons.groups_outlined),
              metric('آخر 30 دقيقة', 'live', Icons.online_prediction),
              metric('النشطون اليوم', 'today', Icons.today),
              metric('الجدد اليوم', 'newToday', Icons.person_add_alt),
              metric('النشطون آخر 30 يومًا', 'month', Icons.calendar_month),
              metric('الجدد آخر 30 يومًا', 'newMonth', Icons.person_add_outlined),
            ]),
          rows('days', 'نشاط آخر 7 أيام', dates: true),
          rows('countries', 'أكثر الدول نشاطًا • 30 يومًا'),
          Text('آخر تحديث: ${data?['updatedAt'] ?? ''}'),
        ],
      ],
    )),
  );
}
