# Offline install of Drools/KIE VS Code extensions on Windows.
# Run from the folder containing the .vsix files:  powershell -ExecutionPolicy Bypass -File .\install.ps1

$order = @(
  'jim-moody.drools-1.2.0.vsix',
  'jhhtaylor.drools-formatter-0.3.1.vsix',
  'kie-group.bpmn-vscode-extension-10.2.0.vsix',
  'kie-group.dmn-vscode-extension-10.2.0.vsix',
  'kie-group.extended-services-vscode-extension-10.2.0.vsix',
  'kie-group.vscode-extension-kie-ba-bundle-10.2.0.vsix'
)

foreach ($f in $order) {
  $path = Join-Path $PSScriptRoot $f
  if (-not (Test-Path $path)) { Write-Warning "missing: $f"; continue }
  Write-Host "installing $f" -ForegroundColor Cyan
  code --install-extension $path --force
}

Write-Host "`nInstalled:" -ForegroundColor Green
code --list-extensions --show-versions
