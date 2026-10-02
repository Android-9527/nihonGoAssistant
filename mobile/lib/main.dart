import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/my_page.dart';
import 'pages/home_page.dart';
import 'pages/review_page.dart';
import 'pages/search_page.dart';
import 'providers/auth_provider.dart';

void main() {
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
      title: 'nihonGO 日语学习',
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

  static const _pages = [
    HomePage(),
    SearchPage(),
    ReviewPage(),
    MyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '学习'),
          NavigationDestination(icon: Icon(Icons.search), label: '检索'),
          NavigationDestination(icon: Icon(Icons.autorenew), label: '复习'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
