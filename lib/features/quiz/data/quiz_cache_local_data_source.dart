import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_data_versions.dart';
import '../../../core/constants/quiz_asset_paths.dart';

class QuizCacheMeta {
  const QuizCacheMeta({
    required this.version,
    required this.quizVersion,
  });

  final String version;
  final String quizVersion;
}

class QuizSheetManifestSlot {
  const QuizSheetManifestSlot({
    required this.storageKey,
    required this.contentName,
  });

  final String storageKey;
  final String contentName;
}

class QuizSheetsManifest {
  const QuizSheetsManifest({required this.sheets});

  final List<QuizSheetManifestSlot> sheets;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'sheets': sheets
            .map(
              (e) => {
                'k': e.storageKey,
                'n': e.contentName,
              },
            )
            .toList(),
      };

  factory QuizSheetsManifest.fromJson(Map<String, dynamic> j) {
    final raw = j['sheets'];
    if (raw is! List<dynamic>) {
      return const QuizSheetsManifest(sheets: []);
    }
    final slots = <QuizSheetManifestSlot>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = item.map((k, v) => MapEntry('$k', v));
      final k = '${m['k'] ?? ''}'.trim();
      if (k.isEmpty) continue;
      slots.add(
        QuizSheetManifestSlot(
          storageKey: k,
          contentName: '${m['n'] ?? ''}'.trim(),
        ),
      );
    }
    return QuizSheetsManifest(sheets: slots);
  }
}

class QuizCacheLocalDataSource {
  static const String _prefsVersionKey = 'main_sheet_version_v1';
  static const String _prefsQuizVersionKey = 'main_quiz_version_v1';

  Future<QuizCacheMeta> readMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final version =
        prefs.getString(_prefsVersionKey) ?? AppDataVersions.appVersion;
    final quizVersion =
        prefs.getString(_prefsQuizVersionKey) ?? AppDataVersions.quizVersion;
    return QuizCacheMeta(version: version, quizVersion: quizVersion);
  }

  Future<void> saveMeta({
    required String version,
    required String quizVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsVersionKey, version);
    await prefs.setString(_prefsQuizVersionKey, quizVersion);
  }

  Future<QuizSheetsManifest?> readSheetsManifest() async {
    final f = await _manifestFile();
    if (!await f.exists()) return null;
    try {
      final text = await f.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      final m = QuizSheetsManifest.fromJson(decoded);
      if (m.sheets.isEmpty) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSheetsManifest(QuizSheetsManifest manifest) async {
    final f = await _manifestFile();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(manifest.toJson()), flush: true);
  }

  Future<void> deleteSheetsManifest() async {
    final f = await _manifestFile();
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<String?> readSheetCsv(String storageKey) async {
    final f = await _sheetFile(storageKey);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  Future<void> writeSheetCsv({
    required String storageKey,
    required String raw,
  }) async {
    final f = await _sheetFile(storageKey);
    await f.parent.create(recursive: true);
    await f.writeAsString(raw, flush: true);
  }

  /// 매니페스트에 없는 `sheet_*.csv` 를 삭제합니다.
  Future<void> pruneSheetsNotIn(Set<String> keepStorageKeys) async {
    final dir = await _sheetsDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('sheet_') || !name.endsWith('.csv')) continue;
      final key = name.substring('sheet_'.length, name.length - '.csv'.length);
      if (!keepStorageKeys.contains(key)) {
        await entity.delete();
      }
    }
  }

  Future<void> clearMultiSheetCache() async {
    await deleteSheetsManifest();
    final dir = await _sheetsDir();
    if (await dir.exists()) {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  Future<String?> readMainQuizCsv() async {
    final f = await _quizFile();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  Future<void> writeMainQuizCsv(String csvRaw) async {
    final f = await _quizFile();
    await f.parent.create(recursive: true);
    await f.writeAsString(csvRaw, flush: true);
  }

  Future<void> deleteMainQuizCsvIfExists() async {
    final f = await _quizFile();
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<File> _quizFile() async {
    final base = await _questionsBaseDir();
    return File(p.join(base.path, QuizAssetPaths.mainCsvFileName));
  }

  Future<Directory> _questionsBaseDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'assets', 'questions'));
  }

  Future<Directory> _sheetsDir() async {
    final base = await _questionsBaseDir();
    return Directory(p.join(base.path, QuizAssetPaths.sheetsSubDir));
  }

  Future<File> _manifestFile() async {
    final base = await _questionsBaseDir();
    return File(p.join(base.path, QuizAssetPaths.sheetsManifestFileName));
  }

  Future<File> _sheetFile(String storageKey) async {
    final dir = await _sheetsDir();
    return File(p.join(dir.path, 'sheet_$storageKey.csv'));
  }
}
