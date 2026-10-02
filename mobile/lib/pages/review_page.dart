import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db_helper.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../widgets/audio_button.dart';
import 'login_page.dart';

/// 复习：按服务器推荐队列逐条复习（上次忘记 / 掌握度低）
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<ReviewItem> _queue = [];
  bool _loading = true;
  String? _error;
  int _index = 0;
  bool _revealed = false;
  bool _submitting = false;
  int _done = 0;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiClient.instance.reviewRecommendations(limit: 30);
      if (!mounted) return;
      setState(() {
        _queue = items;
        _loading = false;
        _index = 0;
        _done = 0;
        _correct = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<({String title, String answer, String entityType, int id})?> _loadCurrent() async {
    final item = _queue[_index];
    if (item.elementType == 'word') {
      final w = await DbHelper.getWord(item.elementId);
      if (w == null) return null;
      return (
        title: w.display,
        answer: '${w.kana}  ${w.chinese}',
        entityType: 'word',
        id: w.id,
      );
    }
    final g = await DbHelper.getGrammarDetail(item.elementId);
    if (g == null) return null;
    return (
      title: g.template,
      answer: g.explanation,
      entityType: 'grammar',
      id: g.id,
    );
  }

  Future<void> _answer(bool correct) async {
    setState(() {
      _submitting = true;
      _revealed = true;
    });
    final item = _queue[_index];
    try {
      await ApiClient.instance.submitTest(
        elementType: item.elementType,
        elementId: item.elementId,
        correct: correct,
      );
      if (correct) _correct++;
      _done++;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：$e'), duration: const Duration(seconds: 2)),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('复习')),
      body: auth.isLoggedIn ? _buildBody() : _buildLoginPrompt(context),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('登录后同步你的学习记录，优先复习\n上次忘记与低掌握的内容',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_queue.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('当前没有需要复习的内容，继续加油！', textAlign: TextAlign.center),
        ),
      );
    }
    if (_index >= _queue.length) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            Text('复习完成（共 $_done 条，答对 $_correct 条）', style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('刷新复习队列')),
          ],
        ),
      );
    }
    return FutureBuilder(
      future: _loadCurrent(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final cur = snap.data!;
        final progress = (_index + 1) / _queue.length;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                '${_queue[_index].reason ?? '待复习'} · ${_index + 1}/${_queue.length}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              cur.title,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          AudioButton(entityType: cur.entityType, entityId: cur.id, size: 26, fallbackText: cur.title),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_revealed)
                        Text(
                          cur.answer,
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade800, height: 1.5),
                          textAlign: TextAlign.center,
                        )
                      else
                        TextButton(
                          onPressed: () => setState(() => _revealed = true),
                          child: const Text('显示答案'),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (!_revealed)
                FilledButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('显示答案'),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
                        onPressed: _submitting ? null : () => _answer(false),
                        icon: const Icon(Icons.close),
                        label: const Text('忘记了'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                        onPressed: _submitting ? null : () => _answer(true),
                        icon: const Icon(Icons.check),
                        label: const Text('记住了'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
