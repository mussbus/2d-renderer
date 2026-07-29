param(
    [string]$FoundationEvidenceDirectory = "",
    [string]$SupplementalEvidenceDirectory = "",
    [string]$SemanticReportDirectory = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($FoundationEvidenceDirectory)) {
    $FoundationEvidenceDirectory =
        Join-Path $repositoryRoot "zig-out\p27a_evidence\candidate"
}
if ([string]::IsNullOrWhiteSpace($SupplementalEvidenceDirectory)) {
    $SupplementalEvidenceDirectory =
        Join-Path $repositoryRoot "zig-out\p27b_evidence\candidate"
}
if ([string]::IsNullOrWhiteSpace($SemanticReportDirectory)) {
    $SemanticReportDirectory =
        Join-Path $repositoryRoot "zig-out\p27b_evidence\final_semantic_report"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory =
        Join-Path $repositoryRoot "zig-out\p27b_evidence\review_package"
}
$FoundationEvidenceDirectory =
    [System.IO.Path]::GetFullPath($FoundationEvidenceDirectory)
$SupplementalEvidenceDirectory =
    [System.IO.Path]::GetFullPath($SupplementalEvidenceDirectory)
$SemanticReportDirectory = [System.IO.Path]::GetFullPath($SemanticReportDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

foreach ($requiredDirectory in @(
    $FoundationEvidenceDirectory,
    $SupplementalEvidenceDirectory,
    $SemanticReportDirectory
)) {
    if (-not (Test-Path -LiteralPath $requiredDirectory -PathType Container)) {
        throw "Required Prompt 27B evidence directory is missing: $requiredDirectory"
    }
}
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory(
    (Join-Path $OutputDirectory "png")
) | Out-Null

Add-Type -AssemblyName System.Drawing

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.Convert]::ToHexString(
            $sha.ComputeHash($Bytes)
        )).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FileSha256Hex {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.Convert]::ToHexString(
            $sha.ComputeHash($stream)
        )).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Read-PpmToken {
    param(
        [byte[]]$Bytes,
        [ref]$Index
    )
    while ($Index.Value -lt $Bytes.Length) {
        $value = $Bytes[$Index.Value]
        if ($value -eq 35) {
            while ($Index.Value -lt $Bytes.Length -and
                $Bytes[$Index.Value] -ne 10) {
                $Index.Value += 1
            }
        }
        elseif ($value -eq 9 -or $value -eq 10 -or
            $value -eq 13 -or $value -eq 32) {
            $Index.Value += 1
        }
        else {
            break
        }
    }
    if ($Index.Value -ge $Bytes.Length) {
        throw "Unexpected end of PPM header"
    }
    $start = $Index.Value
    while ($Index.Value -lt $Bytes.Length) {
        $value = $Bytes[$Index.Value]
        if ($value -eq 9 -or $value -eq 10 -or
            $value -eq 13 -or $value -eq 32) {
            break
        }
        $Index.Value += 1
    }
    return [System.Text.Encoding]::ASCII.GetString(
        $Bytes,
        $start,
        $Index.Value - $start
    )
}

function Read-Ppm {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $index = 0
    $magic = Read-PpmToken -Bytes $bytes -Index ([ref]$index)
    $width = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    $height = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    $maximum = [int](Read-PpmToken -Bytes $bytes -Index ([ref]$index))
    if ($magic -ne "P6" -or $width -le 0 -or
        $height -le 0 -or $maximum -ne 255) {
        throw "Unsupported PPM header in $Path"
    }
    if ($index -ge $bytes.Length -or
        ($bytes[$index] -ne 9 -and $bytes[$index] -ne 10 -and
         $bytes[$index] -ne 13 -and $bytes[$index] -ne 32)) {
        throw "PPM payload separator is missing in $Path"
    }
    if ($bytes[$index] -eq 13 -and
        $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
        $index += 2
    }
    else {
        $index += 1
    }
    $payloadBytes = $width * $height * 3
    if ($bytes.Length - $index -ne $payloadBytes) {
        throw "PPM payload length mismatch in $Path"
    }
    $pixels = [byte[]]::new($payloadBytes)
    [System.Array]::Copy($bytes, $index, $pixels, 0, $payloadBytes)
    return [pscustomobject]@{
        width = $width
        height = $height
        payload = $pixels
        payload_bytes = $payloadBytes
        sha256 = Get-Sha256Hex -Bytes $pixels
    }
}

