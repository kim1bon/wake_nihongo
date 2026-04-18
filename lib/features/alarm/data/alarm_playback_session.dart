import 'package:audio_session/audio_session.dart' as audio_sess;
import 'package:audioplayers/audioplayers.dart';

/// 알람 미리듣기·인앱 반복 재생용 스트림 컨텍스트.
///
/// Android: `USAGE_ALARM` + 가청 강제 플래그에 맞춰 무음/진동(벨소리) 모드에서도 스피커 출력이 가능해집니다.
/// iOS: `playback` 카테고리(물리 무음 스위치는 기기/설정에 따라 여전히 무반응일 수 있음).
final AudioContext alarmInAppAudioContext = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.alarm,
    audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    audioMode: AndroidAudioMode.normal,
  ),
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: {AVAudioSessionOptions.duckOthers},
  ),
);

Future<void> activateAlarmInAppAudioSession() async {
  final session = await audio_sess.AudioSession.instance;
  await session.configure(
    const audio_sess.AudioSessionConfiguration(
      avAudioSessionCategory: audio_sess.AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          audio_sess.AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: audio_sess.AVAudioSessionMode.defaultMode,
      androidAudioAttributes: audio_sess.AndroidAudioAttributes(
        contentType: audio_sess.AndroidAudioContentType.sonification,
        usage: audio_sess.AndroidAudioUsage.alarm,
        flags: audio_sess.AndroidAudioFlags.audibilityEnforced,
      ),
      androidAudioFocusGainType:
          audio_sess.AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ),
  );
  await session.setActive(true);
}

Future<void> deactivateAlarmInAppAudioSession() async {
  final session = await audio_sess.AudioSession.instance;
  await session.setActive(false);
}
