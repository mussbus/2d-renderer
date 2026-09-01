param(
    [string]$EvidenceDirectory =
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'zig-out/p27c_evidence/candidate'),
    [string]$BaselineDirectory =
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'zig-out/p27c_evidence/pre_correction_head_3259f79/d3d12_run_1'),
    [string]$SemanticReportDirectory =
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'zig-out/p27c_evidence/final_semantic_report'),
    [string]$OutputDirectory =
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'zig-out/p27c_evidence/final_review_package')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Get-Sha256Hex([byte[]]$bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $sha.ComputeHash($bytes)
        ).Replace('-', '')).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Read-PpmToken([byte[]]$bytes, [ref]$index) {
    while ($index.Value -lt $bytes.Length) {
        $value = $bytes[$index.Value]
        if ($value -eq 35) {
            while ($index.Value -lt $bytes.Length -and
                $bytes[$index.Value] -ne 10) {
                $index.Value += 1
            }
        }
        elseif ($value -eq 9 -or $value -eq 10 -or
            $value -eq 13 -or $value -eq 32) {
            $index.Value += 1
        }
        else {
            break
        }
    }
    if ($index.Value -ge $bytes.Length) {
        throw 'Unexpected end of PPM header.'
    }
    $start = $index.Value
    while ($index.Value -lt $bytes.Length) {
        $value = $bytes[$index.Value]
        if ($value -eq 9 -or $value -eq 10 -or
            $value -eq 13 -or $value -eq 32) {
            break
        }
        $index.Value += 1
    }
    return [System.Text.Encoding]::ASCII.GetString(
        $bytes,
        $start,
        $index.Value - $start
    )
}

function Read-Ppm([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $index = 0
    $magic = Read-PpmToken $bytes ([ref]$index)
    $width = [int](Read-PpmToken $bytes ([ref]$index))
    $height = [int](Read-PpmToken $bytes ([ref]$index))
    $maximum = [int](Read-PpmToken $bytes ([ref]$index))
    if ($magic -ne 'P6' -or $width -ne 640 -or
        $height -ne 480 -or $maximum -ne 255) {
        throw "Unsupported Prompt 27C PPM header: $path"
    }
    if ($bytes[$index] -eq 13 -and $bytes[$index + 1] -eq 10) {
        $index += 2
    }
    else {
        $index += 1
    }
    $payloadLength = $width * $height * 3
    if ($bytes.Length - $index -ne $payloadLength) {
        throw "Prompt 27C PPM payload length mismatch: $path"
    }
    $payload = [byte[]]::new($payloadLength)
    [System.Array]::Copy($bytes, $index, $payload, 0, $payloadLength)
    return [pscustomobject]@{
        width = $width
        height = $height
        payload = $payload
        payload_sha256 = Get-Sha256Hex $payload
    }
}

function Convert-PpmToBitmap([object]$ppm) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $ppm.width,
        $ppm.height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $ppm.width, $ppm.height)
    $locked = $bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    try {
        $destination = [byte[]]::new($locked.Stride * $ppm.height)
        for ($y = 0; $y -lt $ppm.height; $y++) {
            for ($x = 0; $x -lt $ppm.width; $x++) {
                $source = ($y * $ppm.width + $x) * 3
                $target = $y * $locked.Stride + $x * 3
                $destination[$target] = $ppm.payload[$source + 2]
                $destination[$target + 1] = $ppm.payload[$source + 1]
                $destination[$target + 2] = $ppm.payload[$source]
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
    return $bitmap
}

function New-LabeledSheet(
    [object[]]$items,
    [int]$columns,
    [int]$cellWidth,
    [int]$cellHeight,
    [string]$outputPath
) {
    $rows = [int][math]::Ceiling($items.Count / [double]$columns)
    $labelHeight = 24
    $sheet = [System.Drawing.Bitmap]::new(
        $columns * $cellWidth,
        $rows * ($cellHeight + $labelHeight)
    )
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($sheet)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 13, 25, 51))
            $graphics.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $font = [System.Drawing.Font]::new('Consolas', 10)
            $brush = [System.Drawing.Brushes]::White
            try {
                for ($index = 0; $index -lt $items.Count; $index++) {
                    $column = $index % $columns
                    $row = [int][math]::Floor($index / [double]$columns)
                    $x = $column * $cellWidth
                    $y = $row * ($cellHeight + $labelHeight)
                    $graphics.DrawImage(
                        $items[$index].bitmap,
                        [System.Drawing.Rectangle]::new($x, $y, $cellWidth, $cellHeight),
                        $items[$index].source,
                        [System.Drawing.GraphicsUnit]::Pixel
                    )
                    $graphics.DrawString(
                        $items[$index].label,
                        $font,
                        $brush,
                        $x + 4,
                        $y + $cellHeight + 3
                    )
                }
            }
            finally {
                $font.Dispose()
            }
        }
        finally {
            $graphics.Dispose()
        }
        $sheet.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $sheet.Dispose()
    }
}

