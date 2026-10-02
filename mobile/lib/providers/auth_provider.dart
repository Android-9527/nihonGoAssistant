import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// 登录状态管理：不强制登录，测试/复习前检查 isLoggedIn
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get loading => _loading;

  /// App 启动时恢复登录态
  Future<void> restore() async {
    _loading = true;
    notifyListeners();
    final token = await AuthService.instance.getToken();
    final user = await AuthService.instance.getUser();
    if (token != null && user != null) {
      ApiClient.instance.token = token;
      _user = user;
      // 后台校验 token 是否仍有效（失败则静默登出）
      try {
        final fresh = await ApiClient.instance.me();
        if (fresh != null) _user = fresh;
      } catch (_) {
        // 网络异常不登出，保留本地登录态
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final r = await ApiClient.instance.login(email: email, password: password);
    ApiClient.instance.token = r.token;
    await AuthService.instance.save(token: r.token, user: r.user);
    _user = r.user;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final r = await ApiClient.instance.register(
      email: email,
      password: password,
      nickname: nickname,
    );
    ApiClient.instance.token = r.token;
    await AuthService.instance.save(token: r.token, user: r.user);
    _user = r.user;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.logout();
    } catch (_) {}
    ApiClient.instance.token = null;
    await AuthService.instance.clear();
    _user = null;
    notifyListeners();
  }
}
