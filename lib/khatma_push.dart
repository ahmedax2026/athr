import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'khatma.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class KhatmaPush {
  static final navigator = GlobalKey<NavigatorState>();
  static bool _started = false;
  static RemoteMessage? _pending;
  static bool _homeReady = false;
  static Future<void> _queue = Future<void>.value();

  static void start() {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _queue = _queue.then((_) => _register(user)).catchError((Object _) {});
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      _queue = _queue.then((_) => _register(FirebaseAuth.instance.currentUser)).catchError((Object _) {});
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    FirebaseMessaging.onMessage.listen((message) async {
      if(message.data['type']!='khatma_reminder')return;
      final plugin=FlutterLocalNotificationsPlugin();
      try { await plugin.show(id:8000+(message.messageId??'').hashCode.abs()%10000,title:message.notification?.title??'تذكير بالختمة',body:message.notification?.body??'لا تنس إكمال وردك',notificationDetails:const NotificationDetails(android:AndroidNotificationDetails('athr_khatma','تذكيرات الختمات',importance:Importance.high,priority:Priority.high))); } catch (_) { }
    });
    unawaited(FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _open(m);
    }).catchError((Object _) {}));
  }

  static void homeReady() {
    _homeReady = true;
    final message = _pending;
    if (message != null) _open(message);
  }

  static void _open(RemoteMessage message) {
    if (message.data['type'] != 'khatma_reminder') return;
    if (!_homeReady || navigator.currentState == null) {
      _pending = message;
      return;
    }
    _pending = null;
    final user = FirebaseAuth.instance.currentUser;
    final room = message.data['roomId'];
    if (user == null || message.data['recipientId'] != user.uid ||
        room is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(room)) {
      return;
    }
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Directionality(textDirection: TextDirection.rtl,
        child: KhatmaDetailsScreen(id: room, uid: user.uid))));
  }

  static Future<void> enable() async {
    final permission=await FirebaseMessaging.instance.requestPermission();
    if(permission.authorizationStatus!=AuthorizationStatus.authorized && permission.authorizationStatus!=AuthorizationStatus.provisional)throw StateError('اسمح بالإشعارات في إعدادات الهاتف');
    final user=FirebaseAuth.instance.currentUser;
    if(user==null)throw StateError('سجل الدخول أولًا');
    await _register(user);
  }

  static Future<void> registerCurrent() async {
    _queue = _queue.then((_) => _register(FirebaseAuth.instance.currentUser)).catchError((Object _) {});
    await _queue;
  }

  static Future<void> _register(User? user) async {
    if (!Platform.isAndroid) return;
    final messaging = FirebaseMessaging.instance;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('khatma_push_uid');
    if (previous != null && previous != user?.uid) {
      await messaging.deleteToken();
      await prefs.remove('khatma_push_uid');
    }
    if (user == null || FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    final permission = await messaging.getNotificationSettings();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }
    final token = await messaging.getToken();
    if (token == null || FirebaseAuth.instance.currentUser?.uid != user.uid) return;
    await FirebaseFirestore.instance.collection('push_devices').doc(user.uid).set({
      'token': token, 'updatedAt': FieldValue.serverTimestamp(),
    });
    await prefs.setString('khatma_push_uid', user.uid);
  }

  static Future<String> remind(String roomId, String recipientId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (user == null || token == null) return 'auth_required';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.postUrl(Uri.parse('https://athr-notifications.ahmedax0100.workers.dev/remind'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'roomId': roomId, 'recipientId': recipientId, 'senderId': user.uid}));
      final resp = await req.close().timeout(const Duration(seconds: 25));
      final result = jsonDecode(await resp.transform(utf8.decoder).join().timeout(const Duration(seconds: 10)));
      if (result is Map && result['sent'] == true) return 'sent';
      if (result is Map && result['recorded'] == true) return 'recorded';
      return result is Map ? (result['error'] ?? 'failed').toString() : 'failed';
    } finally {
      client.close(force: true);
    }
  }
}
