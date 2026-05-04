import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 번들 Noto Sans 의 OFL 을 라이선스 페이지에 노출합니다.
void registerBundledFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final kr = await rootBundle.loadString('assets/fonts/Noto_Sans_KR/OFL.txt');
    final jp = await rootBundle.loadString('assets/fonts/Noto_Sans_JP/OFL.txt');
    yield LicenseEntryWithLineBreaks(<String>['noto_sans_kr'], kr);
    yield LicenseEntryWithLineBreaks(<String>['noto_sans_jp'], jp);
  });
}
