import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/alarm_sound_ids.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/responsive.dart';
import '../data/alarm_playback_session.dart';
import '../data/alarm_preview_audio_native.dart';

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
      await _player.stop();
      try {
        await deactivateAlarmInAppAudioSession();
      } catch (_) {}

      final policy = await AlarmPreviewAudioNative.getSoundPreviewPolicy();
      if (policy.blockPreviewPlayback) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '무음·진동 모드에서는 이어폰(유선·블루투스)을 연결했을 때만 미리듣기됩니다.',
              ),
            ),
          );
        }
        return;
      }

      if (policy.ringerHushed && policy.headsetConnected) {
        await activateAlarmPreviewMediaAudioSession();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(
          AssetSource(AlarmSoundIds.assetSourcePath(id)),
          ctx: alarmPreviewMediaInAppAudioContext,
        );
      } else {
        await activateAlarmInAppAudioSession();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(
          AssetSource(AlarmSoundIds.assetSourcePath(id)),
          ctx: alarmInAppAudioContext,
        );
      }
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
    final theme = Theme.of(context);
    final isCompactDevice = MediaQuery.sizeOf(context).width <= 380;
    // A/B 미세 튜닝: 0.0(기존) / 2.0(B안)으로 타일 밀도를 조절합니다.
    const tileHeightStepDp = 2.0;
    final compactTileHeight = 46.0 - tileHeightStepDp;
    final regularTileHeight = 54.0 - tileHeightStepDp;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.beigeSoft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.r(22))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: context.w(isCompactDevice ? 40 : 44),
                height: context.h(isCompactDevice ? 4 : 5),
                margin: EdgeInsets.only(top: context.h(isCompactDevice ? 8 : 10)),
                decoration: BoxDecoration(
                  color: AppPalette.navy.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(context.r(999)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.w(16),
                context.h(isCompactDevice ? 12 : 14),
                context.w(16),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '알람음',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.navy,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(isCompactDevice ? 14 : 16),
                        vertical: context.h(isCompactDevice ? 8 : 10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.r(10)),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, _selectedId),
                    child: const Text('완료'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.w(16),
                context.h(isCompactDevice ? 10 : 12),
                context.w(16),
                context.h(isCompactDevice ? 6 : 8),
              ),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  context.w(12),
                  context.h(isCompactDevice ? 10 : 12),
                  context.w(12),
                  context.h(isCompactDevice ? 10 : 12),
                ),
                decoration: BoxDecoration(
                  color: AppPalette.beigeContainer,
                  borderRadius: BorderRadius.circular(context.r(12)),
                  border: Border.all(color: AppPalette.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '항목을 누르면 선택한 알람음이 반복 재생됩니다.\n'
                  '무음·진동 모드에서는 이어폰(유선·블루투스)을 연결했을 때만 미리듣기됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.navy.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: AlarmSoundIds.all.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: AppPalette.navy.withValues(alpha: 0.10),
                ),
                itemBuilder: (context, index) {
                  final id = AlarmSoundIds.all[index];
                  final isSelected = id == _selectedId;
                  return ListTile(
                    dense: isCompactDevice,
                    visualDensity: VisualDensity(
                      vertical: isCompactDevice ? -1.6 : -0.8,
                    ),
                    minTileHeight: context.h(
                      isCompactDevice ? compactTileHeight : regularTileHeight,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: context.w(16),
                      vertical: context.h(isCompactDevice ? 0 : 2),
                    ),
                    leading: Container(
                      width: context.r(isCompactDevice ? 26 : 30),
                      height: context.r(isCompactDevice ? 26 : 30),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppPalette.green.withValues(alpha: 0.18)
                            : AppPalette.beigeContainer,
                        borderRadius: BorderRadius.circular(context.r(8)),
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: context.r(isCompactDevice ? 16 : 18),
                        color: isSelected ? AppPalette.green : AppPalette.navy.withValues(alpha: 0.75),
                      ),
                    ),
                    title: Text(
                      AlarmSoundIds.label(id),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppPalette.navy,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppPalette.green)
                        : null,
                    onTap: () => _onPick(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
