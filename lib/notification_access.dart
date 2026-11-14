import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_notifications.dart';

/// A single permission entry point shared by Home and Settings.
class NotificationAccessCard extends StatefulWidget {
  const NotificationAccessCard({super.key, this.promptOnFirstHome = false});
  final bool promptOnFirstHome;

  @override
  State<NotificationAccessCard> createState() => _NotificationAccessCardState();
}

class _NotificationAccessCardState extends State<NotificationAccessCard>
    with WidgetsBindingObserver {
  static const _seenKey = 'notification_permission_intro_seen';
  static const _enabledKey = 'athr_notifications_opt_in';
  bool _loading = true;
  bool _allowed = false;
  bool _optedIn = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = await PrayerNotifications.status();
      if (!mounted) return;
      setState(() {
        _allowed = status.enabled;
        _optedIn = prefs.getBool(_enabledKey) ?? true;
        _loading = false;
      });
      if (initial && widget.promptOnFirstHome &&
          !(prefs.getBool(_seenKey) ?? false) && !status.enabled) {
        await prefs.setBool(_seenKey, true);
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWelcomeDialog();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enable() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final allowed = await PrayerNotifications.requestNotificationPermission();
      if (allowed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_enabledKey, true);
        _message('تم السماح بالإشعارات. تأكد من ضبط مدينتك في مواقيت الصلاة لتفعيل المواعيد.');
      } else {
        _message('الإذن غير مفعل. يمكنك السماح به من إعدادات الهاتف.');
        if (mounted) await PrayerNotifications.openNotificationSettings();
      }
    } catch (_) {
      _message('تعذر طلب الإذن. افتح إعدادات إشعارات التطبيق من الهاتف.');
    } finally {
      if (mounted) setState(() => _working = false);
      await _load();
    }
  }

  Future<void> _disable() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
      await PrayerNotifications.cancelPrayerNotifications();
      _message('تم إيقاف تنبيهات الصلاة داخل التطبيق. إذن أندرويد لم يتغير.');
    } catch (_) {
      _message('تعذر إيقاف بعض التنبيهات. راجع إعدادات الهاتف.');
    } finally {
      if (mounted) setState(() => _working = false);
      await _load();
    }
  }

  Future<void> _showWelcomeDialog() async {
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined, size: 42,
            color: Color(0xFFD6B56C)),
        title: const Text('خليك على صلة بصلاتك وأذكارك',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'اسمح لتطبيق أثر لا ينقطع بإرسال تنبيهات مواقيت الصلاة والأذكار. يمكنك تغيير اختيارك في أي وقت من الرئيسية أو الإعدادات.',
          textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ليس الآن')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('تفعيل الإشعارات'),
          ),
        ],
      ),
    );
    if (accept == true && mounted) await _enable();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD6B56C);
    const cream = Color(0xFFF5EBD5);
    final active = _allowed && _optedIn;
    return Container(
      key: const ValueKey('notification-access-card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF103D35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: .65)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.notifications_active_outlined, color: gold),
          SizedBox(width: 9),
          Expanded(child: Text('إشعارات الصلاة والأذكار',
            style: TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16))),
        ]),
        const SizedBox(height: 7),
        Text(_loading ? 'جارٍ التحقق من الإذن...' :
          active ? 'الإشعارات مسموح بها ومفعّلة داخل التطبيق' :
          !_allowed ? 'الإشعارات غير مسموح بها من الهاتف' :
          'الإشعارات متوقفة باختيارك داخل التطبيق',
          style: const TextStyle(color: cream, fontSize: 13)),
        const SizedBox(height: 10),
        if (!_loading)
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: _working ? null : active ? _disable : _enable,
              icon: Icon(active ? Icons.notifications_off_outlined :
                  Icons.notifications_active_outlined, size: 18),
              label: Text(active ? 'إيقاف التنبيهات' : 'تفعيل الإشعارات'),
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF052B27)),
            )),
            if (!_allowed) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'إعدادات إشعارات الهاتف',
                color: gold,
                onPressed: _working ? null :
                    () async { await PrayerNotifications.openNotificationSettings(); },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ]),
      ]),
    );
  }
}
