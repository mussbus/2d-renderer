[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Import', 'ExportCandidate', 'RoundTrip', 'Test', 'Allocate', 'ValidateCandidate', 'SelectFaceSet', 'SelectRegion', 'MarkUnallocated', 'CopyFaceSemantics')]
    [string]$Command,
    [string]$Source = 'assets/canonical_model/human_base/geometry/human_base_geometry.authoring.json',
    [string]$Working = '.authoring-work/r4/human_base_geometry_r4_authority.blend',
    [string]$Sidecar = '.authoring-work/r4/human_base_geometry_r4_authority.sidecar.json',
    [string]$Candidate = '.authoring-work/human_base_geometry.candidate.json',
    [string]$Evidence = '.authoring-work/human_base_geometry.candidate.validation.txt',
    [string]$FaceSetId,
    [string]$RegionId,
    [string]$MeshId = 'human_base_main_body',
    [string]$VertexIndexes = '',
    [string]$FaceIndexes = '',
    [uint32]$SourceFaceId,
    [string]$TargetPolygonIndexes = '',
    [switch]$AllowPositionEdits
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$blenderRoot = Join-Path $repositoryRoot '.deps\blender-4.5.9-windows-x64'
$blender = Join-Path $blenderRoot 'blender.exe'
$archive = Join-Path $repositoryRoot '.deps\cache\blender-4.5.9-windows-x64.zip'
$bridge = Join-Path $repositoryRoot 'tools\blender_bridge\bridge.py'
$zig = Join-Path $repositoryRoot '.deps\zig-0.16.0\zig.exe'
$installedValidator = Join-Path $repositoryRoot 'zig-out\bin\validate-human-geometry-candidate.exe'
$expectedArchiveSha256 = '41da973b9bf95bb312cbeff4d1982feb13259b43c821686b9bafea4dfe5477cf'
$expectedSourceSha256 = '4bed342c289f1f1238c7397c524b63e32d2037737cde08304fe5c47af1b43b8f'
$expectedNormalizedSha256 = 'd7fee949a5ee70c926f19dc46615fa965fa2d75176ba1fc0ea4e02d50aa9b096'
$expectedTopologySha256 = '335be5d44d7200925db18db3361ca19ad0438dd97725f300cd52332417cbf191'
$expectedTriangulationSha256 = '967ee28004e1bb721019919513a73c4aad6b19180d3c45afb704cc0f53864444'
$expectedNeutralSignature = '31beb6c39ffdcfd6ae009c1b416b7c78a000230ca5ce11de6e2f01dd150022f7'
$expectedStructuralSha256 = 'b1baf0c2587e5bf511f36a8695d01ebdd7da2e28e5f0d1990af32ae3bf2c2bda'

function Resolve-RepositoryPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

function Assert-Dependency {
    param([switch]$VerifyArchive)

    if (-not (Test-Path -LiteralPath $blender -PathType Leaf)) {
        throw "Pinned Blender executable is missing at '$blender'. Run tools/bootstrap_dependencies.ps1."
    }
    if ($VerifyArchive) {
        if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
            throw "Pinned Blender archive is missing at '$archive'."
        }
        $archiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
        if ($archiveHash -ne $expectedArchiveSha256) {
            throw "Pinned Blender archive SHA-256 mismatch. Expected $expectedArchiveSha256, actual $archiveHash."
        }
    }
    $versionLines = @(& $blender --version 2>&1)
    $versionExitCode = $LASTEXITCODE
    $versionOutput = $versionLines | Select-Object -First 1
    if ($versionExitCode -ne 0 -or $versionOutput -ne 'Blender 4.5.9 LTS') {
        throw "Pinned Blender version mismatch. Expected 'Blender 4.5.9 LTS', actual '$versionOutput'."
    }
}

function Assert-SourceIdentity {
    param([Parameter(Mandatory)][string]$Path)

    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    if ($actual -ne $expectedSourceSha256) {
        throw "Current geometry authority changed. Expected $expectedSourceSha256, actual $actual."
    }
}

function Invoke-BlenderBridge {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$OpenWorkingFile
    )

    $commandArguments = @('--background')
    if ([string]::IsNullOrWhiteSpace($OpenWorkingFile)) {
        $commandArguments += '--factory-startup'
    }
    else {
        $commandArguments += $OpenWorkingFile
    }
    $commandArguments += @('--python', $bridge, '--')
    $commandArguments += $Arguments
    & $blender @commandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Blender bridge command failed with exit code $LASTEXITCODE."
    }
}

