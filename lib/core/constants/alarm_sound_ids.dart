/// Bundled alarm tones from `assets/sounds/*.mp3`.
class AlarmSoundIds {
  AlarmSoundIds._();

  static const String defaultId = 'basic';

  static const List<String> all = [
    'basic',
    'chicken',
    'clear_horizon',
    'japan_signal',
    'alarm_clock',
    'ghibli_style',
  ];

  static const Map<String, String> _assetFileNameById = {
    'basic': '기본',
    'chicken': '닭',
    'clear_horizon': '맑은 지평선',
    'japan_signal': '일본 신호등',
    'alarm_clock': '자명종',
    'ghibli_style': '지브리 스타일',
  };

  static const Map<String, String> _labelById = {
    'basic': '기본',
    'chicken': '닭',
    'clear_horizon': '맑은 지평선',
    'japan_signal': '일본 신호등',
    'alarm_clock': '자명종',
    'ghibli_style': '지브리 스타일',
  };

  static const Map<String, String> _legacyIdMap = {
    'Alram_01': 'basic',
    'Alram_02': 'chicken',
    'Alram_03': 'clear_horizon',
    'Alram_04': 'japan_signal',
  };

  static String _resolvedId(String soundId) =>
      isValid(soundId) ? soundId : (_legacyIdMap[soundId] ?? defaultId);

  static String assetPath(String soundId) =>
      'assets/sounds/${_assetFileNameById[_resolvedId(soundId)]}.mp3';

  /// Path for [AssetSource] (relative to the `assets/` directory).
  static String assetSourcePath(String soundId) =>
      'sounds/${_assetFileNameById[_resolvedId(soundId)]}.mp3';

  static String label(String soundId) =>
      _labelById[_resolvedId(soundId)] ?? _resolvedId(soundId);

  /// Valid [AndroidNotificationChannel.id] / per-sound channel suffix.
  static String channelSuffix(String soundId) => _resolvedId(soundId);

  /// Android `res/raw/<name>.mp3` resource name (no extension).
  ///
  static String androidRawName(String soundId) {
    switch (_resolvedId(soundId)) {
      case 'basic':
        return 'basic';
      case 'chicken':
        return 'chicken';
      case 'clear_horizon':
        return 'clear_horizon';
      case 'japan_signal':
        return 'japan_signal';
      case 'alarm_clock':
        return 'alarm_clock';
      case 'ghibli_style':
        return 'ghibli_style';
      default:
        return 'basic';
    }
  }

  static bool isValid(String? id) => id != null && all.contains(id);

  /// iOS bundle file name for UNNotificationSound.
  static String iosFileName(String soundId) =>
      '${_resolvedId(soundId)}.mp3';
}
