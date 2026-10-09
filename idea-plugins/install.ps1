# Offline install of IntelliJ IDEA plugins.
# Unpacks plugin archives straight into the IDE config plugins directory.
# IDEA MUST BE CLOSED while this runs.
#
# Usage:
#   .\install.ps1 -Branch 2026.2-262
#   .\install.ps1 -Branch 2025.3-253 -PluginsDir "C:\Users\me\AppData\Roaming\JetBrains\IntelliJIdea2025.3\plugins"

param(
    [Parameter(Mandatory = $true)][string]$Branch,
    [string]$PluginsDir
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot $Branch
if (-not (Test-Path $src)) {
    Write-Host "Branch folder not found: $src" -ForegroundColor Red
    Write-Host "Available:" -ForegroundColor Yellow
    Get-ChildItem $PSScriptRoot -Directory | ForEach-Object { "  " + $_.Name }
    exit 1
}

if (-not $PluginsDir) {
    $root = Join-Path $env:APPDATA 'JetBrains'
    $ide = Get-ChildItem $root -Directory -Filter 'IntelliJIdea*' -ErrorAction SilentlyContinue |
           Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ide) {
        Write-Host "IDE config dir not found under $root. Pass -PluginsDir explicitly." -ForegroundColor Red
        exit 1
    }
    $PluginsDir = Join-Path $ide.FullName 'plugins'
    Write-Host "Detected IDE config: $($ide.Name)" -ForegroundColor Cyan
}

# Refuse to run while the IDE holds the plugin dir open.
if (Get-Process -Name 'idea64' -ErrorAction SilentlyContinue) {
    Write-Host "IntelliJ IDEA is running. Close it first." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $PluginsDir | Out-Null
Write-Host "Target: $PluginsDir`n" -ForegroundColor Cyan

foreach ($zip in Get-ChildItem $src -Filter *.zip | Sort-Object Name) {
    Write-Host "-> $($zip.Name)"
    try {
        Expand-Archive -LiteralPath $zip.FullName -DestinationPath $PluginsDir -Force
        Write-Host "   ok" -ForegroundColor Green
    } catch {
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nInstalled plugin folders:" -ForegroundColor Cyan
Get-ChildItem $PluginsDir -Directory | ForEach-Object { "  " + $_.Name }
Write-Host "`nStart IDEA and check Settings | Plugins | Installed." -ForegroundColor Yellow
