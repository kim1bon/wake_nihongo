import '../../../core/constants/quiz_sheet_config.dart';
import '../domain/quiz_entry.dart';
import 'quiz_cache_local_data_source.dart';
import 'quiz_index_remote_data_source.dart';
import 'quiz_local_asset_data_source.dart';
import 'quiz_remote_data_source.dart';
import 'quiz_sheet_parser.dart';
import 'quiz_version_remote_data_source.dart';

class QuizVersionStatus {
  const QuizVersionStatus({
    required this.localVersion,
    required this.localQuizVersion,
    required this.remoteVersion,
    required this.remoteQuizVersion,
  });

  final String localVersion;
  final String localQuizVersion;
  final String remoteVersion;
  final String remoteQuizVersion;

  bool get quizVersionDifferent => localQuizVersion != remoteQuizVersion;
}

class QuizSyncResult {
  const QuizSyncResult({
    required this.updated,
    required this.previousQuizVersion,
    required this.currentQuizVersion,
  });

  final bool updated;
  final String previousQuizVersion;
  final String currentQuizVersion;
}

/// 퀴즈 동기화 UI용 진행 상태.
enum QuizDownloadPhase {
  /// 인덱스 시트 CSV 요청 중.
  preparingIndex,

  /// 개별 시트 CSV 수신 중 ([current] / [total]).
  downloadingSheet,

  /// 레거시 단일 CSV 한 번에 수신 (1/1).
  legacyCsv,
}

class QuizDownloadProgress {
  const QuizDownloadProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.contentLabel,
  });

  final QuizDownloadPhase phase;

  /// [downloadingSheet]: 1…[total]. 그 외 단계는 UI에서 무시해도 됨.
  final int current;
  final int total;

  /// 인덱스 시트의 콘텐츠 이름(있을 때만).
  final String? contentLabel;
}

class QuizRepository {
  QuizRepository({
    QuizRemoteDataSource? remoteDataSource,
    QuizVersionRemoteDataSource? versionRemoteDataSource,
    QuizCacheLocalDataSource? cacheLocalDataSource,
    QuizIndexRemoteDataSource? indexRemoteDataSource,
  }) : _remote = remoteDataSource ?? QuizRemoteDataSource(),
       _versionRemote = versionRemoteDataSource ?? QuizVersionRemoteDataSource(),
       _cache = cacheLocalDataSource ?? QuizCacheLocalDataSource(),
       _index = indexRemoteDataSource ?? QuizIndexRemoteDataSource();

  final QuizRemoteDataSource _remote;
  final QuizVersionRemoteDataSource _versionRemote;
  final QuizCacheLocalDataSource _cache;
  final QuizIndexRemoteDataSource _index;

  /// 로컬/원격 버전 상태를 확인합니다. 원격 조회 실패 시 `null`.
  Future<QuizVersionStatus?> checkVersionStatus() async {
    try {
      final localMeta = await _cache.readMeta();
      final remoteMeta = await _versionRemote.fetchVersionInfo();
      return QuizVersionStatus(
        localVersion: localMeta.version,
        localQuizVersion: localMeta.quizVersion,
        remoteVersion: remoteMeta.version,
        remoteQuizVersion: remoteMeta.quizVersion,
      );
    } catch (_) {
      return null;
    }
  }

  /// 인덱스 시트 기준으로 활성 URL들을 내려받아 시트별 로컬 파일·매니페스트를 갱신합니다.
  /// 실패 시 레거시 단일 GID CSV로 폴백합니다.
  Future<QuizSyncResult> updateQuizFromRemote({
    required QuizVersionStatus status,
    void Function(QuizDownloadProgress progress)? onDownloadProgress,
  }) async {
    final multi = await _downloadMultiSheetsToCache(
      onProgress: onDownloadProgress,
    );
    if (multi != null && multi.isNotEmpty) {
      await _cache.deleteMainQuizCsvIfExists();
      await _cache.saveMeta(
        version: status.remoteVersion,
        quizVersion: status.remoteQuizVersion,
      );
      return QuizSyncResult(
        updated: true,
        previousQuizVersion: status.localQuizVersion,
        currentQuizVersion: status.remoteQuizVersion,
      );
    }

    try {
      onDownloadProgress?.call(
        const QuizDownloadProgress(
          phase: QuizDownloadPhase.legacyCsv,
          current: 1,
          total: 1,
        ),
      );
      final quizCsv = await _remote.fetchRawCsv(
        uri: QuizSheetConfig.legacyQuizExportCsvUri,
      );
      await _cache.clearMultiSheetCache();
      await _cache.writeMainQuizCsv(quizCsv);
      await _cache.saveMeta(
        version: status.remoteVersion,
        quizVersion: status.remoteQuizVersion,
      );
      return QuizSyncResult(
        updated: true,
        previousQuizVersion: status.localQuizVersion,
        currentQuizVersion: status.remoteQuizVersion,
      );
    } catch (_) {
      return QuizSyncResult(
        updated: false,
        previousQuizVersion: status.localQuizVersion,
        currentQuizVersion: status.localQuizVersion,
      );
    }
  }

