import 'dart:math';
import 'dart:async';
import 'khatma_push.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'athr_qcf_mushaf_reader.dart';

const _starts = <int>[1,22,42,62,82,102,121,142,162,182,201,222,242,262,282,302,322,342,362,382,402,422,442,462,482,502,522,542,562,582];
const _green = Color(0xFF075143);
int _firstPage(int part) => _starts[part - 1];
int _lastPage(int part) => part == 30 ? 604 : _starts[part] - 1;
String _range(int part) => 'صفحة ${_firstPage(part)} إلى ${_lastPage(part)}';

class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});
  @override State<KhatmaScreen> createState() => _KhatmaScreenState();
}
class _KhatmaScreenState extends State<KhatmaScreen> {
  User? user;
  String? error;
  String? guestName;
  final guestInput = TextEditingController();
  @override void dispose() { guestInput.dispose(); super.dispose(); }
  Future<void> saveGuest() async {
    final value = guestInput.text.trim();
    if (value.length < 2 || value.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسمك من حرفين إلى 60 حرفًا')));
      return;
    }
    await SharedPreferences.getInstance().then((p) => p.setString('khatma_guest_name', value));
    if (mounted) setState(() => guestName = value);
  }
  @override void initState() { super.initState(); _login(); }
  Future<void> _login() async {
    try {
      final auth = FirebaseAuth.instance;
      final u = auth.currentUser ?? (await auth.signInAnonymously()).user;
      final prefs = await SharedPreferences.getInstance();
      unawaited(KhatmaPush.registerCurrent());
      if (mounted) setState(() { user = u; guestName = prefs.getString('khatma_guest_name'); });
    } catch (_) {
      if (mounted) setState(() => error = 'يجب تفعيل تسجيل الدخول المجهول Anonymous في Firebase Authentication لاستخدام الختمات.');
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الختمات الجماعية')),
    body: error != null ? Center(child: Padding(padding: const EdgeInsets.all(20),child: Text(error!,textAlign:TextAlign.center))) :
    user == null ? const Center(child: CircularProgressIndicator()) :
    guestName == null ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.person_outline, size: 60, color: _green),
      const SizedBox(height: 16),
      const Text('الدخول كضيف', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('اكتب اسمك فقط للمشاركة في الختمات، بدون بريد إلكتروني أو كلمة مرور.'),
      const SizedBox(height: 18),
      TextField(controller: guestInput, maxLength: 60, textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'اسمك', hintText: 'مثال: أحمد وكيل', border: OutlineInputBorder()), onSubmitted: (_) => saveGuest()),
      FilledButton.icon(onPressed: saveGuest, icon: const Icon(Icons.login), label: const Text('متابعة كضيف')),
    ])) :
    ListView(padding: const EdgeInsets.all(16), children: [
      OutlinedButton.icon(onPressed: () async {
        try { await KhatmaPush.enable(); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تسجيل جهازك لاستقبال تذكيرات الختمات'))); }
        catch(e){if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تفعيل الإشعارات: $e')));}
      },icon:const Icon(Icons.notifications_active_outlined),label:const Text('تفعيل إشعارات الختمات')),
      ListTile(title: Text('أهلًا، $guestName'), subtitle: const Text('مشارك كضيف'), trailing: IconButton(tooltip: 'تغيير الاسم', icon: const Icon(Icons.edit_outlined), onPressed: () { guestInput.text = guestName!; setState(() => guestName = null); })),
      FilledButton.icon(onPressed: () => Navigator.push(context,MaterialPageRoute<void>(builder: (_) => KhatmaCreateScreen(uid:user!.uid,guestName:guestName!))),
        icon: const Icon(Icons.add),label: const Text('إنشاء ختمة')),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: () => _joinCode(context,user!.uid),
        icon: const Icon(Icons.key),label: const Text('الانضمام بكود الختمة')),
      const SizedBox(height: 20),
      const Text('الختمات العامة',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('khatmas').where('privacy',isEqualTo:'public').snapshots(),
        builder: (context,s) {
          if(s.hasError) return const Text('تعذر عرض الختمات؛ راجع صلاحيات Firestore.');
          if(!s.hasData) return const Center(child:CircularProgressIndicator());
          if(s.data!.docs.isEmpty) return const Padding(padding:EdgeInsets.all(20),child:Text('لا توجد ختمات عامة حاليًا'));
          return Column(children:[for(final doc in s.data!.docs) _tile(context,doc,user!.uid)]);
        }),
      const SizedBox(height: 20),
      const Text('ختماتي',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('khatmas').where('memberIds',arrayContains:user!.uid).snapshots(),
        builder:(context,s) {
          if(s.hasError) return const Text('تعذر تحميل ختماتك');
          if(!s.hasData) return const Center(child:CircularProgressIndicator());
          if(s.data!.docs.isEmpty) return const Text('لم تنضم إلى ختمة بعد');
          return Column(children:[for(final doc in s.data!.docs) _tile(context,doc,user!.uid)]);
        }),
    ]),
  );
  Widget _tile(BuildContext ctx,QueryDocumentSnapshot<Map<String,dynamic>> doc,String uid) {
    final d=doc.data();
    final count=(d['memberCount'] as num?)?.toInt()??0;
    final max=(d['capacity'] as num?)?.toInt()??10;
    return Card(child:ListTile(
      title:Text((d['title']??'ختمة جماعية').toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text('$count / $max مشاركين • ${d['privacy']=='private'?'خاصة':'عامة'}'),
      trailing:const Icon(Icons.chevron_left),
      onTap:()=>Navigator.push(ctx,MaterialPageRoute<void>(builder:(_)=>KhatmaDetailsScreen(id:doc.id,uid:uid))),
    ));
  }
  Future<void> _joinCode(BuildContext context,String uid) async {
    final input=TextEditingController();
    final code=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('كود الانضمام'),
      content:TextField(controller:input,keyboardType:TextInputType.number,
        decoration:const InputDecoration(hintText:'أدخل كود الختمة المكون من 6 أرقام')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,input.text.trim()),child:const Text('بحث'))]));
    input.dispose();
    if(code==null||code.isEmpty||!context.mounted)return;
    try {
      final found=await FirebaseFirestore.instance.collection('khatmas').doc(code).get();
      if(!context.mounted)return;
      if(!found.exists) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الكود غير موجود')));return; }
      Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>KhatmaDetailsScreen(id:found.id,uid:uid)));
    } catch (_) { if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر البحث عن الكود'))); }
  }
}

