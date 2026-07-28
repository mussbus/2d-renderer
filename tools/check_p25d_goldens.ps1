param(
    [switch]$CompareLatest
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'tests/goldens/p25d/manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if (-not $manifest.approved) {
    throw 'Prompt 25D golden manifest is not approved.'
}
if ($manifest.backend -ne 'direct3d12' -or $manifest.shader_format -ne 'DXIL') {
    throw 'Prompt 25D goldens must retain the approved D3D12/DXIL route.'
}

$checked = 0
foreach ($capture in $manifest.captures) {
    $goldenPath = Join-Path $repositoryRoot $capture.path
    if (-not (Test-Path -LiteralPath $goldenPath -PathType Leaf)) {
        throw "Missing Prompt 25D golden: $($capture.path)"
    }
    $goldenHash = (Get-FileHash -LiteralPath $goldenPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($goldenHash -ne $capture.sha256) {
        throw "Prompt 25D golden hash mismatch: $($capture.path)"
    }
    if ($CompareLatest) {
        $latestPath = Join-Path $repositoryRoot $capture.latest_path
        if (-not (Test-Path -LiteralPath $latestPath -PathType Leaf)) {
            throw "Missing latest Prompt 25D capture: $($capture.latest_path)"
        }
        $latestHash = (Get-FileHash -LiteralPath $latestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($latestHash -ne $capture.sha256) {
            throw "Latest Prompt 25D capture differs from approved golden: $($capture.latest_path)"
        }
    }
    $checked += 1
}

$comparison = if ($CompareLatest) { 'stored and latest captures' } else { 'stored captures' }
Write-Host "Prompt 25D goldens: $checked/$checked PASS ($comparison, D3D12/DXIL 640x480)"
