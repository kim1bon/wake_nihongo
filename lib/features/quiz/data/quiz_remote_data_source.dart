import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/quiz_sheet_config.dart';
import '../domain/quiz_entry.dart';
import 'quiz_sheet_parser.dart';

class QuizRemoteDataSource {
  /// 생략 시 패키지 기본 `http.get`을 사용합니다. 별도 [http.Client]를 넘기면 테스트·고급 설정용으로만 사용합니다.
  QuizRemoteDataSource({http.Client? httpClient}) : _client = httpClient;

  final http.Client? _client;

  Future<List<QuizEntry>> fetchEntries({Uri? uri}) async {
    final text = await fetchRawCsv(uri: uri);
    return parseQuizSheetCsv(text);
  }

  Future<String> fetchRawCsv({Uri? uri}) async {
    final u = uri ?? QuizSheetConfig.quizExportCsvUri;
    final c = _client;
    final response = await (c != null ? c.get(u) : http.get(u)).timeout(
      const Duration(seconds: 6),
    );
    // 구글 시트 CSV는 UTF-8인데 Content-Type에 charset이 없으면 package:http 가 latin1으로
    // 디코딩해 한국어·일본어가 깨질 수 있음 → bodyBytes 를 항상 UTF-8로 디코딩.
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw HttpQuizException(
        statusCode: response.statusCode,
        bodyPreview: text.length > 200 ? '${text.substring(0, 200)}…' : text,
      );
    }
    return text;
  }

  void dispose() {
    _client?.close();
  }
}

class HttpQuizException implements Exception {
  HttpQuizException({required this.statusCode, required this.bodyPreview});

  final int statusCode;
  final String bodyPreview;

  @override
  String toString() => 'HttpQuizException($statusCode): $bodyPreview';
}
