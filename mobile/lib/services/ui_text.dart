import 'language_setting.dart';

/// 界面框架文案：跟随释义语言设置切换中英文
///
/// 释义（单词/语法/句子内容）走 LanguageSetting.t(zh, en)；
/// 界面框架文字（Tab / 按钮 / 标题 / 提示等）统一走 UiText.t(zh, en)，
/// 二者共用同一套「跟随系统 + 手动选择」逻辑。
class UiText {
  static String t(String zh, String en) => LanguageSetting.useEnglish ? en : zh;
}
