# Диагностика: почему JDT LS не видит сгенерированные proto-классы.
# Запуск из корня проекта (там, где лежит родительский pom.xml):
#   powershell -ExecutionPolicy Bypass -File .\diagnose-proto.ps1 -Module digital-ksb-cache-service
# Результат: .\proto-diagnostics.txt — его и пришлите.

param(
  [string]$Module = "digital-ksb-cache-service",
  [string]$Out = ".\proto-diagnostics.txt"
)

$ErrorActionPreference = "Continue"
function Section($t) { "`n=== $t " + ("=" * [Math]::Max(0, 60 - $t.Length)) }

$report = @()
$report += "proto-diagnostics  $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$report += "cwd: $(Get-Location)"
$report += "module: $Module"

# 1. Версии инструментов
$report += Section "1. versions"
$report += (& code --version 2>&1 | Select-Object -First 1) -replace '^', 'vscode: '
$report += (& code --list-extensions --show-versions 2>&1 | Select-String -Pattern 'redhat.java|vscjava' | ForEach-Object { "ext: $_" })
$report += (& java -version 2>&1 | Select-Object -First 1) -replace '^', 'java: '
$report += (& mvn -v 2>&1 | Select-Object -First 1) -replace '^', 'mvn: '

# 2. Настройки java.* из User settings.json
$report += Section "2. user settings (java.* / lifecycle)"
$settings = Join-Path $env:APPDATA "Code\User\settings.json"
if (Test-Path $settings) {
  $report += "file: $settings"
  $report += (Get-Content $settings | Select-String -Pattern 'java\.|lifecycle|maven' | ForEach-Object { $_.Line })
} else { $report += "NOT FOUND: $settings" }

# 3. Файл lifecycle mapping — существует ли по указанному пути
$report += Section "3. lifecycle mapping file"
$lm = $null
if (Test-Path $settings) {
  $m = (Get-Content $settings -Raw) -match '"java\.configuration\.maven\.lifecycleMappings"\s*:\s*"([^"]+)"'
  if ($m) { $lm = $Matches[1] -replace '\\\\', '\' }
}
if ($lm) {
  $report += "configured path: $lm"
  if (Test-Path $lm) {
    $report += "exists: YES, size $((Get-Item $lm).Length) bytes"
    $report += "--- content ---"
    $report += (Get-Content $lm)
  } else { $report += "exists: NO  <-- путь не найден, настройка ни на что не влияет" }
} else { $report += "java.configuration.maven.lifecycleMappings не задан в User settings" }

# 4. Какой именно плагин генерирует proto (точные координаты)
$report += Section "4. effective-pom: protobuf plugin coordinates"
$eff = & mvn -q -o help:effective-pom -pl $Module 2>&1
if ($LASTEXITCODE -ne 0) { $eff = & mvn -q help:effective-pom -pl $Module 2>&1 }
$lines = $eff -split "`r?`n"
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match 'protobuf|protoc|grpc') {
    $from = [Math]::Max(0, $i - 6); $to = [Math]::Min($lines.Count - 1, $i + 10)
    $report += $lines[$from..$to]
    $report += "---"
    $i = $to
  }
}

# 5. Сгенерированные исходники на диске
$report += Section "5. generated sources on disk"
foreach ($p in @("$Module\target\generated-sources\protobuf\java", "$Module\target\generated-sources\protobuf\grpc-java")) {
  if (Test-Path $p) {
    $n = (Get-ChildItem $p -Recurse -Filter *.java | Measure-Object).Count
    $newest = (Get-ChildItem $p -Recurse -Filter *.java | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    $report += "$p : $n .java, newest $($newest.LastWriteTime)"
  } else { $report += "$p : MISSING" }
}

# 6. .classpath, который построил JDT LS
$report += Section "6. JDT .classpath entries"
$ws = Join-Path $env:APPDATA "Code\User\workspaceStorage"
$cps = Get-ChildItem $ws -Recurse -Filter ".classpath" -ErrorAction SilentlyContinue |
       Where-Object { $_.FullName -match [Regex]::Escape($Module) }
if (-not $cps) { $report += "не найдено .classpath для модуля $Module под $ws" }
foreach ($cp in $cps) {
  $report += "file: $($cp.FullName)"
  $report += "modified: $($cp.LastWriteTime)"
  $report += (Get-Content $cp.FullName | Select-String -Pattern 'kind="src"|generated' | ForEach-Object { "  " + $_.Line.Trim() })
}

# 7. Лог JDT LS: ошибки про maven / lifecycle / protobuf
$report += Section "7. JDT LS log (maven/lifecycle/protobuf/ERROR)"
$logs = Get-ChildItem $ws -Recurse -Filter ".log" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match 'redhat\.java' } | Sort-Object LastWriteTime -Descending | Select-Object -First 2
foreach ($l in $logs) {
  $report += "file: $($l.FullName)  (modified $($l.LastWriteTime))"
  $report += (Get-Content $l.FullName -Tail 4000 |
              Select-String -Pattern 'lifecycle|protobuf|not covered|Updating Maven|ERROR|Exception' |
              Select-Object -Last 60 | ForEach-Object { "  " + $_.Line })
}

# 8. Проблемы конфигурации проекта, если m2e их записал
$report += Section "8. m2e markers / project config"
$prefs = Get-ChildItem $ws -Recurse -Filter "org.eclipse.m2e.core.prefs" -ErrorAction SilentlyContinue | Select-Object -First 3
foreach ($p in $prefs) { $report += "file: $($p.FullName)"; $report += (Get-Content $p.FullName | ForEach-Object { "  $_" }) }

$report | Out-File -FilePath $Out -Encoding UTF8
Write-Host "готово: $Out" -ForegroundColor Green
Write-Host "размер: $((Get-Item $Out).Length) bytes"
