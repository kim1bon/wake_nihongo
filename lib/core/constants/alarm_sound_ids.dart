/// Bundled alarm tones: `assets/sounds/Alram_01.mp3` … `Alram_04.mp3`.
/// Android `res/raw` uses lowercase names without extension (e.g. `alram_01`).
class AlarmSoundIds {
  AlarmSoundIds._();

  static const String defaultId = 'Alram_01';

  static const List<String> all = [
    'Alram_01',
    'Alram_02',
    'Alram_03',
    'Alram_04',
  ];

  static String assetPath(String soundId) => 'assets/sounds/$soundId.mp3';

  /// Path for [AssetSource] (relative to the `assets/` directory).
  static String assetSourcePath(String soundId) => 'sounds/$soundId.mp3';

  /// Valid [AndroidNotificationChannel.id] / per-sound channel suffix.
  static String channelSuffix(String soundId) =>
      soundId.toLowerCase().replaceAll('.', '_');

  /// Android `res/raw/<name>.mp3` resource name (no extension).
  static String androidRawName(String soundId) {
    switch (soundId) {
      case 'Alram_01':
        return 'alram_01';
      case 'Alram_02':
        return 'alram_02';
      case 'Alram_03':
        return 'alram_03';
      case 'Alram_04':
        return 'alram_04';
      default:
        return 'alram_01';
    }
  }

  static bool isValid(String? id) => id != null && all.contains(id);

  /// iOS bundle file name for UNNotificationSound.
  static String iosFileName(String soundId) => '$soundId.mp3';
}
