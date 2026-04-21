import 'package:csv/csv.dart';

import '../domain/quiz_entry.dart';

/// 첫 행 헤더: id, category, type, jp, kor (대소문자 무시, 공백 트림).
List<QuizEntry> parseQuizSheetCsv(String raw) {
  var text = raw;
  if (text.startsWith('\ufeff')) {
    text = text.substring(1);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // 기본 CsvToListConverter는 eol이 \r\n 일 때만 행으로 나누므로, \n 기준으로 통일한다.
  final rows = const CsvToListConverter(eol: '\n').convert(text);
  if (rows.isEmpty) return [];

  final header = rows.first.map((c) => '$c'.trim().toLowerCase()).toList();
  final idIdx = header.indexOf('id');
  var catIdx = header.indexOf('category');
  // 시트 오탈자(catergory)도 허용해 원격 데이터 변경에 안전하게 대응.
  if (catIdx < 0) {
    catIdx = header.indexOf('catergory');
  }
  final typeIdx = header.indexOf('type');
  final jpIdx = header.indexOf('jp');
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
    final id = '${row[idIdx]}'.trim();
    final jp = '${row[jpIdx]}'.trim();
    if (id.isEmpty && jp.isEmpty) continue;

    out.add(
      QuizEntry(
        id: id.isEmpty ? '$i' : id,
        category: '${row[catIdx]}'.trim(),
        type: '${row[typeIdx]}'.trim(),
        jp: jp,
        kor: '${row[korIdx]}'.trim(),
      ),
    );
  }
  return out;
}
