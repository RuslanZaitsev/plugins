<#
  Проверка состояния JDT LS и последствий правок вокруг proto-классов.

  Диагностика (ничего не меняет):
      powershell -ExecutionPolicy Bypass -File .\check-jdtls.ps1
  Откат правок и чистка кэша:
      powershell -ExecutionPolicy Bypass -File .\check-jdtls.ps1 -Fix

  -Fix делает только безопасные операции:
    * останавливает процессы языкового сервера
    * бэкапит и удаляет записи protobuf из lifecycle mapping (они выключают коннектор local.m2e-protobuf)
    * удаляет proto-классы, скопированные в target/generated-sources/annotations
    * удаляет кэш workspaceStorage (пересоздастся, теряются только индексы)
  settings.json и .m2\settings.xml НЕ правятся автоматически — только отчёт.
#>

param(
  [switch]$Fix,
  [string]$Module = "digital-ksb-cache-service"
)

$ErrorActionPreference = "Continue"
$problems = @()
$actions  = @()

function Head($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "  [ok]   $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  [!]    $t" -ForegroundColor Yellow }
function Bad($t)  { Write-Host "  [BAD]  $t" -ForegroundColor Red }

# ---------------------------------------------------------------- 1. процессы
Head "1. процессы"
$code = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if ($code) { Warn "VS Code запущен ($($code.Count) проц.) — для -Fix его лучше закрыть" }
else { Ok "VS Code закрыт" }

$jdt = Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
       Where-Object { $_.CommandLine -match 'jdt\.ls|jdtls|org\.eclipse\.equinox\.launcher' }
if ($jdt) {
  foreach ($p in $jdt) {
    $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    $mb = 0
    if ($proc) { $mb = [Math]::Round($proc.WorkingSet64 / 1MB) }
    $cpu = 0
    if ($proc) { $cpu = [Math]::Round($proc.CPU) }
    Warn "jdt.ls PID $($p.ProcessId): RAM ${mb}MB, CPU ${cpu}s"
  }
  $problems += "языковой сервер запущен"
} else { Ok "процессов jdt.ls нет" }

# ------------------------------------------------- 2. настройки VS Code (java.*)
Head "2. settings.json"
$settings = Join-Path $env:APPDATA "Code\User\settings.json"
$raw = ""
if (Test-Path $settings) {
  $raw = Get-Content $settings -Raw
  $checks = @{
    'java.autobuild.enabled'                      = 'false'
    'java.import.maven.offline.enabled'           = 'true'
  }
  foreach ($k in $checks.Keys) {
    if ($raw -match [Regex]::Escape($k) + '"\s*:\s*' + $checks[$k]) { Ok "$k = $($checks[$k])" }
    else { Warn "$k не выставлен в $($checks[$k]) — при зависании это первое, что стоит сделать" }
  }
  if ($raw -match '"java\.jdt\.ls\.vmargs"\s*:\s*"([^"]*)"') {
    $vm = $Matches[1]
    if ($vm -match '-Xmx(\d+)([GgMm])') {
      $size = [int]$Matches[1]; $unit = $Matches[2].ToUpper()
      $gb = $size
      if ($unit -eq 'M') { $gb = [Math]::Round($size / 1024, 1) }
      if ($gb -ge 4) { Ok "-Xmx = ${gb}G" } else { Warn "-Xmx = ${gb}G — для монорепы маловато, стоит 4-6G" }
    }
  }
  if ($raw -match '"java\.jdt\.ls\.protobufSupport\.enabled"\s*:\s*false') {
    Warn "java.jdt.ls.protobufSupport.enabled=false — это Gradle-only настройка, на Maven не влияет; можно удалить строку"
  }
} else { Bad "не найден: $settings" }

