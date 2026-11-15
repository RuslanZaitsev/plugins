# OPTIONAL diagnostics for protobuf classes in VS Code (redhat.java + local.m2e-protobuf >= 1.1.0).
# Not needed for normal setup: install.ps1 is enough. Changes NOTHING on disk.
#
#   powershell -ExecutionPolicy Bypass -File .\fix-proto.ps1                       # check user profile
#   powershell -ExecutionPolicy Bypass -File .\fix-proto.ps1 -ProjectRoot C:\Work\IdeaProjects\digital-ksb-cache
#
# Since connector 1.1.0 a workspace lifecycle mapping that mentions protobuf-maven-plugin
# no longer disables the connector, so the mapping file is only reported, never modified.
# What it only reports:
#   - connector / redhat.java not installed
#   - Eclipse metadata (.project/.classpath) next to pom.xml -> project imported as Eclipse project (error 1013)
#   - pom-embedded m2e lifecycle-mapping for maven-compiler-plugin (the only thing that can bypass the connector)
#   - generated sources missing -> run mvn compile

param([string]$ProjectRoot = '')

$ErrorActionPreference = 'Stop'
function Ok($m)   { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]    $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "  [BAD]  $m" -ForegroundColor Red }
function Fixed($m){ Write-Host "  [fix]  $m" -ForegroundColor Cyan }

Write-Host "`n=== 1. extensions" -ForegroundColor White
$exts = @()
try { $exts = & code --list-extensions --show-versions 2>$null } catch { }
if (-not $exts) {
  Warn "'code' CLI not found in PATH - cannot verify extensions (Ctrl+Shift+P -> Shell Command: Install 'code' command in PATH)"
} else {
  $java = $exts | Where-Object { $_ -like 'redhat.java@*' }
  $conn = $exts | Where-Object { $_ -like 'local.m2e-protobuf@*' }
  if ($java) { Ok $java } else { Bad 'redhat.java is not installed' }
  if ($conn) { Ok $conn } else { Bad 'local.m2e-protobuf is not installed: code --install-extension .\local.m2e-protobuf-1.1.0.vsix' }
}

Write-Host "`n=== 2. workspace lifecycle mapping" -ForegroundColor White
$settings = Join-Path $env:APPDATA 'Code\User\settings.json'
$mapping = $null
if (Test-Path $settings) {
  $text = [IO.File]::ReadAllText($settings)
  $m = [regex]::Match($text, '"java\.configuration\.maven\.lifecycleMappings"\s*:\s*"([^"]+)"')
  if ($m.Success) { $mapping = $m.Groups[1].Value -replace '\\\\', '\' }
  if ($text -match '"java\.jdt\.ls\.protobufSupport\.enabled"\s*:\s*false') {
    Warn 'java.jdt.ls.protobufSupport.enabled=false: harmless for Maven (Gradle-only), but the line can be removed'
  }
} else {
  Warn "settings.json not found: $settings"
}

if (-not $mapping) {
  Ok 'java.configuration.maven.lifecycleMappings is not set - nothing overrides the connector'
} elseif (-not (Test-Path $mapping)) {
  Warn "mapping file from settings does not exist: $mapping (ignored by JDT LS)"
} else {
  [xml]$doc = Get-Content -LiteralPath $mapping -Raw -Encoding UTF8
  $nodes = @($doc.SelectNodes('//pluginExecution[pluginExecutionFilter/artifactId="protobuf-maven-plugin"]'))
  if ($nodes.Count -eq 0) { Ok "$mapping : no protobuf entries" }
  else { Ok "$mapping : $($nodes.Count) protobuf entr(y/ies) - harmless with connector 1.1.0, left as is" }
}

if ($ProjectRoot) {
  Write-Host "`n=== 3. project: $ProjectRoot" -ForegroundColor White
  if (-not (Test-Path $ProjectRoot)) { Bad "not found: $ProjectRoot"; exit 1 }
  $poms = Get-ChildItem -Path $ProjectRoot -Recurse -Filter pom.xml -File -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -notmatch '\\(target|node_modules|\.git)\\' }

  $eclipse = 0
  foreach ($p in $poms) {
    $d = $p.DirectoryName
    if ((Test-Path (Join-Path $d '.project')) -or (Test-Path (Join-Path $d '.classpath'))) {
      Bad "Eclipse metadata next to pom.xml: $d  (module imported as Eclipse project, m2e bypassed)"
      $eclipse++
    }
  }
  if ($eclipse -gt 0) { Warn 'move them away: powershell -ExecutionPolicy Bypass -File .\check-eclipse-artifacts.ps1 -Remove' }
  else { Ok 'no .project/.classpath next to pom.xml' }

  $withProto = 0
  foreach ($p in $poms) {
    $x = [IO.File]::ReadAllText($p.FullName)
    if ($x -notmatch 'protobuf-maven-plugin') { continue }
    $withProto++
    if ($x -match 'org\.eclipse\.m2e' -and $x -match '(?s)lifecycle-mapping.*maven-compiler-plugin') {
      Warn "$($p.FullName): pom-embedded m2e lifecycle-mapping mentions maven-compiler-plugin - may bypass the connector"
    }
    $gen = Join-Path $p.DirectoryName 'target\generated-sources\protobuf'
    $cnt = 0
    if (Test-Path $gen) { $cnt = @(Get-ChildItem $gen -Recurse -Filter *.java -File).Count }
    if ($cnt -gt 0) { Ok "$($p.Directory.Name): $cnt generated .java" }
    else { Warn "$($p.Directory.Name): no generated sources yet -> mvn compile -pl $($p.Directory.Name) -am" }
  }
  if ($withProto -eq 0) { Warn 'no module with protobuf-maven-plugin found (may be inherited from parent pom outside the repo - fine)' }
}

Write-Host "`n=== next" -ForegroundColor White
Write-Host '  after first install: Ctrl+Shift+P -> Java: Clean Java Language Server Workspace (once)' -ForegroundColor Cyan
Write-Host '  after changing .proto: mvn compile (VS Code picks up regenerated classes automatically)' -ForegroundColor Cyan