class KhatmaCreateScreen extends StatefulWidget {
  const KhatmaCreateScreen({super.key,required this.uid,required this.guestName});
  final String uid,guestName;
  @override State<KhatmaCreateScreen> createState()=>_KhatmaCreateScreenState();
}
class _KhatmaCreateScreenState extends State<KhatmaCreateScreen> {
  final title=TextEditingController(), name=TextEditingController();
  final daysInput=TextEditingController(text:'30'), capacityInput=TextEditingController(text:'10');
  int days=30, capacity=10;
  bool private=false, manual=false, busy=false;
  @override void initState() { super.initState(); name.text = widget.guestName; }
  @override void dispose(){title.dispose();name.dispose();daysInput.dispose();capacityInput.dispose();super.dispose();}
  Future<void> create() async {
    days=int.tryParse(daysInput.text)??0;capacity=int.tryParse(capacityInput.text)??0;
    if(title.text.trim().isEmpty||name.text.trim().length<2||days<1||days>365||capacity<2||capacity>30){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('المدة من 1 إلى 365 يومًا والمشاركون من 2 إلى 30')));return;}
    setState(()=>busy=true);
    try {
      // Six-digit numeric room IDs; existing rooms retain their original IDs.
      final collection=FirebaseFirestore.instance.collection('khatmas');
      final doc=collection.doc((100000+Random.secure().nextInt(900000)).toString());
      final code=doc.id;
      final batch=FirebaseFirestore.instance.batch();
      batch.set(doc,{
        'title':title.text.trim(),'creatorId':widget.uid,'creatorName':name.text.trim(),
        'code':code,'privacy':private?'private':'public',
        'distribution':manual?'manual':'auto','capacity':capacity,'memberCount':1,
        'memberIds':[widget.uid],'completedParts':<int>[],'started':false,
        'createdAt':FieldValue.serverTimestamp(),
        'deadline':Timestamp.fromDate(DateTime.now().add(Duration(days:days))),
      });
      batch.set(doc.collection('members').doc(widget.uid),{
        'name':name.text.trim(),'joinedAt':FieldValue.serverTimestamp(),
        'slot':0,'parts':<int>[],
        'completed':<int>[],
      });
      await batch.commit();
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute<void>(builder:(_)=>KhatmaDetailsScreen(id:doc.id,uid:widget.uid)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشل إنشاء الختمة: ${e is FirebaseException?e.code:e.toString()}')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('إنشاء ختمة')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'الختمة باسم مين؟',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك في الختمة',border:OutlineInputBorder())),
      const SizedBox(height:16),
      TextField(controller:daysInput,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(labelText:'مدة الختمة بالأيام',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:capacityInput,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(labelText:'عدد المشاركين',border:OutlineInputBorder())),
      SwitchListTile(title:const Text('ختمة خاصة — بالكود فقط'),value:private,onChanged:(v)=>setState(()=>private=v)),
      SwitchListTile(title:const Text('توزيع مخصص بواسطة المنشئ'),subtitle:const Text('بدون التفعيل توزع الأجزاء تلقائيًا'),value:manual,onChanged:(v)=>setState(()=>manual=v)),
      const SizedBox(height:16),
      FilledButton(onPressed:busy?null:create,child:Text(busy?'جارٍ الإنشاء...':'إنشاء الختمة')),
    ]),
  );
}

