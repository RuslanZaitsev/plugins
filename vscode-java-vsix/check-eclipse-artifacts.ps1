<#
  Ищет Eclipse-метаданные в репозитории. Если .project/.classpath лежат рядом с pom.xml,
  JDT LS импортирует модуль как Eclipse-проект и ПОЛНОСТЬЮ игнорирует Maven-модель:
  m2e не строит classpath, lifecycle mapping ни на что не влияет.

  Проверка:  powershell -ExecutionPolicy Bypass -File .\check-eclipse-artifacts.ps1
  Удаление:  powershell -ExecutionPolicy Bypass -File .\check-eclipse-artifacts.ps1 -Remove
             (файлы переносятся в .eclipse-backup\, не удаляются насовсем)
#>
param([switch]$Remove)

$ErrorActionPreference = "Continue"
$root = Get-Location
$patterns = @(".project", ".classpath", ".factorypath", ".classpath.bak*", ".settings")
$found = @()

Write-Host "`nсканирую: $root" -ForegroundColor Cyan

foreach ($pat in $patterns) {
  $items = Get-ChildItem -Path $root -Filter $pat -Recurse -Force -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -notmatch '\\target\\' -and $_.FullName -notmatch '\\\.git\\' }
  foreach ($i in $items) { $found += $i }
}

if ($found.Count -eq 0) {
  Write-Host "`n[ok] Eclipse-метаданных в репозитории нет — проекты импортируются как Maven" -ForegroundColor Green
  exit 0
}

Write-Host "`nнайдено $($found.Count) объектов:" -ForegroundColor Yellow
foreach ($f in $found) {
  $rel = $f.FullName.Substring($root.Path.Length).TrimStart('\')
  $pomNear = Test-Path (Join-Path $f.DirectoryName "pom.xml")
  $flag = ""
  if ($pomNear) { $flag = "  <-- РЯДОМ С pom.xml: модуль импортируется как Eclipse-проект" }
  Write-Host "  $rel$flag"

  # для .classpath показать подозрительные source-записи
  if ($f.Name -eq ".classpath") {
    try {
      $xml = [xml](Get-Content $f.FullName -Raw)
      foreach ($e in $xml.classpath.classpathentry) {
        if ($e.kind -eq "src") {
          $bad = ""
          if ($e.path -match '^target($|/)' -and $e.path -notmatch 'generated') { $bad = "  <-- вероятная причина ошибки 1013" }
          if ($e.path -eq "target" -or $e.path -eq "target/classes") { $bad = "  <-- ПРИЧИНА ошибки 1013" }
          Write-Host "       src: $($e.path)$bad"
        }
      }
    } catch { Write-Host "       (XML не читается: $($_.Exception.Message))" }
  }
}

if ($Remove) {
  $backup = Join-Path $root ".eclipse-backup"
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  Write-Host "`nперенос в $backup" -ForegroundColor Cyan
  foreach ($f in $found) {
    $rel = $f.FullName.Substring($root.Path.Length).TrimStart('\')
    $dest = Join-Path $backup $rel
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    Move-Item -Path $f.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
    Write-Host "  перенесён: $rel"
  }
  Write-Host "`nдальше: закрыть VS Code, удалить кэш workspaceStorage, открыть проект заново" -ForegroundColor Yellow
} else {
  Write-Host "`nесли выше есть пометки 'РЯДОМ С pom.xml' — выполните:" -ForegroundColor Yellow
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\check-eclipse-artifacts.ps1 -Remove"
}
