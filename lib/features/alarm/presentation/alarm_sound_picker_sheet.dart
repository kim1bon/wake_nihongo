import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../data/alarm_playback_session.dart';

/// Bottom sheet: tap a row to preview that tone in a loop; tap **완료** to confirm.
class AlarmSoundPickerSheet extends StatefulWidget {
  const AlarmSoundPickerSheet({super.key, required this.initialSoundId});

  final String initialSoundId;

  @override
  State<AlarmSoundPickerSheet> createState() => _AlarmSoundPickerSheetState();
}

class _AlarmSoundPickerSheetState extends State<AlarmSoundPickerSheet> {
  final AudioPlayer _player = AudioPlayer();
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = AlarmSoundIds.isValid(widget.initialSoundId)
        ? widget.initialSoundId
        : AlarmSoundIds.defaultId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playLoop(_selectedId);
    });
  }

  Future<void> _playLoop(String soundId) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알람음을 재생할 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _onPick(String id) async {
    setState(() => _selectedId = id);
    await _playLoop(id);
  }

  @override
  void dispose() {
    () async {
      await _player.stop();
      try {
        await deactivateAlarmInAppAudioSession();
      } catch (_) {}
      await _player.dispose();
    }();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('알람음', style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedId),
                  child: const Text('완료'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '항목을 누르면 선택한 알람음이 반복 재생됩니다.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          for (final id in AlarmSoundIds.all)
            ListTile(
              title: Text(id),
              trailing: id == _selectedId ? const Icon(Icons.check) : null,
              onTap: () => _onPick(id),
            ),
        ],
      ),
    );
  }
}
