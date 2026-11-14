import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AdhanCatalog {
  static const channel = MethodChannel('athr/adhan_alarms');
  static const builtIn = {'adhan_makkah': 'أذان الحرم المكي', 'adhan_afasy': 'أذان مشاري العفاسي'};
  static final validId = RegExp(r'^remote_[a-zA-Z0-9_]{1,64}$');
  static bool validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
        uri.userInfo.isEmpty && uri.path.toLowerCase().endsWith('.mp3');
  }
  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> parse(dynamic raw) => raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e))
          .where((e) => validId.hasMatch(e['id'].toString()) &&
              validUrl(e['url'].toString()) && e['name'] is String).take(20).toList()
        : [];
    try {
      final doc = await FirebaseFirestore.instance.collection('content').doc('adhan_voices').get()
          .timeout(const Duration(seconds: 3));
      final data = doc.data();
      if (doc.exists && data?['published'] == true) {
        final items = parse(data?['voices']);
        await prefs.setString('adhan_catalog_cache', jsonEncode(items));
        return items;
      }
    } catch (_) {}
    try { return parse(jsonDecode(prefs.getString('adhan_catalog_cache') ?? '[]')); }
    catch (_) { return []; }
  }
  static Future<String> localPath(String id) async {
    if (!validId.hasMatch(id)) throw ArgumentError('invalid voice');
    return (await channel.invokeMethod<String>('voicePath', {'id': id}))!;
  }
  static Future<void>? _prefetching;
  static Future<void> prefetch() => _prefetching ??= _prefetch().whenComplete(() => _prefetching = null);
  static Future<void> _prefetch() async {
    try {
      final items = await load();
      for (final item in items) {
        try {
          await download(item['id'].toString(), item['url'].toString());
        } catch (_) {
          // Not published yet or offline: retry at the next app launch/resume.
        }
      }
    } catch (_) {}
  }
  static Future<String?> cachedPath(String id) async {
    try {
      final path = await localPath(id);
      final file = File(path);
      if (await file.exists() && await file.length() > 1024) return path;
    } catch (_) {}
    return null;
  }
  static final _downloads = <String, Future<String>>{};
  static Future<String> download(String id, String url) =>
      _downloads.putIfAbsent(id, () async {
        try { return await _download(id, url); }
        finally { _downloads.remove(id); }
      });
  static Future<String> _download(String id, String url) async {
    if (!validUrl(url)) throw ArgumentError('HTTPS MP3 only');
    final path = await localPath(id);
    final file = File(path);
    if (await file.exists() && await file.length() > 1024) return path;
    final partial = File('$path.part');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    try {
      var uri = Uri.parse(url);
      late HttpClientResponse response;
      for (var redirects = 0; ; redirects++) {
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Android) Athr Audio');
        request.headers.set(HttpHeaders.acceptHeader, 'audio/mpeg, audio/*, */*');
        response = await request.close().timeout(const Duration(seconds: 20));
        if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || redirects >= 5) throw StateError('redirect');
        uri = uri.resolve(location);
        if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          throw StateError('redirect');
        }
        await response.listen((_) {}).cancel();
      }
      if (response.statusCode != 200) throw StateError('HTTP ${response.statusCode}');
      if (response.contentLength > 50 * 1024 * 1024) throw StateError('file too large');
      sink = partial.openWrite();
      var size = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        size += chunk.length;
        if (size > 50 * 1024 * 1024) throw StateError('file too large');
        sink.add(chunk);
      }
      await sink.close();
      sink = null;
      if (size < 1024) throw StateError('invalid audio');
      final playable = await channel.invokeMethod<bool>('validateVoice', {'id': id});
      if (playable != true) throw StateError('invalid MP3');
      await partial.rename(path);
      return path;
    } finally {
      client.close(force: true);
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    }
  }
  static Future<String> availableVoice(String id) async {
    if (builtIn.containsKey(id)) return id;
    try {
      if (await File(await localPath(id)).exists()) return id;
    } catch (_) {}
    return 'adhan_makkah';
  }
}
