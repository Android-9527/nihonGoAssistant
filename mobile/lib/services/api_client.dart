import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user.dart';
import 'ui_text.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// 后端 API 客户端：登录 / 测试 / 复习（内容数据全部走本地，不走网络）
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _token;

  String? get token => _token;

  set token(String? t) => _token = t;

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = _token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  /// 通用请求：支持 GET / POST / DELETE，返回动态类型
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path);
    http.Response resp;
    try {
      if (method == 'GET') {
        resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
      } else if (method == 'DELETE') {
        resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15));
      } else {
        resp = await http
            .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      throw ApiException(UiText.t('网络连接失败，请检查网络后重试', 'Network error — please check your connection and retry'));
    }
    dynamic json;
    try {
      if (resp.body.isNotEmpty) json = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {}
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json ?? <String, dynamic>{};
    }
    final msg = (json is Map<String, dynamic> && json['error'] is String)
        ? (json['error'] as String)
        : UiText.t('请求失败（${resp.statusCode}）', 'Request failed (${resp.statusCode})');
    throw ApiException(msg, resp.statusCode);
  }

  // ---------- 认证 ----------

  Future<({String token, User user})> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final j = await _request('POST', '/api/auth/register', body: {
      'email': email,
      'password': password,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    });
    return (
      token: j['token'] as String,
      user: User.fromJson(j['user'] as Map<String, dynamic>),
    );
  }

  Future<({String token, User user})> login({
    required String email,
    required String password,
  }) async {
    final j = await _request('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    return (
      token: j['token'] as String,
      user: User.fromJson(j['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    await _request('POST', '/api/auth/logout');
  }

  Future<User?> me() async {
    final j = await _request('GET', '/api/auth/me');
    final u = j['user'];
    return u is Map<String, dynamic> ? User.fromJson(u) : null;
  }

  // ---------- 测试 / 复习 ----------

  Future<SubmitResult> submitTest({
    required String elementType,
    required int elementId,
    required bool correct,
    int durationMs = 0,
    int? chapter,
  }) async {
    final j = await _request('POST', '/api/test/submit', body: {
      'element_type': elementType,
      'element_id': elementId,
      'correct': correct,
      'duration_ms': durationMs,
      if (chapter != null) 'chapter': chapter,
    });
    return SubmitResult.fromJson(j);
  }

  // ---------- 语法分析 ----------

  /// 输入一句日语，返回 LLM 模板与最相关语法（网页 /api/grammar-search 同接口）
  Future<Map<String, dynamic>> grammarSearch(String sentence) async {
    return _request('POST', '/api/grammar-search', body: {'sentence': sentence})
        as Map<String, dynamic>;
  }
}
