# Wake Nihongo

일본어 학습(퀴즈 등)을 위한 모바일 앱을 목표로 하는 **Flutter** 프로젝트입니다. 현재는 **로컬 알람 MVP**가 구현되어 있습니다.

**저장소:** [github.com/kim1bon/wake_nihongo](https://github.com/kim1bon/wake_nihongo)

## 주요 기능 (알람)

| 기능 | 설명 |
|------|------|
| 알람 CRUD | 추가 · 수정 · 삭제 |
| 반복 요일 | 월~일 개별 선택, **매일**(7요일 전체) |
| 알람 On/Off | 목록에서 스위치로 켜기/끄기 (DB `enabled` + 스케줄 연동) |
| 알람음 | 4종(`Alram_01`~`04`) 선택 · 바텀시트에서 미리듣기 |
| 무음/진동 대응(인앱) | `audio_session` + `audioplayers` 알람용 오디오 컨텍스트 |
| Android 백그라운드 | 앱이 꺼진 상태에서도 **네이티브 AlarmManager + 포그라운드 서비스**로 알람음 **무한 반복** 재생 |
| 알람 해제 UI | 전체 화면 알람 화면, 알림/서비스에서 앱 진입 시 동일 플로우 |

## 기술 스택

- **Flutter** (Dart `^3.11.5`)
- **Riverpod** — 상태 관리
- **sqflite** — 알람 로컬 저장
- **flutter_local_notifications** + **timezone** + **flutter_timezone** — 예약 알림
- **audioplayers** + **audio_session** — 인앱 재생 · 세션 구성

## 요구 사항

- Flutter SDK (프로젝트 `environment`와 호환되는 버전)
- Android Studio / Xcode (각 플랫폼 빌드 시)
- Android: 알림, 정확한 알람, 전체 화면 인텐트 등 권한은 앱 실행 중 안내·요청 흐름에 맞게 사용됩니다.

## 시작하기

```bash
git clone https://github.com/kim1bon/wake_nihongo.git
cd wake_nihongo
flutter pub get
flutter run
```

분석만 돌릴 때:

```bash
flutter analyze
```

## Android 릴리스 APK

```bash
flutter build apk
```

출력 예: `build/app/outputs/flutter-apk/app-release.apk`

스토어 배포용은 AAB가 일반적입니다.

```bash
flutter build appbundle
```

## 프로젝트 구조 (요약)

```
lib/
├── app/           # 부트스트랩, 알람 코디네이터, MaterialApp
├── core/          # 상수 등 공통
├── features/
│   └── alarm/     # 도메인 · 데이터 · UI (목록, 추가/수정, 알람 해제 화면, 사운드 피커)
├── features/quiz/ # 예약 (향후)
└── main.dart
```

Android 네이티브 알람/무한 재생은 `android/app/src/main/kotlin/com/example/wake_nihongo/` 에서 다룹니다.

## iOS 참고

- 로컬 알림 · 인앱 재생은 동작하나, **물리 무음 스위치**나 **백그라운드 무한 사운드**는 Android와 OS 정책이 다릅니다.
- Time Sensitive 등은 Apple 개발자 계정·Capability 설정이 필요할 수 있습니다.

## 라이선스

저장소에 별도 라이선스 파일이 없다면 기본적으로 저작권은 저장소 소유자에게 있습니다. 오픈소스로 공개하려면 `LICENSE` 파일을 추가하는 것을 권장합니다.

## 관련 문서

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Riverpod](https://riverpod.dev/)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
