import 'package:audioplayers/audioplayers.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import 'alarm_playback_session.dart';

/// In-app looping alarm audio when a scheduled notification opens the app.
class AlarmRingtonePlayer {
  final AudioPlayer _player = AudioPlayer();

  Future<void> startLoop(String soundId) async {
    final id = AlarmSoundIds.isValid(soundId) ? soundId : AlarmSoundIds.defaultId;
    try {
      await activateAlarmInAppAudioSession();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource(AlarmSoundIds.assetSourcePath(id)),
        ctx: alarmInAppAudioContext,
      );
    } catch (_) {
      // Asset missing or platform error — notification may still have played OS sound.
    }
  }

  Future<void> stop() async {
    await _player.stop();
    try {
      await deactivateAlarmInAppAudioSession();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
