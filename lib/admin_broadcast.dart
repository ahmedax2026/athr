import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});
  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}
class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  bool busy = false;
  static const green = Color(0xFF063D33);
  static const gold = Color(0xFFD9BC7D);
  @override
  void dispose() { title.dispose(); body.dispose(); super.dispose(); }
  void notice(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  Future<void> send(bool test) async {
    if (busy) return;
    final heading = title.text.trim(), message = body.text.trim();
    if (heading.isEmpty || message.isEmpty || heading.length > 100 || message.length > 500) {
      notice('أدخل عنوانًا ومحتوى صالحين'); return;
    }
    if (!test) {
      final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('إرسال لجميع المستخدمين؟'),
        content: const Text('سيُرسل الإشعار إلى الأجهزة المشتركة في الإشعارات العامة.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الإرسال'))],
      ));
      if (yes != true || !mounted || busy) return;
    }
    setState(() => busy = true);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final auth = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (auth == null) throw StateError('سجل الدخول مجددًا');
      final testToken = test ? await FirebaseMessaging.instance.getToken() : null;
      if (test && testToken == null) throw StateError('تعذر تسجيل الجهاز');
      final request = await client.postUrl(Uri.parse('https://athr-notifications.ahmedax0100.workers.dev/broadcast'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $auth');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'title': heading, 'body': message, if (test) 'testToken': testToken}));
      final response = await request.close().timeout(const Duration(seconds: 30));
      final result = jsonDecode(await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 15)));
      if (response.statusCode != 200 || result is! Map || result['sent'] != true) throw StateError('رفضت الخدمة الإرسال (${response.statusCode})');
      notice(test ? 'تم قبول إرسال التجربة لجهازك' : 'قبلت Firebase طلب الإرسال للجميع');
      try {
        await FirebaseFirestore.instance.collection('admin_audit').add({
          'actorUid': FirebaseAuth.instance.currentUser!.uid, 'createdAt': FieldValue.serverTimestamp(),
          'type': 'broadcast', 'title': heading, 'body': message, 'test': test,
        });
      } catch (_) { notice('تم قبول الإرسال لكن تعذر حفظ السجل'); }
    } catch (e) { notice('تعذر الإرسال: $e'); }
    finally { client.close(force: true); if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مركز الإشعارات')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(24), border: Border.all(color: gold)),
        child: const Column(children: [Icon(Icons.campaign_rounded, color: gold, size: 44), SizedBox(height: 8), Text('تواصل مع الجميع', style: TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 24)), Text('أثر لا ينقطع • الإشعارات العامة', style: TextStyle(color: Colors.white))])),
      const SizedBox(height: 20),
      TextField(controller: title, maxLength: 100, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'عنوان الإشعار', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: body, maxLength: 500, maxLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'محتوى الإشعار', border: OutlineInputBorder())),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.notifications_active_outlined), SizedBox(width: 8), Text('معاينة • الآن')]),
        const SizedBox(height: 10), Text(title.text.isEmpty ? 'عنوان الإشعار' : title.text, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(body.text.isEmpty ? 'محتوى الإشعار' : body.text),
      ]))),
      const SizedBox(height: 16),
      if (busy) const LinearProgressIndicator(),
      FilledButton.icon(onPressed: busy ? null : () => send(false), style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: gold, padding: const EdgeInsets.all(16)), icon: const Icon(Icons.send_rounded), label: const Text('إرسال للجميع')),
      OutlinedButton.icon(onPressed: busy ? null : () => send(true), icon: const Icon(Icons.phone_android), label: const Text('تجربة على جهازي')),
      const SizedBox(height: 20), const Text('آخر الإشعارات المرسلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: FirebaseFirestore.instance.collection('admin_audit').orderBy('createdAt', descending: true).limit(50).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return const Text('تعذر قراءة السجل');
          if (!snap.hasData) return const LinearProgressIndicator();
          final docs = snap.data!.docs.where((d) => d.data()['type'] == 'broadcast');
          if (docs.isEmpty) return const Text('لا توجد إشعارات في السجل الأخير');
          return Column(children: [for (final doc in docs) Card(child: ListTile(leading: const Icon(Icons.history), title: Text(doc.data()['title'].toString()), subtitle: Text(doc.data()['body'].toString()), trailing: Text(doc.data()['test'] == true ? 'تجربة' : 'عام')))]);
        }),
    ]))),
  );
}