class KhatmaDetailsScreen extends StatefulWidget {
  const KhatmaDetailsScreen({super.key,required this.id,required this.uid});
  final String id,uid;
  @override State<KhatmaDetailsScreen> createState()=>_KhatmaDetailsScreenState();
}
class _KhatmaDetailsScreenState extends State<KhatmaDetailsScreen> {
  final name=TextEditingController();
  bool busy=false;
  DocumentReference<Map<String,dynamic>> get ref=>FirebaseFirestore.instance.collection('khatmas').doc(widget.id);
  @override void initState() { super.initState(); _loadName(); }
  Future<void> _loadName() async { final prefs = await SharedPreferences.getInstance(); if (mounted) name.text = prefs.getString('khatma_guest_name') ?? ''; }
  @override void dispose(){name.dispose();super.dispose();}
  void message(String value){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));}
  Future<void> join(Map<String,dynamic> d) async {
    if (busy) return;
    final guest = name.text.trim();
    if(guest.length < 2 || guest.length > 60){message('اكتب اسمًا من حرفين إلى 60 حرفًا');return;}
    setState(()=>busy=true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap=await tx.get(ref);
        if(!snap.exists)throw StateError('missing');
        final data=snap.data()!;
        final memberRef=ref.collection('members').doc(widget.uid);
        final existing=await tx.get(memberRef);
        if(existing.exists)return;
        final count=(data['memberCount'] as num).toInt();
        final capacity=(data['capacity'] as num).toInt();
        if(count>=capacity)throw StateError('full');
        if(data['started']==true || data['closed']==true)throw StateError('started');
        final parts=<int>[];
        tx.set(memberRef,{'name':guest,'slot':count,'parts':parts,
          'completed':<int>[],'joinedAt':FieldValue.serverTimestamp()});
        tx.update(ref,{'memberCount':FieldValue.increment(1),
          'memberIds':FieldValue.arrayUnion([widget.uid])});
      });
      message('تم الانضمام بنجاح');
    }catch(e){message(e is FirebaseException ? (e.code == 'permission-denied' ? 'صلاحيات الانضمام مرفوضة؛ يجب تحديث قواعد Firestore' : 'تعذر الانضمام: ${e.code}') : e.toString().contains('full')?'اكتمل عدد المشاركين':e.toString().contains('started')?'بدأت الختمة أو أُغلقت':'تعذر الانضمام');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> leave() async {
    setState(()=>busy=true);
    try {
      if ((await ref.get()).data()?['creatorId'] == widget.uid) { message('الهوست لا يمكنه مغادرة الختمة'); setState(() => busy=false); return; }
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final m=ref.collection('members').doc(widget.uid);
        final member=await tx.get(m);
        if(!member.exists)return;
        if ((await tx.get(ref)).data()?['started'] == true) throw StateError('started');
        if (member.data()?['completed'] is List && (member.data()!['completed'] as List).isNotEmpty) throw StateError('completed');
        tx.delete(m);
        tx.update(ref,{'memberCount':FieldValue.increment(-1),
          'memberIds':FieldValue.arrayRemove([widget.uid])});
      });
      if(mounted)Navigator.pop(context);
    }catch(_){message('لا يمكن المغادرة بعد بدء الختمة أو إتمام أجزاء، أو حدث خطأ في الصلاحيات');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> startKhatma(Map<String,dynamic> d) async {
    if(d['creatorId']!=widget.uid||d['started']==true||d['closed']==true)return;
    setState(()=>busy=true);
    try {
      final members=await ref.collection('members').get();
      final ordered=members.docs.toList()..sort((a,b){
        final x=(a.data()['joinedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final y=(b.data()['joinedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final c=x.compareTo(y);
        return c!=0?c:a.id.compareTo(b.id);
      });
      final ids=ordered.map((m)=>m.id).toList();
      final batch=FirebaseFirestore.instance.batch();
      if(d['distribution']=='auto'){
        for(var i=0;i<ids.length;i++){
          final base=30 ~/ ids.length;
          final extra=30 % ids.length;
          final int first=1+i*base+(i<extra?i:extra);
          final int count=base+(i<extra?1:0);
          batch.update(ref.collection('members').doc(ids[i]),{'parts':List<int>.generate(count,(j)=>first+j)});
        }
      }
      batch.update(ref,{'started':true});
      await batch.commit();
      message('بدأت الختمة');
    }catch(e){message('تعذر البدء: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> extendDeadline() async {
    String input = '7';
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تمديد الختمة'),
        content: TextFormField(
          initialValue: '7',
          keyboardType: TextInputType.number,
          onChanged: (value) => input = value,
          decoration: const InputDecoration(labelText: 'أيام إضافية'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(input)),
            child: const Text('تمديد')),
        ],
      ),
    );
    if (!mounted || days == null || days < 1 || days > 365) return;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['creatorId'] != widget.uid ||
            snap.data()?['closed'] == true) {
          throw StateError('not allowed');
        }
        final old = (snap.data()?['deadline'] as Timestamp).toDate();
        tx.update(ref, {'deadline': Timestamp.fromDate(old.add(Duration(days: days)))});
      });
      message('تم تمديد الختمة بنجاح');
    } catch (e) { message('تعذر التمديد: $e'); }
  }

  Future<void> closeKhatma() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق الختمة'),
        content: const Text('سيتم إيقاف الانضمام وتسجيل الإنجاز، مع الاحتفاظ بالختمة وسجل المشاركين. هل تريد الإغلاق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإغلاق')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['creatorId'] != widget.uid ||
            snap.data()?['closed'] == true) {
          throw StateError('not allowed');
        }
        tx.update(ref, {'closed': true, 'closedAt': FieldValue.serverTimestamp()});
      });
      message('تم إغلاق الختمة');
    } catch (e) { message('تعذر الإغلاق: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> remindMembers({String? target}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final room = (await ref.get()).data();
      if (room == null || room['creatorId'] != widget.uid ||
          room['closed'] == true || room['started'] != true) {
        throw StateError('not allowed');
      }
      final members = await ref.collection('members').get();
      var sent = 0;
      var recorded = 0;
      var skipped = 0;
      for (final member in members.docs) {
        if (member.id == widget.uid || (target != null && member.id != target)) {
          continue;
        }
        final data = member.data();
        final parts = List<int>.from(data['parts'] ?? []);
        final done = List<int>.from(data['completed'] ?? []);
        if (parts.every(done.contains)) continue;
        try {
          final result = await KhatmaPush.remind(widget.id, member.id);
          if (result == 'sent') {
            sent++;
          } else if (result == 'recorded') {
            recorded++;
          } else {
            skipped++;
          }
        } catch (_) {
          skipped++;
        }
      }
      message('تم قبول إرسال إشعار لـ $sent مشارك، وتسجيل $recorded تذكير داخل التطبيق فقط، وتخطي $skipped (قد يكون السبب عدم تسجيل الجهاز أو مدة الانتظار أو خطأ الاتصال).');
    } catch (_) {
      message('تعذر تسجيل التذكير. تحقق من الاتصال وقواعد Firestore.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget reminderBanner() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: ref.collection('reminders').doc(widget.uid).snapshots(),
    builder: (context, snapshot) {
      final sent = snapshot.data?.data()?['sentAt'];
      if (sent is! Timestamp) return const SizedBox.shrink();
      return Card(child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined, color: _green),
        title: const Text('تذكير من صاحب الختمة'),
        subtitle: Text('لا تنسَ إكمال وردك من القرآن الكريم. ${sent.toDate().day}/${sent.toDate().month}'),
      ));
    },
  );

  Future<void> shareInvite() async {
    final msg='انضم إلى ختمتنا في أثر لا ينقطع. كود الدعوة: ${widget.id}';
    final url=Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    if(!await launchUrl(url,mode:LaunchMode.externalApplication)){
      await Clipboard.setData(ClipboardData(text:msg));message('تم نسخ الدعوة');
    }
  }
  Future<void> readPart(int part) async {
    final prefs=await SharedPreferences.getInstance();
    final key='khatma_${widget.id}_${widget.uid}_$part';
    final last=prefs.getInt(key)??_starts[part-1];
    if(!mounted)return;
    final finished=await Navigator.push<bool>(context,MaterialPageRoute<bool>(
      builder:(_)=>KhatmaPartReader(part:part,initialPage:last,onPage:(p)=>prefs.setInt(key,p))));
    if(finished==true){
      final current=await ref.collection('members').doc(widget.uid).get();
      if(List<int>.from(current.data()?['completed']??[]).contains(part))return;
      if(!await complete(part,true))return;
      if(!mounted)return;
      final title=(await ref.get()).data()?['title']?.toString()??'صاحب الختمة';
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topRight,end: Alignment.bottomLeft,colors:[Color(0xFF176451),Color(0xFF06372F)]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color:const Color(0xFFD6B56C),width:1.7),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.volunteer_activism_rounded,color:Color(0xFFFFD77A),size:48),
            const SizedBox(height:12),
            const Text('تقبّل الله تلاوتك',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFFFD77A),fontSize:26,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            const Text('تم تسجيل إتمام الجزء',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFE6D8B6),fontSize:14,fontWeight:FontWeight.w700)),
            const SizedBox(height:18),
            const Divider(color:Color(0xFFD6B56C)),
            const Text('اللهم إني وهبت أجر وثواب هذه التلاوة إلى',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFFFF5DA),fontSize:22,fontWeight:FontWeight.w900,height:1.7)),
            const SizedBox(height:12),
            Text(title,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFFFD77A),fontSize:24,fontWeight:FontWeight.w900,height:1.4)),
            const SizedBox(height:12),
            const Text('اللهم تقبّل مني',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFFFFF5DA),fontSize:20,fontWeight:FontWeight.w900)),
            const SizedBox(height:22),
            SizedBox(width:double.infinity,child:FilledButton(style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFD77A),foregroundColor:const Color(0xFF06372F),padding:const EdgeInsets.symmetric(vertical:14)),onPressed:()=>Navigator.pop(ctx),child:const Text('اللهم آمين',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)))),
          ])),
        ),
      ));
    }
  }
  Future<bool> complete(int part,bool done) async {
    try {
      final m=ref.collection('members').doc(widget.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap=await tx.get(m);
        final room=await tx.get(ref);
        if(room.data()?['started']!=true||room.data()?['closed']==true)throw StateError('room unavailable');
        if(!snap.exists||!List<int>.from(snap.data()?['parts']??[]).contains(part))throw StateError('not assigned');
        if(List<int>.from(snap.data()?['completed']??[]).contains(part)==done)return;
        tx.update(m,{'completed':done?FieldValue.arrayUnion([part]):FieldValue.arrayRemove([part])});
        tx.update(ref,{'completedParts':done?FieldValue.arrayUnion([part]):FieldValue.arrayRemove([part])});
      });
      return true;
    }catch(_){message('تعذر تحديث الجزء');return false;}
  }
  Future<void> assign(String uid,List<int> existing) async {
    final allMembers=await ref.collection('members').get();
    final occupied=<int>{};
    for(final doc in allMembers.docs){
      if(doc.id!=uid) occupied.addAll(List<int>.from(doc.data()['parts']??[]));
    }
    final selected=existing.toSet();
    if (!mounted) return;
    final result=await showDialog<Set<int>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('توزيع الأجزاء'),
      content:SizedBox(width:350,height:380,child:ListView(children:[
        for(var i=1;i<=30;i++)CheckboxListTile(title:Text('الجزء $i'),
          subtitle:Text(_range(i)),
          value:selected.contains(i),
          secondary:occupied.contains(i)?const Icon(Icons.lock_outline):null,
          onChanged:occupied.contains(i)?null:(v)=>update(()=>v==true?selected.add(i):selected.remove(i))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,selected),child:const Text('حفظ'))])));
    if(result==null)return;
    try {
      final m=ref.collection('members').doc(uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final members=await tx.get(ref);
        if (members.data()?['creatorId'] != widget.uid) throw StateError('host');
        final others=<DocumentSnapshot<Map<String,dynamic>>>[];
        for(final doc in allMembers.docs){
          if(doc.id!=uid) others.add(await tx.get(doc.reference));
        }
        if(others.any((other)=>List<int>.from(other.data()?['parts']??[]).any(result.contains))) throw StateError('duplicate assignment');
        final snap=await tx.get(m);
        final oldDone=List<int>.from(snap.data()?['completed']??[]);
        final keep=oldDone.where(result.contains).toList();
        tx.update(m,{'parts':result.toList()..sort(),'completed':keep});
        if (keep.length != oldDone.length) throw StateError('completed parts cannot be removed');
      });
      message('تم حفظ التوزيع');
    }catch(_){message('تعذر حفظ التوزيع');}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('تفاصيل الختمة')),
    body:StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream:ref.snapshots(),builder:(context,s){
        if(s.hasError)return const Center(child:Text('تعذر فتح الختمة؛ تحقق من الكود والصلاحيات'));
        if(!s.hasData)return const Center(child:CircularProgressIndicator());
        if(!s.data!.exists)return const Center(child:Text('الختمة غير موجودة'));
        final d=s.data!.data()!;
        final creator=d['creatorId']==widget.uid;
        final count=(d['memberCount'] as num?)?.toInt()??0;
        final capacity=(d['capacity'] as num?)?.toInt()??10;
        final completed=List<int>.from(d['completedParts']??[]);
        final started=d['started']==true;
        final closed=d['closed']==true;
        return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          stream:ref.collection('members').doc(widget.uid).snapshots(),
          builder:(context,m){
            final mine=m.hasError ? null : m.data?.data();
            final isMember = (d['memberIds'] as List?)?.contains(widget.uid) ?? false;
            return ListView(padding:const EdgeInsets.all(16),children:[
              Container(
                padding:const EdgeInsets.all(20),
                decoration:BoxDecoration(
                  gradient:const LinearGradient(colors:[Color(0xFF075143),Color(0xFF032E29)]),
                  borderRadius:BorderRadius.circular(24)),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    const Icon(Icons.auto_stories,color:Color(0xFFE9C77C)),
                    const SizedBox(width:8),
                    Expanded(child:Text((d['title']??'ختمة جماعية').toString(),
                      style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900))),
                  ]),
                  const SizedBox(height:8),
                  Text(closed?'ختمة مغلقة':started?'ختمة جارية':'في انتظار بدء الختمة',
                    style:const TextStyle(color:Color(0xFFE9C77C),fontWeight:FontWeight.bold)),
                  const SizedBox(height:18),
                  Row(children:[
                    SizedBox(width:90,height:90,child:Stack(alignment:Alignment.center,children:[
                      SizedBox.expand(child:CircularProgressIndicator(
                        value:completed.length/30,strokeWidth:9,
                        backgroundColor:Colors.white24,
                        color:const Color(0xFFE9C77C))),
                      Text('${(completed.length*100/30).round()}%',
                        style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
                    ])),
                    const SizedBox(width:18),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text('المكتمل: ${completed.length} من 30 جزء',
                        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
                      const SizedBox(height:8),
                      Text('المتبقي: ${30-completed.length} جزء',
                        style:const TextStyle(color:Colors.white70)),
                      const SizedBox(height:8),
                      Text('المشاركون: $count من $capacity',
                        style:const TextStyle(color:Colors.white70)),
                    ])),
                  ]),
                ]),
              ),
              const SizedBox(height:16),
              if(creator&&!started&&!closed) FilledButton(onPressed:busy?null:()=>startKhatma(d),child:const Text('بدء الختمة وتوزيع الأجزاء')),
              if(!started) const Text('في انتظار بدء الختمة'),
              if(creator&&started&&!closed&&completed.length<30)
                FilledButton.icon(onPressed:busy?null:()=>remindMembers(),
                  icon:const Icon(Icons.notifications_active_outlined),
                  label:const Text('تذكير المشاركين الذين لم يكملوا')),
              if(mine!=null&&!creator&&started&&!closed &&
                  List<int>.from(mine['parts']??[]).any((p)=>!List<int>.from(mine['completed']??[]).contains(p)))
                reminderBanner(),
              if(creator&&!closed) TextButton(onPressed:extendDeadline,child:const Text('تمديد موعد الختمة')),
              if(creator&&!closed) OutlinedButton.icon(onPressed:busy?null:closeKhatma,
                icon:const Icon(Icons.lock_outline),label:const Text('إغلاق الختمة')),
              if(closed) const Card(child:ListTile(leading:Icon(Icons.lock_outline),title:Text('هذه الختمة مغلقة'),subtitle:Text('يمكن عرض سجل القراءة، لكن لا يمكن تسجيل إنجاز جديد'))),
              if(completed.length==30) const Card(child:ListTile(title:Text('مبارك اكتمال الختمة'),subtitle:Text('اللهم تقبل منا وأهد ثوابها لمن نُويت له'))),
              const SizedBox(height:12),
              Card(child:ListTile(title:Text('كود الانضمام: ${d['code']}'),
                trailing:IconButton(icon:const Icon(Icons.copy),onPressed:() async {
                  await Clipboard.setData(ClipboardData(text:d['code'].toString()));message('تم نسخ الكود');
                }))),
              OutlinedButton.icon(onPressed:shareInvite,icon:const Icon(Icons.share),label:const Text('مشاركة عبر واتساب')),
              if (mine == null && isMember) ...[
                const Card(child: ListTile(title: Text('أنت منضم بالفعل'), subtitle: Text('جارٍ تحميل بيانات مشاركتك. تحقق من الاتصال والصلاحيات إذا استمرت المشكلة.'))),
              ] else if(mine==null) ...[
                TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك عند الانضمام')),
                const SizedBox(height:10),
                FilledButton(onPressed:busy||count>=capacity||started||closed?null:()=>join(d),
                  child:Text(closed?'الختمة مغلقة':started?'بدأت الختمة':count>=capacity?'الختمة مكتملة العدد':'انضم للختمة')),
              ] else ...[
                const SizedBox(height:12),
                const Row(children:[Icon(Icons.menu_book,color:_green),SizedBox(width:8),Text('أجزائي',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900))]),
                for(final p in List<int>.from(mine['parts']??[])..sort())
                  Card(child:Column(children:[
                    ListTile(title:Text('الجزء $p',style:const TextStyle(fontWeight:FontWeight.w800)),
                      subtitle:Text('${_range(p)} • ${List<int>.from(mine['completed']??[]).contains(p)?'مكتمل':'بانتظار القراءة'}'),
                      trailing:Icon(List<int>.from(mine['completed']??[]).contains(p)?Icons.check_circle:Icons.menu_book,color:_green)),
                    Row(children:[
                      Expanded(child:TextButton.icon(onPressed:started&&!closed?()=>readPart(p):null,
                        icon:const Icon(Icons.menu_book),label:Text(List<int>.from(mine['completed']??[]).contains(p)?'إعادة القراءة':'قراءة الجزء'))),
                    ]),
                  ])),
                if((mine['parts'] as List?)?.isEmpty??true)
                  const Text('لم تُخصص لك أجزاء بعد. انتظر توزيع المنشئ.'),
                TextButton.icon(onPressed:busy?null:leave,icon:const Icon(Icons.exit_to_app),
                  label:const Text('مغادرة الختمة')),
              ],
              const Divider(height:30),
              const Text('الأجزاء الثلاثون',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
              Wrap(spacing:8,runSpacing:8,children:[
                for(var p=1;p<=30;p++)Chip(label:Text('$p'),
                  avatar:Icon(completed.contains(p)?Icons.check_circle:Icons.circle_outlined,
                    color:completed.contains(p)?Colors.green:Colors.grey,size:18)),
              ]),
              const SizedBox(height:16),
              const Row(children:[Icon(Icons.people_alt_outlined,color:_green),SizedBox(width:8),Text('المشاركون',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))]),
              StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream:ref.collection('members').snapshots(),builder:(context,ms){
                  if(ms.hasError)return const Text('المشاركون يظهرون بعد الانضمام');
                  if(!ms.hasData)return const Center(child:CircularProgressIndicator());
                  return Column(children:[for(final member in ms.data!.docs)
                    Card(child:ListTile(
                      title:Text((member.data()['name']??'مشارك').toString()),
                      subtitle:Text('الأجزاء: ${(List<int>.from(member.data()['parts']??[])..sort()).join('، ')} • المكتمل: ${(member.data()['completed'] as List?)?.length??0}'),
                      trailing: creator ? Row(mainAxisSize: MainAxisSize.min, children: [
                        if (started && !closed && member.id != widget.uid && List<int>.from(member.data()['parts']??[]).any((p)=>!List<int>.from(member.data()['completed']??[]).contains(p)))
                          IconButton(tooltip: 'تذكير المشارك', icon: const Icon(Icons.notifications_outlined), onPressed: busy ? null : ()=>remindMembers(target: member.id)),
                        if (d['distribution']=='manual' && !closed)
                          IconButton(icon:const Icon(Icons.edit),onPressed:()=>assign(member.id,List<int>.from(member.data()['parts']??[]))),
                      ]) : null,
                    )),
                  ]);
                }),
            ]);
          });
      }),
  );
}

// Khatmas always open the shared Ottoman reader, regardless of the global reader preference.
class KhatmaPartReader extends StatelessWidget {
  const KhatmaPartReader({
    super.key,
    required this.part,
    required this.initialPage,
    required this.onPage,
  });
  final int part, initialPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => AthrQcfMushafReader(
    initialPage: initialPage,
    firstPage: _firstPage(part),
    lastPage: _lastPage(part),
    onPage: onPage,
  );
}
