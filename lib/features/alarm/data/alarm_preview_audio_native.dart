import 'dart:io';

import 'package:flutter/services.dart';

/// 알람음 **미리듣기**(추가·수정 화면)용. 실제 알람 울림 경로와 별개.
class AlarmSoundPreviewPolicy {
  const AlarmSoundPreviewPolicy({
    required this.ringerHushed,
    required this.headsetConnected,
  });

  /// 무음 또는 진동(벨소리 끔) 모드.
  final bool ringerHushed;

  /// 유선·블루투스 이어폰/헤드셋 등 스피커가 아닌 출력 연결.
  final bool headsetConnected;

  /// 이 경우 미리듣기 재생을 하지 않음(스피커로 나가지 않도록).
  bool get blockPreviewPlayback => ringerHushed && !headsetConnected;

  static const AlarmSoundPreviewPolicy permissive = AlarmSoundPreviewPolicy(
    ringerHushed: false,
    headsetConnected: true,
  );
}

class AlarmPreviewAudioNative {
  AlarmPreviewAudioNative._();

  static const _ch = MethodChannel('com.example.wake_nihongo/alarm_native');

  static Future<AlarmSoundPreviewPolicy> getSoundPreviewPolicy() async {
    if (!Platform.isAndroid) {
      return AlarmSoundPreviewPolicy.permissive;
    }
    try {
      final raw = await _ch.invokeMethod<Object?>('getSoundPreviewPolicy');
      if (raw is! Map) return AlarmSoundPreviewPolicy.permissive;
      final map = Map<String, dynamic>.from(raw);
      return AlarmSoundPreviewPolicy(
        ringerHushed: map['ringerHushed'] == true,
        headsetConnected: map['headsetConnected'] == true,
      );
    } on MissingPluginException {
      return AlarmSoundPreviewPolicy.permissive;
    } catch (_) {
      return AlarmSoundPreviewPolicy.permissive;
    }
  }
}
