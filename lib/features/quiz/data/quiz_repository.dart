import '../domain/quiz_entry.dart';
import 'quiz_cache_local_data_source.dart';
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

class QuizRepository {
  QuizRepository({
    QuizRemoteDataSource? remoteDataSource,
    QuizVersionRemoteDataSource? versionRemoteDataSource,
    QuizCacheLocalDataSource? cacheLocalDataSource,
  }) : _remote = remoteDataSource ?? QuizRemoteDataSource(),
       _versionRemote = versionRemoteDataSource ?? QuizVersionRemoteDataSource(),
       _cache = cacheLocalDataSource ?? QuizCacheLocalDataSource();

  final QuizRemoteDataSource _remote;
  final QuizVersionRemoteDataSource _versionRemote;
  final QuizCacheLocalDataSource _cache;

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

  /// 원격 퀴즈 CSV를 내려받아 로컬 파일/버전을 갱신합니다.
  Future<QuizSyncResult> updateQuizFromRemote({
    required QuizVersionStatus status,
  }) async {
    try {
      final quizCsv = await _remote.fetchRawCsv();
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

  /// 로컬 CSV 우선, 없으면 원격, 둘 다 실패하면 번들 샘플 사용.
  Future<List<QuizEntry>> loadEntries() async {
    final localCsv = await _cache.readMainQuizCsv();
    if (localCsv != null && localCsv.trim().isNotEmpty) {
      try {
        return parseQuizSheetCsv(localCsv);
      } catch (_) {
        // 손상된 로컬 CSV는 무시하고 원격/샘플 폴백을 시도.
      }
    }

    try {
      final remoteCsv = await _remote.fetchRawCsv();
      await _cache.writeMainQuizCsv(remoteCsv);
      try {
        final remoteMeta = await _versionRemote.fetchVersionInfo();
        await _cache.saveMeta(
          version: remoteMeta.version,
          quizVersion: remoteMeta.quizVersion,
        );
      } catch (_) {
        // 메타 동기화 실패 시에도 방금 저장한 CSV는 계속 사용.
      }
      return parseQuizSheetCsv(remoteCsv);
    } catch (_) {
      return QuizLocalAssetDataSource.loadSampleEntries();
    }
  }
}
