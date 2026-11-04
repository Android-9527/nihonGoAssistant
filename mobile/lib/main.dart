import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/my_page.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/wordbook_page.dart';
import 'providers/auth_provider.dart';
import 'services/language_setting.dart';
import 'services/ui_text.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageSetting.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restore()),
      ],
      child: const NihonGoApp(),
    ),
  );
}

class NihonGoApp extends StatelessWidget {
  const NihonGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: UiText.t('nihonGO 日语学习', 'nihonGO Japanese Learning'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2962FF)),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 语言切换时重建常驻页面，让界面框架文字即时更新
    LanguageSetting.notifier.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    LanguageSetting.notifier.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 每次 build 新建实例：语言切换后 IndexedStack 子页会重新 build 并读取最新文案
    final pages = [
      HomePage(),
      SearchPage(),
      WordbookPage(),
      MyPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: UiText.t('学习', 'Learn')),
          NavigationDestination(
              icon: const Icon(Icons.search), label: UiText.t('检索', 'Search')),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: UiText.t('单词本', 'Wordbook')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: UiText.t('我的', 'Me')),
        ],
      ),
    );
  }
}
