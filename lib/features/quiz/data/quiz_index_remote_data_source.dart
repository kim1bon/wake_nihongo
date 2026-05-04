import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/quiz_sheet_config.dart';
import 'quiz_remote_data_source.dart';
import 'quiz_sheet_parser.dart';

/// 인덱스(사용 유무) 시트 한 행.
class QuizIndexRow {
  const QuizIndexRow({
    required this.id,
    required this.contentName,
    required this.url,
  });

  final String id;
  final String contentName;
  final String url;
}

Uri? normalizeGoogleSheetCsvUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final u = Uri.tryParse(trimmed);
  if (u == null) return null;
  if (u.path.contains('/export')) return u;

  final match = RegExp(
    r'/spreadsheets/d/([a-zA-Z0-9-_]+)',
  ).firstMatch(u.toString());
  final sheetId = match?.group(1);
  if (sheetId == null) return u;

  var gid = '0';
  final frag = u.fragment;
  if (frag.startsWith('gid=')) {
    gid = frag.substring(4).split('&').first;
  }

  return Uri.parse(
    'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid',
  );
}

class QuizIndexRemoteDataSource {
  QuizIndexRemoteDataSource({http.Client? httpClient}) : _client = httpClient;

  final http.Client? _client;

  Future<String> fetchRawIndexCsv({Uri? uri}) async {
    final u = uri ?? QuizSheetConfig.quizIndexExportCsvUri;
    final c = _client;
    final response = await (c != null ? c.get(u) : http.get(u)).timeout(
      const Duration(seconds: 10),
    );
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw HttpQuizException(
        statusCode: response.statusCode,
        bodyPreview: text.length > 200 ? '${text.substring(0, 200)}…' : text,
      );
    }
    return text;
  }

  /// `use_display`가 참인 행만, 유효한 URL이 있는 항목만 반환합니다.
  Future<List<QuizIndexRow>> fetchActiveRows({Uri? uri}) async {
    final text = await fetchRawIndexCsv(uri: uri);
    return parseQuizIndexCsv(text);
  }

  void dispose() {
    _client?.close();
  }
}

List<QuizIndexRow> parseQuizIndexCsv(String raw) {
  var text = raw;
  if (text.startsWith('\ufeff')) {
    text = text.substring(1);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n').convert(text);
  if (rows.length < 2) return [];

  final header = rows.first.map((c) => '$c'.trim().toLowerCase()).toList();
  final idIdx = header.indexOf('id');
  final useIdx = header.indexOf('use_display');
  final nameIdx = header.indexOf('content_name');
  final urlIdx = header.indexOf('url');
  if (idIdx < 0 || useIdx < 0 || urlIdx < 0) {
    throw FormatException(
      '인덱스 CSV 헤더에 id, use_display, url 이 필요합니다. 실제: $header',
    );
  }

  final out = <QuizIndexRow>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length <= urlIdx) continue;
    final useRaw = '${row[useIdx]}'.trim();
    if (useRaw.isEmpty || !parseSheetBool(useRaw)) continue;

    final id = '${row[idIdx]}'.trim();
    final urlRaw = '${row[urlIdx]}'.trim();
    if (urlRaw.isEmpty) continue;

    final name = nameIdx >= 0 && nameIdx < row.length
        ? '${row[nameIdx]}'.trim()
        : '';

    out.add(
      QuizIndexRow(
        id: id.isEmpty ? 'row_$i' : id,
        contentName: name,
        url: urlRaw,
      ),
    );
  }
  return out;
}