foreach ($path in @(
    (Join-Path $EvidenceDirectory 'manifest.json'),
    (Join-Path $SemanticReportDirectory 'report.json')
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Prompt 27C evidence is missing: $path"
    }
}

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
$pngDirectory = Join-Path $OutputDirectory 'png'
$sheetDirectory = Join-Path $OutputDirectory 'contact_sheets'
[System.IO.Directory]::CreateDirectory($pngDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory($sheetDirectory) | Out-Null

$manifest = Get-Content (Join-Path $EvidenceDirectory 'manifest.json') -Raw |
    ConvertFrom-Json
$semantic = Get-Content (Join-Path $SemanticReportDirectory 'report.json') -Raw |
    ConvertFrom-Json
if ($manifest.schema -ne 'prompt27c.state-conditioned-d3d12.v1' -or
    $manifest.backend -ne 'direct3d12' -or
    $manifest.shader_format -ne 'dxil' -or
    $manifest.capture_count -ne 8 -or
    $manifest.failure_count -ne 0) {
    throw 'Prompt 27C D3D12 manifest contract failed.'
}
if ($semantic.failure_count -ne 0 -or $semantic.metric_count -lt 3788) {
    throw 'Prompt 27C semantic production report is not a zero-failure result.'
}

$records = [System.Collections.Generic.List[object]]::new()
$bitmaps = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($capture in $manifest.captures) {
        $ppmPath = Join-Path $EvidenceDirectory $capture.filename
        $ppm = Read-Ppm $ppmPath
        if ($ppm.payload_sha256 -ne $capture.pixel_sha256) {
            throw "Prompt 27C pixel hash mismatch: $($capture.capture_id)"
        }
        $bitmap = Convert-PpmToBitmap $ppm
        $bitmaps.Add($bitmap)
        $pngName = [System.IO.Path]::ChangeExtension($capture.filename, '.png')
        $pngPath = Join-Path $pngDirectory $pngName
        $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $records.Add([pscustomobject]@{
            capture_id = $capture.capture_id
            ppm = $capture.filename
            png = "png/$pngName"
            render_frame = $capture.render_frame
            simulation_tick = $capture.simulation_tick
            stable_frames = $capture.stable_frames
            view = $capture.resolved_view
            facing = $capture.facing
            animation = $capture.animation
            global_build = $capture.global_build
            elbow_angle_deg = $capture.elbow_angle_deg
            knee_angle_deg = $capture.knee_angle_deg
            trace_records = $capture.anatomy_trace_records
            pixel_sha256 = $capture.pixel_sha256
        })
    }

    $fullItems = for ($index = 0; $index -lt $records.Count; $index++) {
        [pscustomobject]@{
            bitmap = $bitmaps[$index]
            source = [System.Drawing.Rectangle]::new(0, 0, 640, 480)
            label = $records[$index].capture_id
        }
    }
    New-LabeledSheet $fullItems 4 320 240 (
        Join-Path $sheetDirectory 'all_states.png'
    )

    $closeups = @(
        @{ name = 'shoulders'; rectangle = [System.Drawing.Rectangle]::new(175, 70, 315, 100) },
        @{ name = 'elbows_wrists'; rectangle = [System.Drawing.Rectangle]::new(175, 125, 315, 125) },
        @{ name = 'pelvis_hips'; rectangle = [System.Drawing.Rectangle]::new(175, 210, 315, 95) },
        @{ name = 'knees_ankles'; rectangle = [System.Drawing.Rectangle]::new(175, 270, 315, 115) },
        @{ name = 'feet'; rectangle = [System.Drawing.Rectangle]::new(175, 335, 315, 75) }
    )
    foreach ($closeup in $closeups) {
        $items = foreach ($index in @(0, 1, 2, 5, 6, 7)) {
            [pscustomobject]@{
                bitmap = $bitmaps[$index]
                source = $closeup.rectangle
                label = $records[$index].capture_id
            }
        }
        New-LabeledSheet $items 3 420 140 (
            Join-Path $sheetDirectory "$($closeup.name).png"
        )
    }

    if (Test-Path -LiteralPath (Join-Path $BaselineDirectory '01_neutral_front.ppm')) {
        $baselinePpm = Read-Ppm (Join-Path $BaselineDirectory '01_neutral_front.ppm')
        $baselineBitmap = Convert-PpmToBitmap $baselinePpm
        try {
            $comparison = @(
                [pscustomobject]@{
                    bitmap = $baselineBitmap
                    source = [System.Drawing.Rectangle]::new(0, 0, 640, 480)
                    label = 'PRE 3259f79 neutral_front'
                },
                [pscustomobject]@{
                    bitmap = $bitmaps[0]
                    source = [System.Drawing.Rectangle]::new(0, 0, 640, 480)
                    label = 'POST Prompt27C neutral_front'
                }
            )
            New-LabeledSheet $comparison 2 640 480 (
                Join-Path $sheetDirectory 'before_after_neutral_front.png'
            )
        }
        finally {
            $baselineBitmap.Dispose()
        }
    }
}
finally {
    foreach ($bitmap in $bitmaps) {
        $bitmap.Dispose()
    }
}

