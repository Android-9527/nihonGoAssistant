import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/ui_text.dart';

/// 登录 / 注册页（邮箱 + 密码，昵称可选）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _isRegister = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      if (_isRegister) {
        await auth.register(
          email: _email.text.trim(),
          password: _password.text,
          nickname: _nickname.text.trim(),
        );
      } else {
        await auth.login(email: _email.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? UiText.t('注册账号', 'Register') : UiText.t('登录', 'Sign In'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isRegister)
                TextFormField(
                  controller: _nickname,
                  decoration: InputDecoration(
                      labelText: UiText.t('昵称（可选）', 'Nickname (optional)'),
                      prefixIcon: const Icon(Icons.person_outline)),
                ),
              if (_isRegister) const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: UiText.t('邮箱', 'Email'),
                    prefixIcon: const Icon(Icons.mail_outline)),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                    return UiText.t('邮箱格式不正确', 'Invalid email format');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: UiText.t('密码（至少 6 位）', 'Password (min 6 characters)'),
                    prefixIcon: const Icon(Icons.lock_outline)),
                validator: (v) => (v ?? '').length < 6
                    ? UiText.t('密码至少 6 位', 'Password must be at least 6 characters')
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isRegister ? UiText.t('注册并登录', 'Register & Sign In') : UiText.t('登录', 'Sign In')),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() {
                  _isRegister = !_isRegister;
                  _error = null;
                }),
                child: Text(_isRegister
                    ? UiText.t('已有账号？去登录', 'Have an account? Sign in')
                    : UiText.t('没有账号？去注册', 'No account? Register')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