# --------------------------------------------- 3. lifecycle mapping: что внутри
Head "3. lifecycle mapping"
$lmPath = $null
if ($raw -match '"java\.configuration\.maven\.lifecycleMappings"\s*:\s*"([^"]+)"') {
  $lmPath = $Matches[1] -replace '\\\\', '\'
}
if (-not $lmPath) { Ok "настройка lifecycleMappings не задана (нейтральное состояние)" }
elseif (-not (Test-Path $lmPath)) { Bad "файл не найден: $lmPath — настройка ни на что не влияет" }
else {
  Write-Host "  файл: $lmPath ($((Get-Item $lmPath).Length) bytes)"
  $xml = $null
  try { $xml = [xml](Get-Content $lmPath -Raw) } catch { Bad "XML не парсится: $($_.Exception.Message)" }
  if ($xml) {
    $pbNodes = @($xml.lifecycleMappingMetadata.pluginExecutions.pluginExecution |
                 Where-Object { $_.pluginExecutionFilter.artifactId -eq 'protobuf-maven-plugin' })
    if ($pbNodes.Count -eq 0) { Ok "блока protobuf нет" }
    if ($pbNodes.Count -gt 0) {
      # любая запись (ignore/execute) приоритетнее коннектора local.m2e-protobuf и выключает его
      Bad "protobuf: $($pbNodes.Count) запись(ей) в workspace mapping — перебивает коннектор local.m2e-protobuf"
      $problems += "lifecycle mapping: запись для protobuf"
      if ($Fix) {
        Copy-Item $lmPath "$lmPath.bak" -Force
        foreach ($n in $pbNodes) { $null = $n.ParentNode.RemoveChild($n) }
        $xml.Save($lmPath)
        $actions += "lifecycle mapping: protobuf-записи удалены (бэкап $lmPath.bak)"
        Ok "protobuf-записи удалены"
      }
    }
  }
}

# ------------------------------------- 4. профиль в .m2\settings.xml (цикл сборки)
Head "4. maven settings.xml"
$userSettings = $null
if ($raw -match '"java\.configuration\.maven\.userSettings"\s*:\s*"([^"]+)"') {
  $userSettings = $Matches[1] -replace '\\\\', '\'
}
if (-not $userSettings) { $userSettings = Join-Path $env:USERPROFILE ".m2\settings.xml" }
if (Test-Path $userSettings) {
  Write-Host "  файл: $userSettings"
  $hits = Select-String -Path $userSettings -Pattern 'javaOutputDirectory|protocPluginOutputDirectory|vscode-proto-sources' -ErrorAction SilentlyContinue
  if ($hits) {
    Bad "найдено перенаправление вывода protoc — ВЕРОЯТНАЯ ПРИЧИНА ЗАВИСАНИЯ"
    Write-Host "       protoc пишет .java в source root, JDT видит изменение -> пересборка -> protoc снова -> цикл"
    foreach ($h in $hits) { Write-Host "       строка $($h.LineNumber): $($h.Line.Trim())" }
    Write-Host "       УБРАТЬ ВРУЧНУЮ (файл может содержать креды Nexus, автоматически не правлю)" -ForegroundColor Yellow
    $problems += "settings.xml: перенаправление protoc в source root"
  } else { Ok "перенаправления вывода protoc нет" }
} else { Warn "не найден: $userSettings" }

# ------------------------------------------- 5. мусор в generated-sources/annotations
Head "5. target\generated-sources\annotations"
$ann = Join-Path (Get-Location) "$Module\target\generated-sources\annotations"
if (Test-Path $ann) {
  $all = @(Get-ChildItem $ann -Recurse -Filter *.java -ErrorAction SilentlyContinue)
  $proto = @($all | Where-Object { $_.FullName -match '\\proto\\' -or $_.Name -match 'Grpc|OuterClass|Proto\.java$' })
  Write-Host "  всего .java: $($all.Count), похожих на proto: $($proto.Count)"
  if ($proto.Count -gt 0) {
    Bad "proto-классы лежат в APT-каталоге (копия или перенаправление вывода)"
    $problems += "annotations содержит proto-классы"
    if ($Fix) {
      Remove-Item $ann -Recurse -Force -ErrorAction SilentlyContinue
      $actions += "удалён каталог $ann (пересоздастся при сборке)"
      Ok "каталог удалён"
    }
  } else { Ok "посторонних классов нет" }
} else { Ok "каталога нет (нормально до сборки)" }

# ------------------------------------------------------- 6. сгенерированные proto
Head "6. сгенерированные proto на диске"
foreach ($p in @("$Module\target\generated-sources\protobuf\java", "$Module\target\generated-sources\protobuf\grpc-java")) {
  if (Test-Path $p) {
    $n = @(Get-ChildItem $p -Recurse -Filter *.java -ErrorAction SilentlyContinue).Count
    Ok "$p : $n .java"
  } else { Warn "$p : нет — нужен mvn compile" }
}

