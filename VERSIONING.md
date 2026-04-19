# 버전·커밋 관리 (WakeNihongo)

Flutter 앱 버전은 **`pubspec.yaml`** 의 한 줄로 정합니다.

```yaml
version: 1.0.0+1
```

- **`1.0.0`** — 사용자에게 보이는 버전 이름 (MAJOR.MINOR.PATCH).
- **`+1`** — 빌드 번호 (Android `versionCode`, iOS 빌드 번호). 스토어 업로드 시 **이전보다 커야** 합니다.

Git **커밋 해시**와 **앱 버전 숫자**는 서로 자동 연동되지 않습니다. 아래처럼 **습관 + 스크립트**로 맞춥니다.

---

## 추천 워크플로

### A. 매 커밋마다 빌드 번호만 올리기 (가장 단순)

기능을 넣고 커밋할 때마다 **`+1`만** 올리면, “몇 번째 빌드인지”가 커밋 시점과 대응됩니다.

1. 프로젝트 루트에서:

   ```powershell
   .\scripts\bump_build.ps1
   ```

2. 변경된 `pubspec.yaml`을 스테이징하고 같이 커밋합니다.

   ```powershell
   git add pubspec.yaml
   git commit -m "기능: 알람 스누즈"
   ```

의미 있는 단위(예: 릴리즈)에서만 MAJOR/MINOR/PATCH를 직접 수정해도 됩니다.

### B. Git 태그로 “릴리즈 지점” 표시

배포하거나 마일스톤을 남길 때:

```powershell
git tag -a v1.0.0 -m "첫 플레이 스토어 빌드"
git push origin v1.0.0
```

GitHub **Releases**에서 해당 태그를 선택해 노트를 달 수 있습니다.

### C. 현재 코드가 태그 기준 몇 커밋인지 보기

```powershell
git describe --tags --always
```

예: `v1.0.0-3-gabcd123` → `v1.0.0` 이후 3커밋.

---

## 스크립트

| 파일 | 설명 |
|------|------|
| `scripts/bump_build.ps1` | `1.0.0+5` → `1.0.0+6` (+1만 증가) |
| `scripts/bump_patch.ps1` | `1.0.3+10` → `1.0.4+11` (PATCH+1, 빌드도 +1) |

실행 위치는 **저장소 루트** (`wake_nihongo` 폴더) 기준입니다.

---

## 자동화를 더 하고 싶다면

- **커밋할 때마다** 빌드를 올리려면 Git **pre-commit** 훅에서 `bump_build.ps1`를 호출할 수 있습니다. 다만 매 커밋마다 버전 파일이 바뀌므로 팀·습관에 맞출지 결정하면 됩니다.

---

## 요약

| 목표 | 방법 |
|------|------|
| 커밋마다 “앱 버전 숫자” 남기기 | 커밋 전 `bump_build.ps1` → `pubspec.yaml` 포함 커밋 |
| 배포 단위 구분 | `git tag v1.x.x` + 필요 시 MAJOR/MINOR/PATCH 수정 |
| 코드 이력만 | 지금처럼 `git commit` / `git push` (Git이 자동 관리) |
