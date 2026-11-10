import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _starts = <int>[1,22,42,62,82,102,121,142,162,182,201,222,242,262,282,302,322,342,362,382,402,422,442,462,482,502,522,542,562,582];
const _green = Color(0xFF075143);

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
      content:TextField(controller:input,textCapitalization:TextCapitalization.characters,
        decoration:const InputDecoration(hintText:'الصق كود الدعوة هنا')),
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
  int days=30, capacity=10;
  bool private=false, manual=false, busy=false;
  @override void initState() { super.initState(); name.text = widget.guestName; }
  @override void dispose(){title.dispose();name.dispose();super.dispose();}
  Future<void> create() async {
    if(title.text.trim().isEmpty||name.text.trim().isEmpty)return;
    setState(()=>busy=true);
    try {
      final doc=FirebaseFirestore.instance.collection('khatmas').doc();
      final code=doc.id;
      final batch=FirebaseFirestore.instance.batch();
      batch.set(doc,{
        'title':title.text.trim(),'creatorId':widget.uid,'creatorName':name.text.trim(),
        'code':code,'privacy':private?'private':'public',
        'distribution':manual?'manual':'auto','capacity':capacity,'memberCount':1,
        'memberIds':[widget.uid],'completedParts':<int>[],
        'createdAt':FieldValue.serverTimestamp(),
        'deadline':Timestamp.fromDate(DateTime.now().add(Duration(days:days))),
      });
      batch.set(doc.collection('members').doc(widget.uid),{
        'name':name.text.trim(),'joinedAt':FieldValue.serverTimestamp(),
        'slot':0,'parts':manual?<int>[]:[for(var p=1;p<=30;p++)if((p-1)%capacity==0)p],
        'completed':<int>[],
      });
      await batch.commit();
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute<void>(builder:(_)=>KhatmaDetailsScreen(id:doc.id,uid:widget.uid)));
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('فشل إنشاء الختمة؛ تحقق من صلاحيات Firebase')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('إنشاء ختمة')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'الختمة باسم مين؟',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك في الختمة',border:OutlineInputBorder())),
      const SizedBox(height:16),
      DropdownButtonFormField<int>(initialValue:days,decoration:const InputDecoration(labelText:'مدة الختمة'),
        items:[7,15,30,60,90].map((v)=>DropdownMenuItem(value:v,child:Text('$v يوم'))).toList(),
        onChanged:(v)=>setState(()=>days=v??30)),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(initialValue:capacity,decoration:const InputDecoration(labelText:'عدد المشاركين'),
        items:[5,6,10,15,30].map((v)=>DropdownMenuItem(value:v,child:Text('$v مشارك'))).toList(),
        onChanged:(v)=>setState(()=>capacity=v??10)),
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
    if(name.text.trim().isEmpty){message('اكتب اسمك أولًا');return;}
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
        final parts=data['distribution']=='manual'?<int>[]:
          [for(var p=1;p<=30;p++)if((p-1)%capacity==count)p];
        tx.set(memberRef,{'name':name.text.trim(),'slot':count,'parts':parts,
          'completed':<int>[],'joinedAt':FieldValue.serverTimestamp()});
        tx.update(ref,{'memberCount':FieldValue.increment(1),
          'memberIds':FieldValue.arrayUnion([widget.uid])});
      });
      message('تم الانضمام بنجاح');
    }catch(e){message(e.toString().contains('full')?'اكتمل عدد المشاركين':'تعذر الانضمام؛ راجع الصلاحيات');}
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
        if (member.data()?['completed'] is List && (member.data()!['completed'] as List).isNotEmpty) throw StateError('completed');
        tx.delete(m);
        tx.update(ref,{'memberCount':FieldValue.increment(-1),
          'memberIds':FieldValue.arrayRemove([widget.uid])});
      });
      if(mounted)Navigator.pop(context);
    }catch(_){message('لا يمكن المغادرة بعد إتمام أجزاء، أو حدث خطأ في الصلاحيات');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> complete(int part,bool done) async {
    try {
      final m=ref.collection('members').doc(widget.uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap=await tx.get(m);
        if(!snap.exists||!List<int>.from(snap.data()?['parts']??[]).contains(part))throw StateError('not assigned');
        tx.update(m,{'completed':done?FieldValue.arrayUnion([part]):FieldValue.arrayRemove([part])});
        tx.update(ref,{'completedParts':done?FieldValue.arrayUnion([part]):FieldValue.arrayRemove([part])});
      });
    }catch(_){message('تعذر تحديث الجزء');}
  }
  Future<void> assign(String uid,List<int> existing) async {
    final selected=existing.toSet();
    final result=await showDialog<Set<int>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('توزيع الأجزاء'),
      content:SizedBox(width:350,height:380,child:ListView(children:[
        for(var i=1;i<=30;i++)CheckboxListTile(title:Text('الجزء $i'),
          value:selected.contains(i),onChanged:(v)=>update(()=>v==true?selected.add(i):selected.remove(i))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,selected),child:const Text('حفظ'))])));
    if(result==null)return;
    try {
      final m=ref.collection('members').doc(uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final members=await tx.get(ref);
        if (members.data()?['creatorId'] != widget.uid) throw StateError('host');
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
        return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          stream:ref.collection('members').doc(widget.uid).snapshots(),
          builder:(context,m){
            final mine=m.hasError ? null : m.data?.data();
            return ListView(padding:const EdgeInsets.all(16),children:[
              Text((d['title']??'ختمة جماعية').toString(),
                style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
              const SizedBox(height:12),
              Text('المشاركون: $count / $capacity • المكتمل: ${completed.length} من 30',
                style:const TextStyle(fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              LinearProgressIndicator(value:completed.length/30,minHeight:10),
              const SizedBox(height:12),
              Card(child:ListTile(title:Text('كود الانضمام: ${d['code']}'),
                trailing:IconButton(icon:const Icon(Icons.copy),onPressed:() async {
                  await Clipboard.setData(ClipboardData(text:d['code'].toString()));message('تم نسخ الكود');
                }))),
              if(mine==null) ...[
                TextField(controller:name,decoration:const InputDecoration(labelText:'اسمك عند الانضمام')),
                const SizedBox(height:10),
                FilledButton(onPressed:busy||count>=capacity?null:()=>join(d),
                  child:Text(count>=capacity?'الختمة مكتملة العدد':'انضم للختمة')),
              ] else ...[
                const SizedBox(height:12),
                const Text('أجزائي',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
                for(final p in List<int>.from(mine['parts']??[])..sort())
                  Card(child:Column(children:[
                    ListTile(title:Text('الجزء $p',style:const TextStyle(fontWeight:FontWeight.w800)),
                      subtitle:Text(List<int>.from(mine['completed']??[]).contains(p)?'مكتمل':'بانتظار القراءة'),
                      trailing:Icon(List<int>.from(mine['completed']??[]).contains(p)?Icons.check_circle:Icons.menu_book,color:_green)),
                    Row(children:[
                      Expanded(child:TextButton.icon(
                        onPressed:() async {
                          final prefs=await SharedPreferences.getInstance();
                          final key='khatma_${widget.id}_${widget.uid}_$p';
                          final last=prefs.getInt(key)??_starts[p-1];
                          if(!context.mounted)return;
                          await Navigator.push(context,MaterialPageRoute<void>(
                            builder:(_)=>KhatmaPartReader(part:p,initialPage:last,
                              onPage:(page)=>prefs.setInt(key,page))));
                        },
                        icon:const Icon(Icons.menu_book),label:const Text('قراءة الجزء'))),
                      Expanded(child:TextButton.icon(
                        onPressed:()=>complete(p,!List<int>.from(mine['completed']??[]).contains(p)),
                        icon:const Icon(Icons.check),label:Text(List<int>.from(mine['completed']??[]).contains(p)?'تراجع':'أتممت القراءة'))),
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
              const Text('المشاركون',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
              StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream:ref.collection('members').snapshots(),builder:(context,ms){
                  if(ms.hasError)return const Text('المشاركون يظهرون بعد الانضمام');
                  if(!ms.hasData)return const Center(child:CircularProgressIndicator());
                  return Column(children:[for(final member in ms.data!.docs)
                    Card(child:ListTile(
                      title:Text((member.data()['name']??'مشارك').toString()),
                      subtitle:Text('الأجزاء: ${(List<int>.from(member.data()['parts']??[])..sort()).join('، ')} • المكتمل: ${(member.data()['completed'] as List?)?.length??0}'),
                      trailing:creator&&d['distribution']=='manual'
                        ?IconButton(icon:const Icon(Icons.edit),onPressed:()=>assign(member.id,List<int>.from(member.data()['parts']??[]))):null,
                    )),
                  ]);
                }),
            ]);
          });
      }),
  );
}

class KhatmaPartReader extends StatefulWidget {
  const KhatmaPartReader({super.key,required this.part,required this.initialPage,required this.onPage});
  final int part,initialPage;
  final ValueChanged<int> onPage;
  @override State<KhatmaPartReader> createState()=>_KhatmaPartReaderState();
}
class _KhatmaPartReaderState extends State<KhatmaPartReader> {
  late final PageController controller;
  late int page;
  late final int first,last;
  @override void initState(){
    super.initState();
    first=_starts[widget.part-1];
    last=widget.part==30?604:_starts[widget.part]-1;
    page=widget.initialPage.clamp(first,last);
    controller=PageController(initialPage:page-first);
  }
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text('الجزء ${widget.part} • صفحة $page من $last')),
    body:Directionality(textDirection:TextDirection.rtl,
      child:PageView.builder(controller:controller,itemCount:last-first+1,
        onPageChanged:(i){setState(()=>page=first+i);widget.onPage(page);},
        itemBuilder:(context,i)=>InteractiveViewer(minScale:1,maxScale:5,
          child:Image.asset('assets/mushaf/${(first+i).toString().padLeft(3,'0')}.webp',
            fit:BoxFit.contain)))),
  );
}
