# Offline install of the Java/Spring/Kafka/proto extension set.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# Order matters: extensionDependencies are not resolved offline, so dependencies go first.

$order = @(
  # --- base language servers (everything Java depends on redhat.java) ---
  'redhat.java-1.57.2026090408.vsix',  # НЕ обновлять: новее = сломанный lombok, см. README
  'redhat.vscode-xml-*',
  'redhat.vscode-yaml-*',
  # --- Java tooling ---
  'vscjava.vscode-java-debug-*',
  'vscjava.vscode-java-test-*',
  'vscjava.vscode-maven-*',
  'vscjava.vscode-java-dependency-*',
  'vscjava.vscode-gradle-*',
  'vscjava.vscode-java-pack-*',
  'dgileadi.java-decompiler-*',
  'shengchen.vscode-checkstyle-*',
  # --- Spring ---
  'vmware.vscode-spring-boot-*',
  'vscjava.vscode-spring-initializr-*',
  'vscjava.vscode-spring-boot-dashboard-*',
  'vmware.vscode-boot-dev-pack-*',
  # --- Kotlin ---
  'fwcd.kotlin-*',
  # --- Kafka / proto / infra ---
  'jeppeandersen.vscode-kafka-*',
  'bufbuild.vscode-buf-*',
  'zxh404.vscode-proto3-*',
  'ms-kubernetes-tools.vscode-kubernetes-tools-*',
  'ms-azuretools.vscode-containers-*',
  # --- quality / DB / git / UX ---
  'mtxr.sqltools-0*',
  'mtxr.sqltools-driver-pg-*',
  'humao.rest-client-*',
  'eamodio.gitlens-*',
  'editorconfig.editorconfig-*',
  'usernamehw.errorlens-*',
  'k--kato.intellij-idea-keybindings-*'
)

$all = Get-ChildItem -Path $PSScriptRoot -Filter *.vsix | Select-Object -ExpandProperty Name
$done = @()

foreach ($pattern in $order) {
  foreach ($f in ($all | Where-Object { $_ -like $pattern } | Sort-Object)) {
    if ($done -contains $f) { continue }
    Write-Host "installing $f" -ForegroundColor Cyan
    code --install-extension (Join-Path $PSScriptRoot $f) --force
    $done += $f
  }
}

# anything not covered by the ordered list
foreach ($f in ($all | Where-Object { $done -notcontains $_ })) {
  Write-Host "installing $f (unordered)" -ForegroundColor Yellow
  code --install-extension (Join-Path $PSScriptRoot $f) --force
}

Write-Host "`nInstalled:" -ForegroundColor Green
code --list-extensions --show-versions