function Convert-PpmToPng {
    param(
        [object]$Ppm,
        [string]$OutputPath
    )
    $bitmap = [System.Drawing.Bitmap]::new(
        $Ppm.width,
        $Ppm.height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $rectangle = [System.Drawing.Rectangle]::new(
        0,
        0,
        $Ppm.width,
        $Ppm.height
    )
    $locked = $bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    try {
        $destination = [byte[]]::new($locked.Stride * $Ppm.height)
        for ($y = 0; $y -lt $Ppm.height; $y += 1) {
            $sourceRow = $y * $Ppm.width * 3
            $destinationRow = $y * $locked.Stride
            for ($x = 0; $x -lt $Ppm.width; $x += 1) {
                $source = $sourceRow + $x * 3
                $destinationIndex = $destinationRow + $x * 3
                $destination[$destinationIndex] = $Ppm.payload[$source + 2]
                $destination[$destinationIndex + 1] =
                    $Ppm.payload[$source + 1]
                $destination[$destinationIndex + 2] = $Ppm.payload[$source]
            }
        }
        [System.Runtime.InteropServices.Marshal]::Copy(
            $destination,
            0,
            $locked.Scan0,
            $destination.Length
        )
    }
    finally {
        $bitmap.UnlockBits($locked)
    }
    try {
        $bitmap.Save(
            $OutputPath,
            [System.Drawing.Imaging.ImageFormat]::Png
        )
    }
    finally {
        $bitmap.Dispose()
    }
}

function Find-Marker {
    param(
        [object]$Ppm,
        [int[]]$Rgb
    )
    [long]$count = 0
    [long]$sumX = 0
    [long]$sumY = 0
    for ($pixel = 0; $pixel -lt
        $Ppm.width * $Ppm.height; $pixel += 1) {
        $offset = $pixel * 3
        if ([Math]::Abs([int]$Ppm.payload[$offset] - $Rgb[0]) -le 1 -and
            [Math]::Abs([int]$Ppm.payload[$offset + 1] - $Rgb[1]) -le 1 -and
            [Math]::Abs([int]$Ppm.payload[$offset + 2] - $Rgb[2]) -le 1) {
            $count += 1
            $sumX += $pixel % $Ppm.width
            $sumY += [Math]::Floor($pixel / [double]$Ppm.width)
        }
    }
    if ($count -eq 0) {
        throw "Required D3D12 marker RGB $($Rgb -join ',') is absent"
    }
    return [pscustomobject]@{
        rgb = $Rgb
        count = $count
        x = [double]$sumX / [double]$count
        y = [double]$sumY / [double]$count
    }
}

$metrics = [System.Collections.Generic.List[object]]::new()
function Add-Metric {
    param(
        [string]$CaseId,
        [string]$Component,
        [string]$Side,
        [string]$Name,
        [double]$Actual,
        [object]$Minimum,
        [object]$Maximum,
        [string]$Unit,
        [string]$Source
    )
    $hasMinimum = $null -ne $Minimum
    $hasMaximum = $null -ne $Maximum
    $passes = (!$hasMinimum -or $Actual -ge [double]$Minimum) -and
        (!$hasMaximum -or $Actual -le [double]$Maximum)
    $metrics.Add([pscustomobject]@{
        case_id = $CaseId
        character_style = if ($Component -eq "environment") {
            "environment"
        }
        else {
            "female"
        }
        view = "declared_capture"
        facing = "declared_capture"
        pose = $CaseId
        outfit = "declared_capture"
        morphology = "nominal"
        component = $Component
        side = $Side
        metric = $Name
        actual = $Actual
        unit = $Unit
        allowed_minimum = if ($hasMinimum) {
            [double]$Minimum
        }
        else {
            $null
        }
        allowed_maximum = if ($hasMaximum) {
            [double]$Maximum
        }
        else {
            $null
        }
        source = $Source
        outcome = if ($passes) { "pass" } else { "fail" }
    })
}

$foundationManifestPath =
    Join-Path $FoundationEvidenceDirectory "capture_manifest.json"
$supplementalManifestPath =
    Join-Path $SupplementalEvidenceDirectory "supplemental_manifest.json"
$semanticReportPath = Join-Path $SemanticReportDirectory "report.json"
foreach ($requiredFile in @(
    $foundationManifestPath,
    $supplementalManifestPath,
    $semanticReportPath
)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required Prompt 27B evidence file is missing: $requiredFile"
    }
}
$foundationManifest =
    Get-Content -Raw -LiteralPath $foundationManifestPath | ConvertFrom-Json
