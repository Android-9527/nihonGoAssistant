import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/db_helper.dart';

/// 本地音频播放：优先播打包的 TTS MP3；
/// 无本地音频或播放失败时，用系统语音合成朗读兜底（离线可用）
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  AudioPlayer? _player;
  FlutterTts? _tts;

  Future<bool> playEntityAudio(
    String entityType,
    int entityId, {
    String? fallbackText,
  }) async {
    final path = await DbHelper.getAudioAssetPath(entityType, entityId);
    if (path != null) {
      await _stopTts();
      try {
        _player ??= AudioPlayer();
        await _player!.stop();
        await _player!.play(AssetSource(path));
        return true;
      } catch (_) {
        // 本地播放失败，落到 TTS
      }
    }
    final text = fallbackText;
    if (text != null && text.trim().isNotEmpty) {
      return _speakTts(text.trim());
    }
    return false;
  }

  Future<void> _stopTts() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<bool> _speakTts(String text) async {
    try {
      _tts ??= FlutterTts();
      await _player?.stop();
      if (!await _japaneseVoiceAvailable()) {
        return false;
      }
      await _tts!.setLanguage('ja-JP');
      await _tts!.setSpeechRate(0.5);
      await _tts!.setPitch(1.0);
      await _tts!.setVolume(1.0);
      await _tts!.awaitSpeakCompletion(false);
      await _tts!.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 手机是否装有日语语音数据（没有则系统 TTS 会按中文读，不可用）
  Future<bool> _japaneseVoiceAvailable() async {
    try {
      final ok = await _tts!.isLanguageAvailable('ja-JP');
      return ok == true;
    } catch (_) {
      // 查询失败时仍尝试朗读，由系统决定
      return true;
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
