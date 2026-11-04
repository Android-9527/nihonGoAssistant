import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// 释义语言偏好：跟随系统 / 中文 / 英文
enum MeaningLang { system, zh, en }

/// 全局释义语言设置（数据库已有 中文+英文 双语字段）
///
/// 策略：首次启动按系统语言定默认（系统中文→中文释义，其他→英文释义）；
/// 用户可在「我的 → 释义语言」手动选择，手动选择后以手动为准并持久化。
/// [notifier] 变化时通知全 App 重建，界面框架文案随之一同切换。
class LanguageSetting {
  static const _key = 'meaning_lang';
  static MeaningLang current = MeaningLang.system;

  /// 语言变化通知（供 UI 监听重建）
  static final ValueNotifier<MeaningLang> notifier =
      ValueNotifier<MeaningLang>(MeaningLang.system);

  /// App 启动时加载持久化偏好
  static Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString(_key);
      current = MeaningLang.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MeaningLang.system,
      );
    } catch (_) {
      current = MeaningLang.system;
    }
    notifier.value = current;
  }

  /// 保存偏好（写入本地）
  static Future<void> set(MeaningLang lang) async {
    current = lang;
    notifier.value = lang;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, lang.name);
    } catch (_) {}
  }

  /// 是否应显示英文释义（跟随系统时按系统语言推断）
  static bool get useEnglish {
    if (current == MeaningLang.en) return true;
    if (current == MeaningLang.zh) return false;
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code != 'zh';
  }

  /// 取释义文本：选中英文且英文非空 → 英文；否则回退中文
  static String t(String zh, String en) {
    if (useEnglish && en.trim().isNotEmpty) return en;
    return zh;
  }
}