$supplementalManifest =
    Get-Content -Raw -LiteralPath $supplementalManifestPath | ConvertFrom-Json
$semanticReport =
    Get-Content -Raw -LiteralPath $semanticReportPath | ConvertFrom-Json
if ($foundationManifest.capture_count -ne 16 -or
    $foundationManifest.failure_count -ne 0) {
    throw "Prompt 27A state-conditioned source manifest is not accepted"
}
if ($supplementalManifest.schema -ne "prompt27b.supplemental.v2" -or
    $supplementalManifest.capture_count -ne 4 -or
    $supplementalManifest.failure_count -ne 0) {
    throw "Prompt 27B supplemental manifest is not accepted"
}
if ($semanticReport.failure_count -ne 0) {
    throw "Prompt 27B semantic report contains failures"
}

$captureInputs = @(
    [pscustomobject]@{ order = 1; id = "front_idle_contact"; file = "01_initial_front_idle.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 2; id = "side_left_planted"; file = "02_side_left_walk.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 3; id = "side_right_planted"; file = "04_side_right_walk.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 4; id = "jump_safe_headroom"; file = "06_jump_apex.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 5; id = "raised_platform_landing"; file = "08_raised_platform_landing.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 6; id = "theme_contact_invariant"; file = "09_theme_switch_in_place.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 7; id = "camera_resize"; file = "07_camera_resize.ppm"; directory = $SupplementalEvidenceDirectory },
    [pscustomobject]@{ order = 8; id = "abrupt_resize_first_post"; file = "08_abrupt_resize_first_post_debug.ppm"; directory = $SupplementalEvidenceDirectory },
    [pscustomobject]@{ order = 9; id = "approach_no_pass_through"; file = "10_interaction_approach.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 10; id = "coherence_debug"; file = "15_detailed_debug.ppm"; directory = $FoundationEvidenceDirectory },
    [pscustomobject]@{ order = 11; id = "parallax_start_debug"; file = "10_parallax_start_debug.ppm"; directory = $SupplementalEvidenceDirectory },
    [pscustomobject]@{ order = 12; id = "parallax_finish_debug"; file = "11_parallax_finish_debug.ppm"; directory = $SupplementalEvidenceDirectory }
)

$captureRecords = [System.Collections.Generic.List[object]]::new()
foreach ($capture in $captureInputs) {
    $ppmPath = Join-Path $capture.directory $capture.file
    if (-not (Test-Path -LiteralPath $ppmPath -PathType Leaf)) {
        throw "Declared Prompt 27B capture is missing: $ppmPath"
    }
    $ppm = Read-Ppm -Path $ppmPath
    Add-Metric $capture.id "readback" "none" "width" $ppm.width 640 640 "px" "D3D12 PPM payload"
    Add-Metric $capture.id "readback" "none" "height" $ppm.height 480 480 "px" "D3D12 PPM payload"
    $pngName = "{0:D2}_{1}.png" -f $capture.order, $capture.id
    $pngPath = Join-Path $OutputDirectory "png\$pngName"
    Convert-PpmToPng -Ppm $ppm -OutputPath $pngPath
    $captureRecords.Add([pscustomobject]@{
        order = $capture.order
        capture_id = $capture.id
        source_file = $capture.file
        ppm_payload_sha256 = $ppm.sha256
        png_file = "png/$pngName"
        png_sha256 = Get-FileSha256Hex -Path $pngPath
    })
}

$supplementalByName = @{}
foreach ($capture in $supplementalManifest.captures) {
    $supplementalByName[$capture.filename] = $capture
    $ppm = Read-Ppm -Path (
        Join-Path $SupplementalEvidenceDirectory $capture.filename
    )
    if ($ppm.sha256 -cne $capture.pixel_sha256) {
        throw "Supplemental payload hash mismatch: $($capture.filename)"
    }
}

$abruptFilename = "08_abrupt_resize_first_post_debug.ppm"
$abruptMetadata = $supplementalByName[$abruptFilename]
if ($null -eq $abruptMetadata) {
    throw "Abrupt-resize first-post metadata is missing"
}
$abruptPpm = Read-Ppm -Path (
    Join-Path $SupplementalEvidenceDirectory $abruptFilename
)
$boundsTop = Find-Marker -Ppm $abruptPpm -Rgb @(199, 59, 251)
$boundsBottom = Find-Marker -Ppm $abruptPpm -Rgb @(239, 137, 53)
$firstPostValue = if ($abruptMetadata.first_post_abrupt_resize) { 1 } else { 0 }
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "previous_viewport_width"
) $abruptMetadata.previous_viewport_px[0] 960 960 "px" "supplemental metadata"
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "previous_viewport_height"
) $abruptMetadata.previous_viewport_px[1] 540 540 "px" "supplemental metadata"
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "current_viewport_width"
) $abruptMetadata.semantic_viewport_px[0] 640 640 "px" "supplemental metadata"
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "current_viewport_height"
) $abruptMetadata.semantic_viewport_px[1] 480 480 "px" "supplemental metadata"
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "first_post_resize_identity"
) $firstPostValue 1 1 "bool" "supplemental metadata"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "semantic_headroom"
) $abruptMetadata.semantic_headroom_px 16 $null "px" "semantic projection"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "semantic_footroom"
) $abruptMetadata.semantic_footroom_px 16 $null "px" "semantic projection"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "top_marker_pixels"
) $boundsTop.count 49 49 "pixels" "D3D12 marker readback"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "bottom_marker_pixels"
) $boundsBottom.count 49 49 "pixels" "D3D12 marker readback"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "top_projection_error"
) ([Math]::Abs(
    $boundsTop.y - [double]$abruptMetadata.semantic_headroom_px
)) 0 0.5 "px" "D3D12 marker readback versus semantic projection"
Add-Metric "abrupt_resize_first_post" "visible_bounds" "none" (
    "bottom_projection_error"
) ([Math]::Abs(
    (480.0 - $boundsBottom.y) -
        [double]$abruptMetadata.semantic_footroom_px
)) 0 0.5 "px" "D3D12 marker readback versus semantic projection"
Add-Metric "abrupt_resize_first_post" "camera" "none" (
    "instantaneous_reprojection_world_delta"
) $abruptMetadata.instantaneous_reprojection_world_delta_px $null $null (
    "px"
) "classified first-post viewport reprojection"

