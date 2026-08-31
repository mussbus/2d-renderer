[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$checksRoot = Join-Path $PSScriptRoot 'checks'
foreach ($helper in @('hygiene.ps1', 'architecture.ps1')) {
    $path = Join-Path $checksRoot $helper
    & $path
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

Write-Host 'Repository check passed: current architecture, build registration, and hygiene invariants are satisfied.'
