import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/quiz_remote_data_source.dart';

/// 설정 화면 등에서 원격 [quiz_version] 조회 실패 시 표시할 문구.
String remoteQuizVersionErrorMessage(Object error) {
  if (error is SocketException || error is http.ClientException) {
    return '인터넷에 연결되어 있지 않아 원격 버전을 확인할 수 없습니다.';
  }
  if (error is TimeoutException) {
    return '응답 시간이 초과되어 원격 버전을 확인할 수 없습니다. 네트워크 연결을 확인해 주세요.';
  }
  if (error is HttpQuizException) {
    return '원격 퀴즈 버전 정보를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
  return '원격 퀴즈 버전을 확인할 수 없습니다. 네트워크 연결 후 다시 시도해 주세요.';
}
