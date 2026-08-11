[CmdletBinding()]
param(
    [switch]$SkipRender
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$commit = '437dd513888a92399d1d3200d2e80859fae55abc'
$upstreamRoot = Join-Path $repositoryRoot ".deps\external\mpfb2-$commit"
$blender = Join-Path $repositoryRoot '.deps\blender-4.5.9-windows-x64\blender.exe'
$script = Join-Path $repositoryRoot 'tools\hm08_qualification\qualification.py'
$comparisonComposer = Join-Path $repositoryRoot 'tools\hm08_qualification\compose_comparisons.ps1'
$r1Working = Join-Path $repositoryRoot '.authoring-work\human_base_geometry_r1_working.blend'
$working = Join-Path $repositoryRoot '.authoring-work\hm08_qualification\hm08_vs_r1_inspection.blend'
$evidence = Join-Path $repositoryRoot 'assets\canonical_model\human_base\geometry\evidence\prompt_2c_t2_hm08'
$arguments = @(
    '--background', $r1Working,
    '--python', $script, '--',
    '--obj', (Join-Path $upstreamRoot 'src\mpfb\data\3dobjs\base.obj'),
    '--license', (Join-Path $upstreamRoot 'LICENSE.ASSETS.md'),
    '--config', (Join-Path $upstreamRoot 'src\mpfb\data\mesh_metadata\hm08_config.json'),
    '--mirror', (Join-Path $upstreamRoot 'src\mpfb\data\mesh_metadata\hm08.mirror'),
    '--vertex-groups', (Join-Path $upstreamRoot 'src\mpfb\data\mesh_metadata\basemesh_vertex_groups.json'),
    '--r1-source', (Join-Path $repositoryRoot 'assets\canonical_model\human_base\geometry\human_base_geometry.authoring.json'),
    '--structural-report', (Join-Path $repositoryRoot 'assets\canonical_model\human_base\human_base.structural_report.txt'),
    '--structural-source', (Join-Path $repositoryRoot 'assets\canonical_model\human_base\human_base.authoring.json'),
    '--evidence-dir', $evidence,
    '--working', $working
)
if (-not $SkipRender) {
    $arguments += '--render'
}

if (-not (Test-Path -LiteralPath $blender -PathType Leaf)) {
    throw "Pinned Blender 4.5.9 LTS executable is absent at '$blender'."
}
if (-not (Test-Path -LiteralPath $r1Working -PathType Leaf)) {
    throw "The reproducible R1 Blender working representation is absent at '$r1Working'."
}

$version = @(& $blender --version 2>&1) | Select-Object -First 1
if ($LASTEXITCODE -ne 0 -or $version -ne 'Blender 4.5.9 LTS') {
    throw "Pinned Blender version mismatch. Expected Blender 4.5.9 LTS, actual '$version'."
}

Push-Location $repositoryRoot
try {
    & $blender @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "hm08 qualification failed with exit code $LASTEXITCODE."
    }
    if (-not $SkipRender) {
        & $comparisonComposer -ImagesDirectory (Join-Path $evidence 'images')
    }
}
finally {
    Pop-Location
}
