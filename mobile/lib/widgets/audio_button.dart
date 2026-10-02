import 'package:flutter/material.dart';

import '../services/audio_service.dart';

/// 朗读按钮：优先播打包的本地 TTS 音频，
/// 无本地音频时用系统语音合成朗读 fallbackText
class AudioButton extends StatefulWidget {
  final String entityType; // word | sentence | grammar
  final int entityId;
  final String? fallbackText;
  final double size;

  const AudioButton({
    super.key,
    required this.entityType,
    required this.entityId,
    this.fallbackText,
    this.size = 20,
  });

  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  bool _playing = false;

  Future<void> _play() async {
    if (_playing) {
      await AudioService.instance.stop();
      setState(() => _playing = false);
      return;
    }
    final ok = await AudioService.instance.playEntityAudio(
      widget.entityType,
      widget.entityId,
      fallbackText: widget.fallbackText,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无离线音频，且手机未安装日语语音'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => _playing = true);
    // 播放结束自动复位（音频时长未知，先 6 秒后复位）
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _playing) setState(() => _playing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _play,
      iconSize: widget.size,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _playing ? Icons.volume_up : Icons.volume_up_outlined,
        color: _playing ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: '朗读',
    );
  }
}