$subsequentCameraSteps = @(
    $semanticReport.metrics | Where-Object {
        $_.case_id -eq "route_frame" -and
        $_.metric -eq "vertical_step"
    }
)
if ($subsequentCameraSteps.Count -eq 0) {
    throw "Subsequent world-camera metrics are missing"
}
$maximumSubsequentCameraStep = (
    $subsequentCameraSteps |
        Measure-Object -Property actual -Maximum
).Maximum
Add-Metric "abrupt_resize_followup" "camera" "none" (
    "maximum_subsequent_world_camera_step"
) $maximumSubsequentCameraStep 0 16 "px/render" "semantic camera report"

$parallaxColors = @(
    [pscustomobject]@{ name = "far"; rgb = @(3, 251, 113); factor = 0.12 },
    [pscustomobject]@{ name = "midground"; rgb = @(17, 89, 253); factor = 0.46 },
    [pscustomobject]@{ name = "gameplay"; rgb = @(241, 29, 197); factor = 1.0 }
)
$parallaxStart = Read-Ppm -Path (
    Join-Path $SupplementalEvidenceDirectory "10_parallax_start_debug.ppm"
)
$parallaxFinish = Read-Ppm -Path (
    Join-Path $SupplementalEvidenceDirectory "11_parallax_finish_debug.ppm"
)
$startMetadata = $supplementalByName["10_parallax_start_debug.ppm"]
$finishMetadata = $supplementalByName["11_parallax_finish_debug.ppm"]
$cameraTravel = [Math]::Abs(
    [double]$finishMetadata.camera_center_m[0] -
    [double]$startMetadata.camera_center_m[0]
)
$displacements = @{}
foreach ($layer in $parallaxColors) {
    $startMarker = Find-Marker -Ppm $parallaxStart -Rgb $layer.rgb
    $finishMarker = Find-Marker -Ppm $parallaxFinish -Rgb $layer.rgb
    Add-Metric "parallax_start" "environment" "none" (
        "$($layer.name)_marker_pixels"
    ) $startMarker.count 25 $null "pixels" "D3D12 marker readback"
    Add-Metric "parallax_finish" "environment" "none" (
        "$($layer.name)_marker_pixels"
    ) $finishMarker.count 25 $null "pixels" "D3D12 marker readback"
    $actual = [Math]::Abs($finishMarker.x - $startMarker.x)
    $predicted = $cameraTravel * [double]$layer.factor * 82.0
    $displacements[$layer.name] = $actual
    Add-Metric "parallax_displacement" "environment" "none" (
        "$($layer.name)_displacement"
    ) $actual ([double]::Epsilon) $null "px" "D3D12 marker readback"
    Add-Metric "parallax_displacement" "environment" "none" (
        "$($layer.name)_prediction_error"
    ) ([Math]::Abs($actual - $predicted)) 0 0.5 "px" (
        "D3D12 marker readback versus submitted factor"
    )
}
Add-Metric "parallax_displacement" "environment" "none" (
    "far_to_midground_separation"
) ($displacements.midground - $displacements.far) 8 $null "px" (
    "D3D12 marker readback"
)
Add-Metric "parallax_displacement" "environment" "none" (
    "midground_to_gameplay_separation"
) ($displacements.gameplay - $displacements.midground) 8 $null "px" (
    "D3D12 marker readback"
)

