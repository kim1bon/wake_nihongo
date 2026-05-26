import 'package:csv/csv.dart';

import '../domain/quiz_entry.dart';

bool parseSheetBool(String raw) {
  final s = raw.trim().toLowerCase();
  return s == 'true' ||
      s == '1' ||
      s == 'yes' ||
      s == 'y' ||
      s == '✓' ||
      s == 'v';
}

String _cell(List<dynamic> row, int idx) {
  if (idx < 0 || idx >= row.length) return '';
  return '${row[idx]}'.trim();
}

/// 첫 행 헤더: id, category, type, jp, kor 필수.
/// 선택: level, hiragana, kor_pronunciation, hiragana_display, incorrect_pool (대소문자 무시, 공백 트림).
List<QuizEntry> parseQuizSheetCsv(String raw) {
  var text = raw;
  if (text.startsWith('\ufeff')) {
    text = text.substring(1);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n').convert(text);
  if (rows.isEmpty) return [];

  final header = rows.first.map((c) => '$c'.trim().toLowerCase()).toList();
  final idIdx = header.indexOf('id');
  var catIdx = header.indexOf('category');
  if (catIdx < 0) {
    catIdx = header.indexOf('catergory');
  }
  final levelIdx = header.indexOf('level');
  final typeIdx = header.indexOf('type');
  final jpIdx = header.indexOf('jp');
  final hiraganaIdx = header.indexOf('hiragana');
  var korPronIdx = header.indexOf('kor_pronunciation');
  if (korPronIdx < 0) {
    korPronIdx = header.indexOf('kor pronunciation');
  }
  final hiraganaDisplayIdx = header.indexOf('hiragana_display');
  final incorrectPoolIdx = header.indexOf('incorrect_pool');
  final korIdx = header.indexOf('kor');
  if (idIdx < 0 || catIdx < 0 || typeIdx < 0 || jpIdx < 0 || korIdx < 0) {
    throw FormatException(
      'CSV 헤더에 id, category, type, jp, kor 가 필요합니다. 실제: $header',
    );
  }

  final out = <QuizEntry>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length <= jpIdx) continue;
    final id = _cell(row, idIdx);
    final jp = _cell(row, jpIdx);
    if (id.isEmpty && jp.isEmpty) continue;

    final hiraganaRaw = hiraganaIdx >= 0 ? _cell(row, hiraganaIdx) : '';
    final displayRaw =
        hiraganaDisplayIdx >= 0 ? _cell(row, hiraganaDisplayIdx) : '';
    final incorrectPoolRaw =
        incorrectPoolIdx >= 0 ? _cell(row, incorrectPoolIdx) : '';

    List<String>? incorrectPoolIds;
    if (incorrectPoolRaw.isNotEmpty) {
      final parts = incorrectPoolRaw.split(',');
      final cleaned = <String>[];
      for (final p in parts) {
        final v = p.trim();
        if (v.isNotEmpty) {
          cleaned.add(v);
        }
      }
      if (cleaned.isNotEmpty) {
        incorrectPoolIds = cleaned;
      }
    }

    out.add(
      QuizEntry(
        id: id.isEmpty ? '$i' : id,
        category: _cell(row, catIdx),
        level: levelIdx >= 0 ? _cell(row, levelIdx) : '',
        type: _cell(row, typeIdx),
        jp: jp,
        hiragana: hiraganaRaw,
        kor: _cell(row, korIdx),
        korPronunciation: korPronIdx >= 0 ? _cell(row, korPronIdx) : '',
        hiraganaDisplay:
            displayRaw.isEmpty ? false : parseSheetBool(displayRaw),
        incorrectPoolIds: incorrectPoolIds,
      ),
    );
  }
  return out;
}