function Import-CanonicalWorkingFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$WorkingPath,
        [Parameter(Mandatory)][string]$SidecarPath
    )

    Assert-SourceIdentity -Path $SourcePath
    Invoke-BlenderBridge -Arguments @(
        'import',
        '--source', $SourcePath,
        '--source-hash', $expectedSourceSha256,
        '--normalized-hash', $expectedNormalizedSha256,
        '--structural-hash', $expectedStructuralSha256,
        '--working', $WorkingPath,
        '--sidecar', $SidecarPath
    )
}

function Export-CanonicalCandidate {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$WorkingPath,
        [Parameter(Mandatory)][string]$SidecarPath,
        [Parameter(Mandatory)][string]$CandidatePath,
        [switch]$AllowPositionEdits
    )

    Assert-SourceIdentity -Path $SourcePath
    if ([System.IO.Path]::GetFullPath($CandidatePath).Equals([System.IO.Path]::GetFullPath($SourcePath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Candidate export refuses to target the authoritative geometry JSON.'
    }
    $arguments = @(
        'export',
        '--source', $SourcePath,
        '--sidecar', $SidecarPath,
        '--candidate', $CandidatePath
    )
    if ($AllowPositionEdits) {
        $arguments += '--allow-position-edits'
    }
    Invoke-BlenderBridge -OpenWorkingFile $WorkingPath -Arguments $arguments
}

function Validate-Candidate {
    param(
        [Parameter(Mandatory)][string]$CandidatePath,
        [Parameter(Mandatory)][string]$EvidencePath
    )

    if (Test-Path -LiteralPath $installedValidator -PathType Leaf) {
        & $installedValidator $CandidatePath $EvidencePath
        if ($LASTEXITCODE -ne 0) {
            throw "Canonical candidate validator failed with exit code $LASTEXITCODE."
        }
    }
    else {
        & $zig build validate-human-geometry-candidate -j1 --summary all -- $CandidatePath $EvidencePath
        if ($LASTEXITCODE -ne 0) {
            throw "Canonical candidate validation build failed with exit code $LASTEXITCODE."
        }
    }
}

function Assert-RoundTripEvidence {
    param([Parameter(Mandatory)][string]$EvidencePath)

    $evidenceText = Get-Content -Raw -LiteralPath $EvidencePath
    $expectedLines = @(
        "normalized_geometry_sha256=$expectedNormalizedSha256",
        "control_topology_sha256=$expectedTopologySha256",
        "triangulation_sha256=$expectedTriangulationSha256",
        "neutral_geometry_signature=$expectedNeutralSignature",
        "structural_normalized_sha256=$expectedStructuralSha256",
        'mesh_count=1',
        'vertex_count=13380',
        'face_count=13378',
        'face_set_count=44',
        'topology_loop_count=44',
        'seam_binding_count=11',
        'geometry_binding_count=35',
        'mesh=human_base_main_body next_vertex_id=13380 next_face_id=13378'
    )
    foreach ($expectedLine in $expectedLines) {
        if (-not $evidenceText.Contains($expectedLine)) {
            throw "No-op round-trip evidence is missing '$expectedLine'."
        }
    }
}

function Assert-InvalidCandidateRejected {
    param([Parameter(Mandatory)][string]$ValidCandidatePath)

    if (-not (Test-Path -LiteralPath $installedValidator -PathType Leaf)) {
        throw "Focused fail-closed validation requires the installed candidate validator at '$installedValidator'."
    }
    $invalidCandidatePath = "$ValidCandidatePath.invalid.json"
    Invoke-BlenderBridge -Arguments @(
        'make-invalid-candidate', '--candidate', $ValidCandidatePath, '--output', $invalidCandidatePath
    )
    $invalidOutput = @(& $installedValidator $invalidCandidatePath 2>&1)
    $invalidExitCode = $LASTEXITCODE
    if ($invalidExitCode -eq 0) {
        throw 'Malformed bridge candidate unexpectedly passed canonical validation.'
    }
    if (-not (($invalidOutput -join "`n").Contains('InvalidGeometrySource'))) {
        throw "Malformed bridge candidate failed for an unexpected reason: $($invalidOutput -join ' ')"
    }
    Write-Host 'BLENDER_BRIDGE_INVALID_CANDIDATE_REJECTED diagnostic=InvalidGeometrySource'
}

$sourcePath = Resolve-RepositoryPath -Path $Source
$workingPath = Resolve-RepositoryPath -Path $Working
$sidecarPath = Resolve-RepositoryPath -Path $Sidecar
$candidatePath = Resolve-RepositoryPath -Path $Candidate
$evidencePath = Resolve-RepositoryPath -Path $Evidence

Push-Location $repositoryRoot
try {
    switch ($Command) {
        'Import' {
            Assert-Dependency
            Import-CanonicalWorkingFile -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath
        }
        'ExportCandidate' {
            Assert-Dependency
            Export-CanonicalCandidate -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath -CandidatePath $candidatePath -AllowPositionEdits:$AllowPositionEdits
        }
        'Allocate' {
            Assert-Dependency
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'allocate', '--source', $sourcePath, '--sidecar', $sidecarPath
            )
        }
        'ValidateCandidate' {
            Validate-Candidate -CandidatePath $candidatePath -EvidencePath $evidencePath
        }
        'SelectFaceSet' {
            Assert-Dependency
            if ([string]::IsNullOrWhiteSpace($FaceSetId)) { throw 'SelectFaceSet requires -FaceSetId.' }
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'select-face-set', '--source', $sourcePath, '--sidecar', $sidecarPath, '--face-set-id', $FaceSetId
            )
        }
        'SelectRegion' {
            Assert-Dependency
            if ([string]::IsNullOrWhiteSpace($RegionId)) { throw 'SelectRegion requires -RegionId.' }
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'select-region', '--source', $sourcePath, '--sidecar', $sidecarPath, '--region-id', $RegionId
            )
        }
        'MarkUnallocated' {
            Assert-Dependency
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'mark-unallocated', '--source', $sourcePath, '--sidecar', $sidecarPath,
                '--mesh-id', $MeshId, '--vertex-indexes', $VertexIndexes, '--face-indexes', $FaceIndexes
            )
        }
        'CopyFaceSemantics' {
            Assert-Dependency
            if ([string]::IsNullOrWhiteSpace($TargetPolygonIndexes)) {
                throw 'CopyFaceSemantics requires -TargetPolygonIndexes.'
            }
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'copy-face-semantics', '--source', $sourcePath, '--sidecar', $sidecarPath,
                '--mesh-id', $MeshId, '--source-face-id', $SourceFaceId,
                '--target-polygon-indexes', $TargetPolygonIndexes
            )
        }
        'RoundTrip' {
            Assert-Dependency
            Import-CanonicalWorkingFile -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath
            Export-CanonicalCandidate -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath -CandidatePath $candidatePath
            Validate-Candidate -CandidatePath $candidatePath -EvidencePath $evidencePath
            Assert-RoundTripEvidence -EvidencePath $evidencePath
            Assert-InvalidCandidateRejected -ValidCandidatePath $candidatePath
            Assert-SourceIdentity -Path $sourcePath
            Write-Host "BLENDER_BRIDGE_ROUNDTRIP_OK normalized=$expectedNormalizedSha256 topology=$expectedTopologySha256 triangulation=$expectedTriangulationSha256 neutral=$expectedNeutralSignature"
        }
        'Test' {
            Assert-Dependency -VerifyArchive
            Invoke-BlenderBridge -Arguments @('self-test')
            Import-CanonicalWorkingFile -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath
            Invoke-BlenderBridge -OpenWorkingFile $workingPath -Arguments @(
                'negative-test', '--source', $sourcePath, '--sidecar', $sidecarPath
            )
            Export-CanonicalCandidate -SourcePath $sourcePath -WorkingPath $workingPath -SidecarPath $sidecarPath -CandidatePath $candidatePath
            Validate-Candidate -CandidatePath $candidatePath -EvidencePath $evidencePath
            Assert-RoundTripEvidence -EvidencePath $evidencePath
            Assert-InvalidCandidateRejected -ValidCandidatePath $candidatePath
            Assert-SourceIdentity -Path $sourcePath
            Write-Host 'BLENDER_BRIDGE_TESTS_OK dependency,coordinate,stable_id,metadata_binding,no_op_roundtrip,candidate_validation'
        }
    }
}
finally {
    Pop-Location
}