$debugPpm = Read-Ppm -Path (
    Join-Path $FoundationEvidenceDirectory "15_detailed_debug.ppm"
)
$surface = Find-Marker -Ppm $debugPpm -Rgb @(11, 239, 239)
$safeTop = Find-Marker -Ppm $debugPpm -Rgb @(247, 13, 167)
$safeBottom = Find-Marker -Ppm $debugPpm -Rgb @(31, 241, 71)
$rightHeel = Find-Marker -Ppm $debugPpm -Rgb @(37, 71, 251)
$rightToe = Find-Marker -Ppm $debugPpm -Rgb @(251, 211, 19)
Add-Metric "coherence_debug" "camera_safe_region" "none" (
    "top_line_position_error"
) ([Math]::Abs($safeTop.y - 16.0)) 0 0.5 "px" "D3D12 marker readback"
Add-Metric "coherence_debug" "camera_safe_region" "none" (
    "bottom_line_position_error"
) ([Math]::Abs($safeBottom.y - 464.0)) 0 0.5 "px" "D3D12 marker readback"
Add-Metric "coherence_debug" "shoe" "right" "heel_to_surface_error" (
    [Math]::Abs($rightHeel.y - $surface.y)
) 0 1.5 "px" "D3D12 marker readback"
Add-Metric "coherence_debug" "shoe" "right" "toe_to_surface_error" (
    [Math]::Abs($rightToe.y - $surface.y)
) 0 1.5 "px" "D3D12 marker readback"

