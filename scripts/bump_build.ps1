# 사용: 저장소 루트에서  .\scripts\bump_build.ps1
# pubspec.yaml 의 +빌드 번호만 1 증가 (예: 1.0.0+3 -> 1.0.0+4)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Pubspec = Join-Path $ProjectRoot "pubspec.yaml"

if (-not (Test-Path $Pubspec)) {
    Write-Error "pubspec.yaml 을 찾을 수 없습니다: $Pubspec"
}

$lines = Get-Content -Path $Pubspec -Encoding UTF8
$updated = $false
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
        $build = [int]$Matches[4] + 1
        $lines[$i] = "version: $($Matches[1]).$($Matches[2]).$($Matches[3])+$build"
        $updated = $true
        Write-Host "OK -> $($lines[$i])"
        break
    }
}

if (-not $updated) {
    Write-Error "pubspec.yaml 에서 version: X.Y.Z+N 형식을 찾지 못했습니다."
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($Pubspec, $lines, $utf8NoBom)
