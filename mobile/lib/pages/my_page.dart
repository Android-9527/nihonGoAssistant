import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'login_page.dart';
import 'review_page.dart';
import 'test_page.dart';

/// 我的：登录状态 + 测试 / 复习入口
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!auth.isLoggedIn)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.account_circle, size: 56, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('登录后可同步学习进度、使用测试与复习', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text('登录 / 注册'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        (auth.user?.nickname.isNotEmpty ?? false)
                            ? auth.user!.nickname.characters.first
                            : '学',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(auth.user?.nickname ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(auth.user?.email ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('退出登录'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: const Text('测试'),
                  subtitle: const Text('按章节自测单词 / 语法'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      _requireLogin(context);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TestPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.autorenew),
                  title: const Text('复习'),
                  subtitle: const Text('底部「复习」页即可直达'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      _requireLogin(context);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReviewPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _requireLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('测试与复习需要登录'),
        action: SnackBarAction(
          label: '去登录',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
      ),
    );
  }
}
