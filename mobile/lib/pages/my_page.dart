import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/language_setting.dart';
import '../services/ui_text.dart';
import 'login_page.dart';
import 'test_page.dart';
import 'wordbook_page.dart';

/// 我的：登录状态 + 测试 / 复习入口 + 设置
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String get _langLabel {
    switch (LanguageSetting.current) {
      case MeaningLang.system:
        return UiText.t('跟随系统', 'Follow System');
      case MeaningLang.zh:
        return UiText.t('中文', 'Chinese');
      case MeaningLang.en:
        return UiText.t('英文', 'English');
    }
  }

  /// 释义语言选择弹窗
  Future<void> _pickLanguage() async {
    final picked = await showDialog<MeaningLang>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(UiText.t('释义语言', 'Meaning Language')),
        children: [
          for (final lang in MeaningLang.values)
            ListTile(
              title: Text(
                switch (lang) {
                  MeaningLang.system => UiText.t('跟随系统（按手机语言）', 'Follow System (device language)'),
                  MeaningLang.zh => UiText.t('中文', 'Chinese'),
                  MeaningLang.en => UiText.t('英文', 'English'),
                },
              ),
              trailing: lang == LanguageSetting.current
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.of(context).pop(lang),
            ),
        ],
      ),
    );
    if (picked != null && picked != LanguageSetting.current) {
      await LanguageSetting.set(picked);
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiText.t('释义语言已切换为：', 'Meaning language switched to: ') + '$_langLabel')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(UiText.t('我的', 'Me'))),
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
                    Text(UiText.t('登录后可同步学习进度、使用测试与复习',
                        'Sign in to sync progress and use tests & review'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: Text(UiText.t('登录 / 注册', 'Sign in / Register')),
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
                            : UiText.t('学', 'S'),
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
                      label: Text(UiText.t('退出登录', 'Sign Out')),
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
                  title: Text(UiText.t('测试', 'Test')),
                  subtitle: Text(UiText.t('按章节自测单词 / 语法', 'Quiz words / grammar by chapter')),
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
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(UiText.t('单词本', 'Wordbook')),
                  subtitle: Text(UiText.t('收藏单词，闪卡复习', 'Save words & review with flashcards')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (!auth.isLoggedIn) {
                      _requireLogin(context);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WordbookPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(UiText.t('释义语言', 'Meaning Language')),
              subtitle: Text(UiText.t('当前：$_langLabel（单词/语法/句子释义）',
                  'Current: $_langLabel (words / grammar / sentences)')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickLanguage,
            ),
          ),
        ],
      ),
    );
  }

  void _requireLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(UiText.t('测试与复习需要登录', 'Tests and review require login')),
        action: SnackBarAction(
          label: UiText.t('去登录', 'Sign In'),
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
