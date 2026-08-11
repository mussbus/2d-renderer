[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$blender = Join-Path $repositoryRoot '.deps\blender-4.5.9-windows-x64\blender.exe'
$script = Join-Path $repositoryRoot 'tools\render_hm08_adoption_evidence.py'
$source = Join-Path $repositoryRoot 'assets\canonical_model\human_base\geometry\human_base_geometry.authoring.json'
$qualification = Join-Path $repositoryRoot 'tools\hm08_qualification\qualification.py'
$evidence = Join-Path $repositoryRoot 'assets\canonical_model\human_base\geometry\evidence\prompt_2c_t3_hm08_adoption'
$working = Join-Path $repositoryRoot '.authoring-work\hm08-adoption\human_base_geometry_hm08_t3_visual.blend'
$expectedSourceSha256 = '29552addc3d550c4a423609598a0dfbc5d28629e62329fb11ef6ce52cab875bf'

if (-not (Test-Path -LiteralPath $blender -PathType Leaf)) { throw "Pinned Blender is missing at $blender" }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant() -ne $expectedSourceSha256) {
    throw 'T3 evidence renderer refuses an unreviewed authority identity.'
}
$output = @(& $blender --background --factory-startup --python $script -- --source $source --qualification-module $qualification --evidence-dir $evidence --working $working 2>&1)
$output | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0 -or -not (($output -join "`n").Contains('HM08_ADOPTION_RENDER_OK'))) {
    throw 'HM08 T3 evidence rendering failed.'
}