# ---------------------------------------------------------------- 7. .classpath
Head "7. .classpath"
$ws = Join-Path $env:APPDATA "Code\User\workspaceStorage"
$cps = @(Get-ChildItem $ws -Recurse -Filter ".classpath" -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -match [Regex]::Escape($Module) })
if ($cps.Count -eq 0) { Warn "не найден .classpath для $Module" }
foreach ($cp in $cps) {
  Write-Host "  $($cp.FullName)"
  $txt = Get-Content $cp.FullName -Raw
  if ($txt -match 'generated-sources/protobuf') { Ok "запись protobuf ЕСТЬ" }
  else { Warn "записи protobuf нет — это и есть исходный симптом" }
}

# ------------------------------------------------- 8. признаки цикла в логе
Head "8. лог сервера: признаки цикла"
$logs = @(Get-ChildItem $ws -Recurse -Filter ".log" -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -match 'redhat\.java' } |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1)
foreach ($l in $logs) {
  Write-Host "  $($l.FullName)"
  $tail = Get-Content $l.FullName -Tail 3000 -ErrorAction SilentlyContinue
  $builds = @($tail | Select-String -Pattern 'Building|Build All|Full Build|Incremental Build').Count
  $errs   = @($tail | Select-String -Pattern 'OutOfMemory|StackOverflow|Could not|Exception').Count
  Write-Host "  упоминаний сборки в хвосте: $builds, ошибок: $errs"
  if ($builds -gt 50) { Bad "очень много сборок подряд — похоже на цикл пересборки"; $problems += "цикл пересборки в логе" }
  if ($errs -gt 0) {
    Warn "последние ошибки:"
    $tail | Select-String -Pattern 'OutOfMemory|StackOverflow|Could not|Exception' | Select-Object -Last 5 |
      ForEach-Object { Write-Host "       $($_.Line)" }
  }
}

# ---------------------------------------------------- 9. кэш воркспейса
Head "9. кэш workspaceStorage"
$stores = @(Get-ChildItem $ws -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "redhat.java") })
foreach ($s in $stores) {
  $size = 0
  $items = Get-ChildItem $s.FullName -Recurse -File -ErrorAction SilentlyContinue
  foreach ($i in $items) { $size += $i.Length }
  $mb = [Math]::Round($size / 1MB)
  $marker = ""
  if ($cps.Count -gt 0 -and $cps[0].FullName.StartsWith($s.FullName)) { $marker = "  <-- этот проект" }
  Write-Host "  $($s.Name): ${mb}MB, изменён $($s.LastWriteTime)$marker"
  if ($Fix -and $marker -ne "") {
    if ($code) { Warn "VS Code запущен — кэш не удаляю, закройте редактор и повторите -Fix" }
    else {
      Remove-Item $s.FullName -Recurse -Force -ErrorAction SilentlyContinue
      $actions += "удалён кэш $($s.FullName)"
      Ok "кэш удалён"
    }
  }
}

# ------------------------------------------------------------- 10. -Fix: процессы
if ($Fix -and $jdt) {
  Head "10. остановка языкового сервера"
  foreach ($p in $jdt) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    $actions += "остановлен jdt.ls PID $($p.ProcessId)"
    Ok "PID $($p.ProcessId) остановлен"
  }
}

# ------------------------------------------------------------------- итог
Head "ИТОГ"
if ($problems.Count -eq 0) { Ok "проблем не найдено" }
else { foreach ($p in $problems) { Bad $p } }

if ($Fix) {
  Write-Host "`nвыполнено:" -ForegroundColor Cyan
  if ($actions.Count -eq 0) { Write-Host "  (нечего было менять)" }
  foreach ($a in $actions) { Write-Host "  - $a" }
  Write-Host "`nдальше вручную:" -ForegroundColor Yellow
  Write-Host "  1. убрать профиль с javaOutputDirectory/protocPluginOutputDirectory из $userSettings, если он найден выше"
  Write-Host "  2. в settings.json поставить: `"java.autobuild.enabled`": false"
  Write-Host "  3. открыть проект, дождаться индексации, затем вернуть autobuild"
} else {
  Write-Host "`nзапустить откат: powershell -ExecutionPolicy Bypass -File .\check-jdtls.ps1 -Fix" -ForegroundColor Yellow
}
