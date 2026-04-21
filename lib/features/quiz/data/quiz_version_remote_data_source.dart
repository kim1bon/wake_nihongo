import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/quiz_sheet_config.dart';
import 'quiz_remote_data_source.dart';

class QuizSheetVersionInfo {
  const QuizSheetVersionInfo({
    required this.version,
    required this.quizVersion,
  });

  final String version;
  final String quizVersion;
}

class QuizVersionRemoteDataSource {
  QuizVersionRemoteDataSource({http.Client? httpClient}) : _client = httpClient;

  final http.Client? _client;

  Future<QuizSheetVersionInfo> fetchVersionInfo({Uri? uri}) async {
    final u = uri ?? QuizSheetConfig.versionExportCsvUri;
    final c = _client;
    final response = await (c != null ? c.get(u) : http.get(u)).timeout(
      const Duration(seconds: 6),
    );
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw HttpQuizException(
        statusCode: response.statusCode,
        bodyPreview: text.length > 200 ? '${text.substring(0, 200)}…' : text,
      );
    }
    return _parseVersionCsv(text);
  }

  void dispose() {
    _client?.close();
  }
}

QuizSheetVersionInfo _parseVersionCsv(String raw) {
  var text = raw;
  if (text.startsWith('\ufeff')) {
    text = text.substring(1);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n').convert(text);
  if (rows.length < 2) {
    throw const FormatException('버전 시트 CSV에 데이터 행이 없습니다.');
  }

  final header = rows.first.map((c) => '$c'.trim().toLowerCase()).toList();
  final versionIdx = header.indexOf('version');
  final quizVersionIdx = header.indexOf('quiz_version');
  if (versionIdx < 0 || quizVersionIdx < 0) {
    throw FormatException(
      '버전 시트 CSV 헤더에 version, quiz_version 이 필요합니다. 실제: $header',
    );
  }

  final data = rows[1];
  final version = '${
      versionIdx < data.length ? data[versionIdx] : ''}'.trim();
  final quizVersion = '${
      quizVersionIdx < data.length ? data[quizVersionIdx] : ''}'.trim();
  if (version.isEmpty || quizVersion.isEmpty) {
    throw const FormatException('version 또는 quiz_version 값이 비어 있습니다.');
  }
  return QuizSheetVersionInfo(version: version, quizVersion: quizVersion);
}