  /// 1) 매니페스트+시트별 파일 → 2) 레거시 단일 CSV → 3) 네트워크(인덱스) → 4) 레거시 단일 URL → 5) 샘플
  Future<List<QuizEntry>> loadEntries() async {
    final fromManifest = await _loadFromManifest();
    if (fromManifest.isNotEmpty) return fromManifest;

    final legacyLocal = await _cache.readMainQuizCsv();
    if (legacyLocal != null && legacyLocal.trim().isNotEmpty) {
      try {
        return parseQuizSheetCsv(legacyLocal);
      } catch (_) {}
    }

    final fromNetMulti = await _downloadMultiSheetsToCache();
    if (fromNetMulti != null && fromNetMulti.isNotEmpty) {
      return fromNetMulti;
    }

    try {
      final remoteCsv = await _remote.fetchRawCsv(
        uri: QuizSheetConfig.legacyQuizExportCsvUri,
      );
      await _cache.clearMultiSheetCache();
      await _cache.writeMainQuizCsv(remoteCsv);
      try {
        final remoteMeta = await _versionRemote.fetchVersionInfo();
        await _cache.saveMeta(
          version: remoteMeta.version,
          quizVersion: remoteMeta.quizVersion,
        );
      } catch (_) {}
      return parseQuizSheetCsv(remoteCsv);
    } catch (_) {
      return QuizLocalAssetDataSource.loadSampleEntries();
    }
  }

  Future<List<QuizEntry>> _loadFromManifest() async {
    final manifest = await _cache.readSheetsManifest();
    if (manifest == null) return [];

    final merged = <QuizEntry>[];
    for (final slot in manifest.sheets) {
      final raw = await _cache.readSheetCsv(slot.storageKey);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        merged.addAll(parseQuizSheetCsv(raw));
      } catch (_) {}
    }
    return merged;
  }

  /// 인덱스에서 활성 시트를 받아 저장하고, 파싱된 전체 목록을 반환합니다. 실패 시 `null`.
  Future<List<QuizEntry>?> _downloadMultiSheetsToCache({
    void Function(QuizDownloadProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const QuizDownloadProgress(
        phase: QuizDownloadPhase.preparingIndex,
        current: 0,
        total: 0,
      ),
    );
    List<QuizIndexRow> rows;
    try {
      rows = await _index.fetchActiveRows();
    } catch (_) {
      return null;
    }
    if (rows.isEmpty) return null;

    final usedKeys = <String>{};
    final slots = <QuizSheetManifestSlot>[];
    final merged = <QuizEntry>[];
    var okCount = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      var key = _storageKeyForIndexId(row.id);
      var disambig = 0;
      while (usedKeys.contains(key)) {
        disambig++;
        key = '${_storageKeyForIndexId(row.id)}_$disambig';
      }
      usedKeys.add(key);

      final label = row.contentName.trim();
      onProgress?.call(
        QuizDownloadProgress(
          phase: QuizDownloadPhase.downloadingSheet,
          current: i + 1,
          total: rows.length,
          contentLabel: label.isEmpty ? null : label,
        ),
      );

      final uri = normalizeGoogleSheetCsvUri(row.url);
      if (uri == null) continue;

      try {
        final csv = await _remote.fetchRawCsv(uri: uri);
        await _cache.writeSheetCsv(storageKey: key, raw: csv);
        final parsed = parseQuizSheetCsv(csv);
        merged.addAll(parsed);
        slots.add(
          QuizSheetManifestSlot(storageKey: key, contentName: row.contentName),
        );
        okCount++;
      } catch (_) {}
    }

    if (okCount == 0) return null;

    await _cache.writeSheetsManifest(QuizSheetsManifest(sheets: slots));
    await _cache.pruneSheetsNotIn(usedKeys);
    return merged;
  }

  static String _storageKeyForIndexId(String id) {
    var s = id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (s.isEmpty) return 'sheet';
    if (s.length > 80) s = s.substring(0, 80);
    return s;
  }
}
