[CmdletBinding()]
param(
    [string]$Source = 'assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json',
    [string]$EvidenceDirectory = 'assets/canonical_model/human_base/geometry/evidence/prompt_2c_r3_hm08_neutral_adaptation'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$blender = Join-Path $repositoryRoot '.deps\blender-4.5.9-windows-x64\blender.exe'
$renderer = Join-Path $repositoryRoot 'tools\render_human_geometry_r3_evidence.py'
$qualification = Join-Path $repositoryRoot 'tools\hm08_qualification\qualification.py'
$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Source))
$evidencePath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $EvidenceDirectory))

if (-not (Test-Path -LiteralPath $blender -PathType Leaf)) {
    throw "Pinned Blender 4.5.9 LTS is missing at '$blender'."
}

& $blender --background --factory-startup --python $renderer -- `
    --source $sourcePath `
    --qualification-module $qualification `
    --evidence-dir $evidencePath
if ($LASTEXITCODE -ne 0) {
    throw "Prompt 2C-R3 evidence renderer failed with exit code $LASTEXITCODE."
}

Write-Host "R3_EVIDENCE_RENDER_PASS evidence=$evidencePath"
