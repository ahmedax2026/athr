import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imad_flutter/imad_flutter.dart';

/// Isolated trial reader. The existing Quran reader stays untouched.
class ImadMushafTrial extends StatefulWidget {
  const ImadMushafTrial({super.key});
  @override
  State<ImadMushafTrial> createState() => _ImadMushafTrialState();
}

class _ImadMushafTrialState extends State<ImadMushafTrial> {
  static const _pageKey = 'imad_trial_last_page';
  static const _themeKey = 'imad_trial_theme';
  late final Future<void> _setup;
  final MushafThemeNotifier _notifier = MushafThemeNotifier();
  int _page = 1;
  ReadingTheme _theme = ReadingTheme.sepia;

  @override
  void initState() {
    super.initState();
    _setup = _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _page = (prefs.getInt(_pageKey) ?? prefs.getInt('react_quran_last_page') ?? 1).clamp(1, 604);
    final selected = prefs.getString(_themeKey);
    _theme = ReadingTheme.values.firstWhere(
      (value) => value.name == selected,
      orElse: () => ReadingTheme.sepia,
    );
    _notifier.setTheme(_theme);
    await MushafLibrary.initialize(audioSources: const {});
  }

  Future<void> _changeTheme(ReadingTheme value) async {
    _notifier.setTheme(value);
    setState(() => _theme = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value.name);
  }

  Future<void> _savePage(int page) async {
    _page = page;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pageKey, page);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _setup,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('تجربة مصحف عماد')),
          body: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText('تعذر تجهيز المصحف: ${snapshot.error}', textAlign: TextAlign.center),
          )),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return MushafThemeScope(
        notifier: _notifier,
        child: Scaffold(
          backgroundColor: ReadingThemeData.fromTheme(_theme).backgroundColor,
          appBar: AppBar(
            title: const Text('مصحف عماد — تجربة'),
            actions: [
              PopupMenuButton<ReadingTheme>(
                tooltip: 'راحة العين',
                icon: const Icon(Icons.visibility_outlined),
                onSelected: _changeTheme,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: ReadingTheme.sepia, child: Text('راحة العين — بيج')),
                  PopupMenuItem(value: ReadingTheme.light, child: Text('الوضع الفاتح')),
                  PopupMenuItem(value: ReadingTheme.dark, child: Text('الوضع الليلي')),
                  PopupMenuItem(value: ReadingTheme.warmDark, child: Text('ليلي دافئ')),
                ],
              ),
            ],
          ),
          body: MushafPageView(
            initialPage: _page,
            showAudioPlayer: false,
            pagePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onPageChanged: _savePage,
          ),
        ),
      );
    },
  );
}
