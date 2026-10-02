/// 全局配置
class AppConfig {
  /// 后端 API 地址（正式版：服务器 nginx 443 反代）
  static const String apiBaseUrl = 'https://nihongolab.win';

  /// 本地打包数据库 asset 路径
  static const String assetDbPath = 'assets/data/nihon_content.db';

  /// tts_audio.file_path 的相对前缀（打包时去掉的部分）
  static const String audioPathPrefix = r'nihonAssitant\datapre\text2speech\audio\';
}