$sheetColumns = 3
$tileWidth = 320
$imageHeight = 240
$labelHeight = 26
$sheetRows = [Math]::Ceiling($captureRecords.Count / [double]$sheetColumns)
$sheet = [System.Drawing.Bitmap]::new(
    $sheetColumns * $tileWidth,
    [int]$sheetRows * ($imageHeight + $labelHeight),
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
)
$graphics = [System.Drawing.Graphics]::FromImage($sheet)
$font = [System.Drawing.Font]::new("Consolas", 10)
try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(15, 20, 32))
    $graphics.InterpolationMode =
        [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    for ($index = 0; $index -lt $captureRecords.Count; $index += 1) {
        $record = $captureRecords[$index]
        $column = $index % $sheetColumns
        $row = [Math]::Floor($index / [double]$sheetColumns)
        $x = $column * $tileWidth
        $y = $row * ($imageHeight + $labelHeight)
        $source = [System.Drawing.Image]::FromFile(
            (Join-Path $OutputDirectory $record.png_file)
        )
        try {
            $graphics.DrawImage($source, $x, $y, $tileWidth, $imageHeight)
        }
        finally {
            $source.Dispose()
        }
        $graphics.DrawString(
            ("{0:D2} {1}" -f $record.order, $record.capture_id),
            $font,
            [System.Drawing.Brushes]::White,
            [single]($x + 3),
            [single]($y + $imageHeight + 2)
        )
    }
    $sheet.Save(
        (Join-Path $OutputDirectory "contact_sheet.png"),
        [System.Drawing.Imaging.ImageFormat]::Png
    )
}
finally {
    $font.Dispose()
    $graphics.Dispose()
    $sheet.Dispose()
}

$failureCount = @($metrics | Where-Object outcome -eq "fail").Count
$result = [ordered]@{
    schema = "prompt27b.review.v1"
    status = if ($failureCount -eq 0) {
        "automated_and_d3d12_pass_pending_owner_review"
    }
    else {
        "rejected"
    }
    manual_visual_acceptance = "PENDING OWNER REVIEW"
    capture_count = $captureRecords.Count
    semantic_metric_count = $semanticReport.metric_count
    pixel_metric_count = $metrics.Count
    failure_count = $failureCount
    captures = $captureRecords
    metrics = $metrics
}
$result | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath (
        Join-Path $OutputDirectory "review_report.json"
    ) -Encoding utf8

$text = [System.Collections.Generic.List[string]]::new()
$text.Add("PROMPT 27B REVIEW PACKAGE")
$text.Add("status=$($result.status)")
$text.Add("manual_visual_acceptance=PENDING OWNER REVIEW")
$text.Add("capture_count=$($result.capture_count)")
$text.Add("semantic_metric_count=$($result.semantic_metric_count)")
$text.Add("pixel_metric_count=$($result.pixel_metric_count)")
$text.Add("failure_count=$failureCount")
$text.Add(
    "parallax_displacement_px=far:$($displacements.far),midground:$($displacements.midground),gameplay:$($displacements.gameplay)"
)
$text.Add("")
$text.Add("CAPTURES")
foreach ($capture in $captureRecords) {
    $text.Add(
        ("{0:D2} {1} {2} ppm_sha256={3} png_sha256={4}" -f
            $capture.order,
            $capture.capture_id,
            $capture.png_file,
            $capture.ppm_payload_sha256,
            $capture.png_sha256)
    )
}
$text.Add("")
$text.Add("PIXEL METRICS")
foreach ($metric in $metrics) {
    $text.Add(
        "$($metric.case_id)/$($metric.component)/$($metric.side) " +
        "$($metric.metric)=$($metric.actual) $($metric.unit) " +
        "allowed=$($metric.allowed_minimum)..$($metric.allowed_maximum) " +
        "$($metric.outcome) source=$($metric.source)"
    )
}
$text | Set-Content -LiteralPath (
    Join-Path $OutputDirectory "review_report.txt"
) -Encoding utf8

if ($failureCount -ne 0) {
    throw "Prompt 27B review package rejected $failureCount pixel metrics"
}
Write-Host (
    "Prompt 27B review package: captures=$($captureRecords.Count) " +
    "semantic_metrics=$($semanticReport.metric_count) " +
    "pixel_metrics=$($metrics.Count) failures=0 output=$OutputDirectory"
)
