param(
    [Parameter(Mandatory = $true)]
    [string]$FirstEvidenceDirectory,
    [Parameter(Mandatory = $true)]
    [string]$SecondEvidenceDirectory,
    [Parameter(Mandatory = $true)]
    [string]$FirstReviewDirectory,
    [Parameter(Mandatory = $true)]
    [string]$SecondReviewDirectory,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$FirstEvidenceDirectory = [System.IO.Path]::GetFullPath($FirstEvidenceDirectory)
$SecondEvidenceDirectory = [System.IO.Path]::GetFullPath($SecondEvidenceDirectory)
$FirstReviewDirectory = [System.IO.Path]::GetFullPath($FirstReviewDirectory)
$SecondReviewDirectory = [System.IO.Path]::GetFullPath($SecondReviewDirectory)
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repositoryRoot "zig-out\p27a_evidence\repeatability.json"
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

function Get-FileSha256Hex {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Repeatability input is missing: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-CanonicalJsonSha256 {
    param([object]$Value)
    $json = $Value | ConvertTo-Json -Depth 20 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

$firstManifest = Get-Content -LiteralPath (
    Join-Path $FirstEvidenceDirectory "capture_manifest.json"
) -Raw | ConvertFrom-Json
$secondManifest = Get-Content -LiteralPath (
    Join-Path $SecondEvidenceDirectory "capture_manifest.json"
) -Raw | ConvertFrom-Json
if ($firstManifest.capture_count -ne 16 -or $secondManifest.capture_count -ne 16) {
    throw "Both repeatability manifests must contain exactly 16 captures"
}
if ($firstManifest.failure_count -ne 0 -or $secondManifest.failure_count -ne 0) {
    throw "Both repeatability manifests must have zero failures"
}

$captureComparisons = [System.Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt 16; $index += 1) {
    $first = $firstManifest.captures[$index]
    $second = $secondManifest.captures[$index]
    $semanticMatch =
        $first.order -eq $second.order -and
        $first.capture_id -ceq $second.capture_id -and
        $first.filename -ceq $second.filename -and
        $first.render_frame -eq $second.render_frame -and
        $first.simulation_tick -eq $second.simulation_tick -and
        $first.stable_ticks -eq $second.stable_ticks -and
        $first.pixel_sha256 -ceq $second.pixel_sha256
    $firstPpmHash = Get-FileSha256Hex (
        Join-Path $FirstEvidenceDirectory $first.filename
    )
    $secondPpmHash = Get-FileSha256Hex (
        Join-Path $SecondEvidenceDirectory $second.filename
    )
    $firstMetadataHash = Get-FileSha256Hex (
        Join-Path $FirstEvidenceDirectory $first.metadata
    )
    $secondMetadataHash = Get-FileSha256Hex (
        Join-Path $SecondEvidenceDirectory $second.metadata
    )
    $pngName = [System.IO.Path]::ChangeExtension(
        [string]$first.filename,
        ".png"
    )
    $firstPngHash = Get-FileSha256Hex (
        Join-Path $FirstReviewDirectory "png\$pngName"
    )
    $secondPngHash = Get-FileSha256Hex (
        Join-Path $SecondReviewDirectory "png\$pngName"
    )
    $captureComparisons.Add([pscustomobject]@{
        order = $first.order
        capture_id = $first.capture_id
        semantic_metadata_match = $semanticMatch
        ppm_file_sha256 = $firstPpmHash
        ppm_byte_identical = $firstPpmHash -ceq $secondPpmHash
        metadata_file_sha256 = $firstMetadataHash
        metadata_byte_identical = $firstMetadataHash -ceq $secondMetadataHash
        png_file_sha256 = $firstPngHash
        png_byte_identical = $firstPngHash -ceq $secondPngHash
    }) | Out-Null
}

$firstMetrics = Get-Content -LiteralPath (
    Join-Path $FirstReviewDirectory "raw_metrics.json"
) -Raw | ConvertFrom-Json
$secondMetrics = Get-Content -LiteralPath (
    Join-Path $SecondReviewDirectory "raw_metrics.json"
) -Raw | ConvertFrom-Json
$firstCanonicalMetrics = [ordered]@{
    schema_version = $firstMetrics.schema_version
    status = $firstMetrics.status
    required_capture_count = $firstMetrics.required_capture_count
    observed_capture_count = $firstMetrics.observed_capture_count
    total_metric_count = $firstMetrics.total_metric_count
    failure_count = $firstMetrics.failure_count
    manual_visual_acceptance = $firstMetrics.manual_visual_acceptance
    required_matrix = $firstMetrics.required_matrix
    metric_summary = $firstMetrics.metric_summary
    raw_metrics = $firstMetrics.raw_metrics
}
$secondCanonicalMetrics = [ordered]@{
    schema_version = $secondMetrics.schema_version
    status = $secondMetrics.status
    required_capture_count = $secondMetrics.required_capture_count
    observed_capture_count = $secondMetrics.observed_capture_count
    total_metric_count = $secondMetrics.total_metric_count
    failure_count = $secondMetrics.failure_count
    manual_visual_acceptance = $secondMetrics.manual_visual_acceptance
    required_matrix = $secondMetrics.required_matrix
    metric_summary = $secondMetrics.metric_summary
    raw_metrics = $secondMetrics.raw_metrics
}
$firstMetricHash = Get-CanonicalJsonSha256 $firstCanonicalMetrics
$secondMetricHash = Get-CanonicalJsonSha256 $secondCanonicalMetrics
$captureFailures = @(
    $captureComparisons |
        Where-Object {
            -not $_.semantic_metadata_match -or
            -not $_.ppm_byte_identical -or
            -not $_.metadata_byte_identical -or
            -not $_.png_byte_identical
        }
)
$metricsMatch = $firstMetricHash -ceq $secondMetricHash
$failureCount = $captureFailures.Count + $(if ($metricsMatch) { 0 } else { 1 })

$report = [ordered]@{
    schema_version = 1
    status = $(if ($failureCount -eq 0) { "repeatable" } else { "mismatch" })
    first_evidence_directory = $FirstEvidenceDirectory
    second_evidence_directory = $SecondEvidenceDirectory
    capture_count = $captureComparisons.Count
    capture_mismatch_count = $captureFailures.Count
    canonical_metric_sha256 = $firstMetricHash
    canonical_metrics_identical = $metricsMatch
    failure_count = $failureCount
    expected_nondeterministic_fields_excluded = @(
        "raw_metrics.evidence_directory"
    )
    captures = $captureComparisons
}
[System.IO.Directory]::CreateDirectory(
    [System.IO.Path]::GetDirectoryName($OutputPath)
) | Out-Null
$report | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM

if ($failureCount -ne 0) {
    throw "Prompt 27A repeatability comparison found $failureCount mismatches"
}

Write-Output "Prompt 27A repeatability: PASS"
Write-Output "Captures: 16/16 byte-identical PPM, metadata, and PNG"
Write-Output "Canonical raw metrics: identical ($firstMetricHash)"
Write-Output "Output: $OutputPath"
