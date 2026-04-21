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

  Future<File> _quizFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(
      p.join(
        appDir.path,
        'assets',
        'questions',
        QuizAssetPaths.mainCsvFileName,
      ),
    );
  }
}
