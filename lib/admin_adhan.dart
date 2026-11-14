import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'adhan_catalog.dart';

class AdminAdhanScreen extends StatefulWidget {
  const AdminAdhanScreen({super.key});
  @override
  State<AdminAdhanScreen> createState() => _AdminAdhanScreenState();
}
class _AdminAdhanScreenState extends State<AdminAdhanScreen> {
  final player = AudioPlayer();
  final ref = FirebaseFirestore.instance.collection('content').doc('adhan_voices');
  bool busy = false;
  bool previewLoading = false;
  String? playingId;
  StreamSubscription<void>? finished;
  @override
  void initState() {
    super.initState();
    finished = player.onPlayerComplete.listen((_) { if (mounted) setState(() => playingId = null); });
  }
  Future<void> stopPreview() async {
    await player.stop();
    if (mounted) setState(() => playingId = null);
  }
  @override
  void dispose() {
    finished?.cancel();
    player.dispose();
    super.dispose();
  }
  void message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Future<void> editVoice([Map<String, dynamic>? old]) async {
    var name = old?['name']?.toString() ?? '';
    var url = old?['url']?.toString() ?? '';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(old == null ? 'إضافة صوت أذان' : 'تعديل صوت الأذان'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(initialValue: name, maxLength: 80, onChanged: (v) => name = v.trim(),
          decoration: const InputDecoration(labelText: 'اسم المؤذن')),
        TextFormField(initialValue: url, onChanged: (v) => url = v.trim(),
          keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط HTTPS مباشر MP3')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ));
    if (ok != true || !mounted || busy) return;
    if (name.isEmpty || name.length > 80 || !AdhanCatalog.validUrl(url) || url.length > 2048) {
      message('أدخل اسمًا ورابط HTTPS مباشر ينتهي بـ MP3');
      return;
    }
    setState(() => busy = true);
    try {
      // Changing the URL creates a new cache identifier, so old downloads stay valid.
      final id = old != null && old['url'] == url ? old['id'].toString()
          : 'remote_${DateTime.now().microsecondsSinceEpoch}';
      await ref.firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final items = List<Map<String, dynamic>>.from(
          ((snap.data()?['voices'] as List?) ?? []).map((x) => Map<String, dynamic>.from(x as Map)));
        if (old != null) items.removeWhere((x) => x['id'] == old['id']);
        if (items.length >= 20) throw StateError('limit');
        items.add({'id': id, 'name': name, 'url': url});
        tx.set(ref, {'published': true, 'voices': items, 'updatedAt': FieldValue.serverTimestamp()});
      });
      message('تم حفظ الرابط. استخدم زر المعاينة للتحقق من تشغيله');
    } on FirebaseException catch (e) {
      message(e.code == 'permission-denied'
          ? 'لا توجد صلاحية لحفظ الصوت. تأكد من تسجيل الدخول بحساب الإدارة.'
          : 'تعذر حفظ الصوت في Firebase (${e.code}).');
    } on StateError catch (e) {
      final reason = e.message.toString();
      message(switch (reason) {
        'limit' => 'وصلت إلى الحد الأقصى: 20 صوتًا إضافيًا.',
        'redirect' => 'الرابط يعيد التوجيه إلى عنوان غير آمن أو غير صالح.',
        'file too large' => 'حجم الصوت يتجاوز 50 ميجابايت.',
        'invalid audio' || 'invalid MP3' => 'الملف ليس تسجيل MP3 صالحًا (من ثانية إلى 10 دقائق).',
        _ => reason.startsWith('HTTP ') ? 'خادم الصوت رفض التحميل ($reason).' : 'تعذر التحقق من ملف الصوت.',
      });
    } catch (_) {
      message('تعذر تحميل الصوت. تأكد من الإنترنت والرابط المباشر ثم حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> remove(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إزالة الصوت من القائمة؟'),
      content: const Text('لن يظهر للاختيار الجديد، لكن النسخ المحملة سابقًا قد تظل تعمل على أجهزة المستخدمين.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إزالة')),
      ],
    ));
    if (yes != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await ref.firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final items = List<Map<String, dynamic>>.from(
          ((snap.data()?['voices'] as List?) ?? []).map((x) => Map<String, dynamic>.from(x as Map)));
        items.removeWhere((x) => x['id'] == item['id']);
        tx.set(ref, {'published': true, 'voices': items, 'updatedAt': FieldValue.serverTimestamp()});
      });
    } catch (_) {
      message('تعذر إزالة الصوت');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> preview(Map<String, dynamic> item) async {
    if (previewLoading) return;
    final id = item['id'].toString(), url = item['url'].toString();
    if (playingId == id) { await stopPreview(); return; }
    setState(() { previewLoading = true; playingId = null; });
    try {
      await player.stop();
      try {
        await player.play(UrlSource(url)).timeout(const Duration(seconds: 20));
      } catch (_) {
        await player.stop();
        final path = await AdhanCatalog.download(id, url);
        if (!mounted) return;
        await player.play(DeviceFileSource(path));
      }
      if (mounted) setState(() => playingId = id);
    } catch (e) {
      message('تعذرت معاينة الصوت: $e');
    } finally {
      if (mounted) setState(() => previewLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة أصوات الأذان'), actions: [
      IconButton(onPressed: previewLoading ? null : stopPreview, icon: const Icon(Icons.stop_circle_outlined), tooltip: 'إيقاف المعاينة'),
    ]),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('تعذر تحميل القائمة'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final items = List<Map<String, dynamic>>.from(
          ((snap.data?.data()?['voices'] as List?) ?? []).map((x) => Map<String, dynamic>.from(x as Map)));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('الأصوات الأصلية محفوظة دائمًا. أضف تسجيلات مسموح بتوزيعها بروابط MP3 مباشرة.'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : () => editVoice(), icon: const Icon(Icons.add), label: const Text('إضافة صوت')),
          if (busy || previewLoading) const LinearProgressIndicator(),
          for (final item in items) Card(child: ListTile(
            title: Text(item['name'].toString()),
            subtitle: Text(item['url'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: busy || previewLoading ? null : () => preview(item), icon: Icon(playingId == item['id'] ? Icons.stop_circle_outlined : Icons.play_circle_outline), tooltip: playingId == item['id'] ? 'إيقاف' : 'معاينة'),
              IconButton(onPressed: busy ? null : () => editVoice(item), icon: const Icon(Icons.edit_outlined), tooltip: 'تعديل'),
              IconButton(onPressed: busy ? null : () => remove(item), icon: const Icon(Icons.delete_outline), tooltip: 'إزالة'),
            ]),
          )),
        ]);
      },
    ),
  );
}
