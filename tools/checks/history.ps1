[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$evidenceBuild = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'build/evidence.zig')
$gatesBuild = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'build/gates.zig')
$requiredBuildMarkers = @(
    '"evidence-history"',
    '"update-human-geometry-refinement-evidence"',
    '"update-human-geometry-r1-evidence"',
    '"test-blender-bridge"',
    '"p27a-review"',
    '"p27b-review"'
)
$requiredFiles = @(
    'tools/export_human_geometry_refinement_evidence.zig',
    'tools/export_human_geometry_r1_evidence.zig',
    'tools/blender_bridge.ps1',
    'tools/build_p27a_review_package.ps1',
    'tools/build_p27b_review_package.ps1'
)

$failed = $false
foreach ($marker in $requiredBuildMarkers) {
    if (-not $evidenceBuild.Contains($marker)) {
        Write-Error "Historical evidence registration is missing $marker." -ErrorAction Continue
        $failed = $true
    }
}
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        Write-Error "Historical evidence implementation is missing '$relativePath'." -ErrorAction Continue
        $failed = $true
    }
}
if ($gatesBuild.Contains('.history')) {
    Write-Error 'Historical evidence reproduction may not be a dependency of routine aggregate gates.' -ErrorAction Continue
    $failed = $true
}
if ($failed) {
    exit 1
}
Write-Host 'Historical evidence registration passed: retained routes are reachable only through explicit on-demand steps.'
exit 0