$assets = @(
    'assets/art/male_base_anatomy_atlas.png',
    'assets/art/female_base_anatomy_atlas.png',
    'assets/art/anatomy_components_atlas.png'
) | ForEach-Object {
    $path = Join-Path (Split-Path -Parent $PSScriptRoot) $_
    [pscustomobject]@{
        path = $_
        sha256 = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
    }
}

$report = [ordered]@{
    schema = 'prompt27c.review-package.v1'
    status = 'automated_pass_owner_visual_review_pending'
    automated_failure_count = 0
    owner_visual_acceptance = 'PENDING OWNER REVIEW'
    semantic_case_count = 102
    semantic_trace_record_count = 2450
    semantic_metric_count = $semantic.metric_count
    semantic_failure_count = $semantic.failure_count
    d3d12_backend = $manifest.backend
    shader_format = $manifest.shader_format
    d3d12_capture_count = $manifest.capture_count
    d3d12_failure_count = $manifest.failure_count
    assets = $assets
    captures = $records
    closeup_sheets = @(
        'contact_sheets/shoulders.png',
        'contact_sheets/elbows_wrists.png',
        'contact_sheets/pelvis_hips.png',
        'contact_sheets/knees_ankles.png',
        'contact_sheets/feet.png'
    )
}
$report | ConvertTo-Json -Depth 8 -Compress |
    Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'review_report.json')

$text = @"
PROMPT 27C AUTOMATED REVIEW PACKAGE
status = automated_pass_owner_visual_review_pending
owner_visual_acceptance = PENDING OWNER REVIEW
semantic_cases = 102
semantic_trace_records = 2450
semantic_metrics = $($semantic.metric_count)
semantic_failures = $($semantic.failure_count)
d3d12_backend = $($manifest.backend)
shader_format = $($manifest.shader_format)
d3d12_captures = $($manifest.capture_count)
d3d12_failures = $($manifest.failure_count)
contact_sheets = shoulders, elbows_wrists, pelvis_hips, knees_ankles, feet
"@
$text | Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'review_report.txt')

$hashManifestPath = Join-Path $OutputDirectory 'sha256.txt'
$hashManifestFullPath = [System.IO.Path]::GetFullPath($hashManifestPath)
$hashLines = @(
    Get-ChildItem -LiteralPath $outputRoot -Recurse -File |
    Where-Object { $_.FullName -ne $hashManifestFullPath } |
    Sort-Object { $_.FullName.Substring($outputRoot.Length + 1) } |
    ForEach-Object {
        '{0}  {1}' -f (
            (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
        ), $_.FullName.Substring($outputRoot.Length + 1).Replace('\', '/')
    }
)
$hashLines | Set-Content -Encoding ascii $hashManifestPath

Write-Host (
    "Prompt 27C review package passed: semantic=$($semantic.metric_count)/" +
    "$($semantic.metric_count), D3D12=8/8, owner_visual_acceptance=PENDING."
)
