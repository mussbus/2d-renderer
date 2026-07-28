param(
    [string]$EvidenceDirectory = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    $EvidenceDirectory = Join-Path $repositoryRoot "zig-out\p27a_evidence\candidate"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot "zig-out\p27a_evidence\review_package"
}
$EvidenceDirectory = [System.IO.Path]::GetFullPath($EvidenceDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

if (-not (Test-Path -LiteralPath $EvidenceDirectory -PathType Container)) {
    throw "Prompt 27A evidence directory is missing: $EvidenceDirectory"
}
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $OutputDirectory "png")) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $OutputDirectory "contact_sheets")) | Out-Null

Add-Type -AssemblyName System.Drawing

$expected = @(
    [pscustomobject]@{ order = 1; id = "initial_front_idle"; file = "01_initial_front_idle.ppm"; view = "front"; facing = "right" },
    [pscustomobject]@{ order = 2; id = "side_left_walk"; file = "02_side_left_walk.ppm"; view = "side"; facing = "left" },
    [pscustomobject]@{ order = 3; id = "stopped_front_facing_left"; file = "03_stopped_front_facing_left.ppm"; view = "front"; facing = "left" },
    [pscustomobject]@{ order = 4; id = "side_right_walk"; file = "04_side_right_walk.ppm"; view = "side"; facing = "right" },
    [pscustomobject]@{ order = 5; id = "short_jump_rise"; file = "05_short_jump_rise.ppm"; view = "side"; facing = "right" },
    [pscustomobject]@{ order = 6; id = "jump_apex"; file = "06_jump_apex.ppm"; view = "side"; facing = "right" },
    [pscustomobject]@{ order = 7; id = "jump_fall"; file = "07_jump_fall.ppm"; view = "side"; facing = "right" },
    [pscustomobject]@{ order = 8; id = "raised_platform_landing"; file = "08_raised_platform_landing.ppm"; view = $null; facing = $null },
    [pscustomobject]@{ order = 9; id = "theme_switch_in_place"; file = "09_theme_switch_in_place.ppm"; view = "front"; facing = $null },
    [pscustomobject]@{ order = 10; id = "interaction_approach"; file = "10_interaction_approach.ppm"; view = "front"; facing = $null },
    [pscustomobject]@{ order = 11; id = "interaction_reach"; file = "11_interaction_reach.ppm"; view = "side"; facing = $null },
    [pscustomobject]@{ order = 12; id = "interaction_first_contact"; file = "12_interaction_first_contact.ppm"; view = "side"; facing = $null },
    [pscustomobject]@{ order = 13; id = "interaction_release"; file = "13_interaction_release.ppm"; view = "side"; facing = $null },
    [pscustomobject]@{ order = 14; id = "interaction_cleanup_front"; file = "14_interaction_cleanup_front.ppm"; view = "front"; facing = $null },
    [pscustomobject]@{ order = 15; id = "detailed_debug"; file = "15_detailed_debug.ppm"; view = "side"; facing = $null },
    [pscustomobject]@{ order = 16; id = "reset_stable_front"; file = "16_reset_stable_front.ppm"; view = "front"; facing = "right" }
)

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.Convert]::ToHexString($sha.ComputeHash($Bytes))).ToLowerInvariant()
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
        return ([System.Convert]::ToHexString($sha.ComputeHash($stream))).ToLowerInvariant()
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
            while ($Index.Value -lt $Bytes.Length -and $Bytes[$Index.Value] -ne 10) {
                $Index.Value += 1
            }
        }
        elseif ($value -eq 9 -or $value -eq 10 -or $value -eq 13 -or $value -eq 32) {
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
        if ($value -eq 9 -or $value -eq 10 -or $value -eq 13 -or $value -eq 32) {
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
    if ($magic -ne "P6" -or $width -le 0 -or $height -le 0 -or $maximum -ne 255) {
        throw "Unsupported PPM header in $Path"
    }
    if ($index -ge $bytes.Length -or
        ($bytes[$index] -ne 9 -and $bytes[$index] -ne 10 -and
         $bytes[$index] -ne 13 -and $bytes[$index] -ne 32)) {
        throw "PPM header is missing its payload separator in $Path"
    }
    if ($bytes[$index] -eq 13 -and
        $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
        $index += 2
    }
    else {
        $index += 1
    }
    $expectedBytes = $width * $height * 3
    if ($bytes.Length - $index -ne $expectedBytes) {
        throw "PPM payload length mismatch in $Path"
    }
    $pixels = [byte[]]::new($expectedBytes)
    [System.Array]::Copy($bytes, $index, $pixels, 0, $expectedBytes)
    [byte]$minimum = 255
    [byte]$maximumChannel = 0
    [uint64]$sum = 0
    foreach ($channel in $pixels) {
        if ($channel -lt $minimum) { $minimum = $channel }
        if ($channel -gt $maximumChannel) { $maximumChannel = $channel }
        $sum += $channel
    }
    return [pscustomobject]@{
        width = $width
        height = $height
        payload = $pixels
        payload_bytes = $expectedBytes
        sha256 = Get-Sha256Hex -Bytes $pixels
        minimum_channel = [int]$minimum
        maximum_channel = [int]$maximumChannel
        mean_channel = [double]$sum / [double]$expectedBytes
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
    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $Ppm.width, $Ppm.height)
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
                $destination[$destinationIndex + 1] = $Ppm.payload[$source + 1]
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
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function New-ContactSheet {
    param(
        [string]$Name,
        [int[]]$Orders,
        [object[]]$CaptureRecords
    )
    $columns = [Math]::Min(3, $Orders.Count)
    $rows = [Math]::Ceiling($Orders.Count / [double]$columns)
    $tileWidth = 320
    $imageHeight = 240
    $labelHeight = 34
    $sheet = [System.Drawing.Bitmap]::new(
        $columns * $tileWidth,
        [int]$rows * ($imageHeight + $labelHeight),
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    $font = [System.Drawing.Font]::new("Consolas", 10)
    $brush = [System.Drawing.Brushes]::White
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(15, 20, 32))
        $graphics.InterpolationMode =
            [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode =
            [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        for ($index = 0; $index -lt $Orders.Count; $index += 1) {
            $record = $CaptureRecords[$Orders[$index] - 1]
            $column = $index % $columns
            $row = [Math]::Floor($index / $columns)
            $x = $column * $tileWidth
            $y = $row * ($imageHeight + $labelHeight)
            $source = [System.Drawing.Image]::FromFile($record.png_path)
            try {
                $graphics.DrawImage($source, $x, $y, $tileWidth, $imageHeight)
            }
            finally {
                $source.Dispose()
            }
            $label = "{0:D2} {1}`n{2}/{3}/{4}" -f
                $record.order,
                $record.capture_id,
                $record.metadata.resolved_view,
                $record.metadata.gameplay_facing,
                $record.metadata.outfit
            $graphics.DrawString(
                $label,
                $font,
                $brush,
                [single]($x + 3),
                [single]($y + $imageHeight + 1)
            )
        }
        $path = Join-Path $OutputDirectory "contact_sheets\$Name.png"
        $sheet.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        return [pscustomobject]@{
            name = $Name
            file = "contact_sheets/$Name.png"
            sha256 = Get-FileSha256Hex -Path $path
            capture_orders = $Orders
        }
    }
    finally {
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

$metricRows = [System.Collections.Generic.List[object]]::new()
function Add-Metric {
    param(
        [object]$Metadata,
        [string]$Metric,
        [double]$Actual,
        [double]$AllowedMinimum,
        [double]$AllowedMaximum,
        [string]$Unit,
        [string]$Source
    )
    if (-not [double]::IsFinite($Actual) -or
        -not [double]::IsFinite($AllowedMinimum) -or
        -not [double]::IsFinite($AllowedMaximum)) {
        throw "Nonfinite metric data for $($Metadata.capture_id)/$Metric"
    }
    if ($AllowedMinimum -gt $AllowedMaximum) {
        throw "Inverted metric range for $($Metadata.capture_id)/$Metric"
    }
    $passed = $Actual -ge $AllowedMinimum -and $Actual -le $AllowedMaximum
    $violation = if ($Actual -lt $AllowedMinimum) {
        $AllowedMinimum - $Actual
    }
    elseif ($Actual -gt $AllowedMaximum) {
        $Actual - $AllowedMaximum
    }
    else {
        0.0
    }
    $metricRows.Add([pscustomobject]@{
        case_identity = $Metadata.capture_id
        style_body = $Metadata.body
        view = $Metadata.resolved_view
        facing = $Metadata.gameplay_facing
        pose_interaction_phase = "$($Metadata.animation_state)/$($Metadata.interaction.phase)"
        outfit_item = $Metadata.outfit
        morphology = [pscustomobject]@{
            profile = $Metadata.morphology
            global_build_percent = [double]$Metadata.global_build_percent
        }
        metric = $Metric
        actual = $Actual
        unit = $Unit
        allowed_minimum = $AllowedMinimum
        allowed_maximum = $AllowedMaximum
        pass = $passed
        source = $Source
        violation = $violation
    }) | Out-Null
}

function Add-AssertionMetric {
    param(
        [object]$Metadata,
        [string]$Metric,
        [bool]$Condition,
        [string]$Source
    )
    Add-Metric -Metadata $Metadata -Metric $Metric `
        -Actual $(if ($Condition) { 1.0 } else { 0.0 }) `
        -AllowedMinimum 1.0 -AllowedMaximum 1.0 -Unit "boolean" -Source $Source
}

$manifestPath = Join-Path $EvidenceDirectory "capture_manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Capture manifest is missing: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or
    $manifest.capture_count -ne $expected.Count -or
    $manifest.captures.Count -ne $expected.Count -or
    $manifest.failure_count -ne 0 -or
    $manifest.status -ne "candidate_pending_owner_review") {
    throw "Capture manifest header is incomplete or invalid"
}

$ppmFiles = @(Get-ChildItem -LiteralPath $EvidenceDirectory -File -Filter "*.ppm")
if ($ppmFiles.Count -ne $expected.Count) {
    throw "Expected exactly $($expected.Count) PPM captures; found $($ppmFiles.Count)"
}

$captureRecords = [System.Collections.Generic.List[object]]::new()
$captureIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
$captureFiles = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)
$pixelHashes = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)

for ($index = 0; $index -lt $expected.Count; $index += 1) {
    $required = $expected[$index]
    $entry = $manifest.captures[$index]
    if ($entry.order -ne $required.order -or
        $entry.capture_id -cne $required.id -or
        $entry.filename -cne $required.file -or
        $entry.metadata -cne "$($required.file).json") {
        throw "Capture manifest order or identity mismatch at entry $($index + 1)"
    }
    if (-not $captureIds.Add([string]$entry.capture_id) -or
        -not $captureFiles.Add([string]$entry.filename)) {
        throw "Duplicate capture identity or filename: $($entry.capture_id)"
    }
    $ppmPath = Join-Path $EvidenceDirectory $required.file
    $metadataPath = Join-Path $EvidenceDirectory "$($required.file).json"
    if (-not (Test-Path -LiteralPath $ppmPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        throw "Capture or metadata is missing for $($required.id)"
    }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.schema_version -ne 1 -or
        $metadata.capture_id -cne $required.id -or
        $metadata.filename -cne $required.file -or
        $metadata.manual_visual_acceptance -cne "PENDING OWNER REVIEW") {
        throw "Metadata identity/status mismatch for $($required.id)"
    }
    if ($null -eq $metadata.consecutive_stable_ticks -or
        $null -eq $metadata.physics -or
        $null -eq $metadata.interaction.eligible -or
        $null -eq $metadata.reset_generation) {
        throw "Required Prompt 27A semantic metadata is missing for $($required.id)"
    }
    if ($null -ne $required.view -and $metadata.resolved_view -cne $required.view) {
        throw "Required view mismatch for $($required.id)"
    }
    if ($null -ne $required.facing -and $metadata.gameplay_facing -cne $required.facing) {
        throw "Required facing mismatch for $($required.id)"
    }

    $ppm = Read-Ppm -Path $ppmPath
    if (-not $pixelHashes.Add([string]$ppm.sha256)) {
        throw "Duplicate D3D12 pixel payload detected for $($required.id)"
    }
    $pngName = [System.IO.Path]::ChangeExtension($required.file, ".png")
    $pngPath = Join-Path $OutputDirectory "png\$pngName"
    Convert-PpmToPng -Ppm $ppm -OutputPath $pngPath
    $pngHash = Get-FileSha256Hex -Path $pngPath

    Add-Metric $metadata "d3d12_width" $ppm.width 640 640 "px" "independent PPM payload parse"
    Add-Metric $metadata "d3d12_height" $ppm.height 480 480 "px" "independent PPM payload parse"
    Add-Metric $metadata "d3d12_rgb_payload" $ppm.payload_bytes 921600 921600 "bytes" "independent PPM payload parse"
    Add-Metric $metadata "d3d12_dynamic_range" ($ppm.maximum_channel - $ppm.minimum_channel) 1 255 "channel_levels" "independent PPM payload parse"
    Add-AssertionMetric $metadata "payload_hash_matches_metadata" ($ppm.sha256 -ceq $metadata.pixels.sha256) "independent SHA-256 versus metadata"
    Add-AssertionMetric $metadata "payload_hash_matches_manifest" ($ppm.sha256 -ceq $entry.pixel_sha256) "independent SHA-256 versus manifest"
    Add-Metric $metadata "pixel_mean_error" ([Math]::Abs($ppm.mean_channel - [double]$metadata.pixels.mean_channel)) 0 0.000001 "channel_levels" "independent PPM payload parse versus metadata"
    Add-Metric $metadata "stable_tick_hold" $metadata.consecutive_stable_ticks $metadata.required_stable_ticks 4294967295 "fixed_ticks" "authoritative fixed-tick capture tracker"
    Add-Metric $metadata "texture_pages" $metadata.render.texture_pages 1 64 "pages" "production UnifiedRenderQueue observation"
    Add-Metric $metadata "submitted_sprites" $metadata.render.submitted_sprites 1 4096 "sprites" "production UnifiedRenderQueue observation"
    Add-Metric $metadata "steady_update_allocations" $metadata.allocations.update 0 0 "allocations" "production lifetime counters"
    Add-Metric $metadata "steady_submission_allocations" $metadata.allocations.submission 0 0 "allocations" "production lifetime counters"
    Add-Metric $metadata "steady_queue_allocations" $metadata.allocations.queue 0 0 "allocations" "production lifetime counters"

    switch ($required.id) {
        { $_ -in @("initial_front_idle", "stopped_front_facing_left",
                   "theme_switch_in_place", "interaction_approach",
                   "interaction_cleanup_front", "reset_stable_front") } {
            Add-Metric $metadata "idle_horizontal_speed" ([Math]::Abs([double]$metadata.velocity_mps[0])) 0 0.02 "m/s" "authoritative controller state"
            Add-Metric $metadata "idle_vertical_speed" ([Math]::Abs([double]$metadata.velocity_mps[1])) 0 0.02 "m/s" "authoritative controller state"
        }
    }
    switch ($required.id) {
        "side_left_walk" {
            Add-Metric $metadata "leftward_speed" (-[double]$metadata.velocity_mps[0]) 0.20 20 "m/s" "authoritative controller state"
            Add-AssertionMetric $metadata "locomotion_phase_valid" ([bool]$metadata.physics.locomotion_phase_valid) "authoritative animation state"
        }
        "side_right_walk" {
            Add-Metric $metadata "rightward_speed" $metadata.velocity_mps[0] 0.20 20 "m/s" "authoritative controller state"
            Add-AssertionMetric $metadata "locomotion_phase_valid" ([bool]$metadata.physics.locomotion_phase_valid) "authoritative animation state"
        }
        "short_jump_rise" {
            Add-Metric $metadata "rise_speed" $metadata.velocity_mps[1] 0.20 20 "m/s" "authoritative controller state"
            Add-Metric $metadata "airborne_clearance" $metadata.physics.airborne_clearance_m 0.10 100 "m" "authoritative collision state"
            Add-AssertionMetric $metadata "airborne_without_support" (-not [bool]$metadata.grounded -and $null -eq $metadata.supporting_collider) "authoritative collision state"
        }
        "jump_apex" {
            Add-Metric $metadata "apex_vertical_speed" ([Math]::Abs([double]$metadata.velocity_mps[1])) 0 0.35 "m/s" "authoritative controller state"
            Add-Metric $metadata "airborne_clearance" $metadata.physics.airborne_clearance_m 0.10 100 "m" "authoritative collision state"
            Add-AssertionMetric $metadata "airborne_without_support" (-not [bool]$metadata.grounded -and $null -eq $metadata.supporting_collider) "authoritative collision state"
        }
        "jump_fall" {
            Add-Metric $metadata "fall_speed" (-[double]$metadata.velocity_mps[1]) 0.20 20 "m/s" "authoritative controller state"
            Add-Metric $metadata "airborne_clearance" $metadata.physics.airborne_clearance_m 0.10 100 "m" "authoritative collision state"
            Add-AssertionMetric $metadata "airborne_without_support" (-not [bool]$metadata.grounded -and $null -eq $metadata.supporting_collider) "authoritative collision state"
        }
        "raised_platform_landing" {
            Add-AssertionMetric $metadata "landed_this_frame" ([bool]$metadata.physics.landed_this_frame) "authoritative collision transition"
            Add-AssertionMetric $metadata "raised_support_match" (
                $metadata.physics.landing_support -eq $metadata.physics.raised_support -and
                $metadata.supporting_collider -eq $metadata.physics.raised_support
            ) "authoritative collision transition"
            Add-Metric $metadata "left_semantic_sole_surface_error" $metadata.physics.left_surface_error_m 0 0.08 "m" "production foot semantic versus collision ground sample"
            Add-Metric $metadata "right_semantic_sole_surface_error" $metadata.physics.right_surface_error_m 0 0.08 "m" "production foot semantic versus collision ground sample"
            Add-AssertionMetric $metadata "feet_surface_contact_valid" ([bool]$metadata.physics.surface_contact_valid) "production bilateral semantic surface contract"
        }
        "theme_switch_in_place" {
            Add-AssertionMetric $metadata "theme_changed" ([bool]$metadata.theme_transition.changed) "authoritative environment theme transition"
            Add-AssertionMetric $metadata "theme_fingerprint_unchanged" ([bool]$metadata.theme_transition.fingerprint_unchanged) "authoritative immutable collision fingerprint"
            Add-Metric $metadata "theme_root_delta" ([Math]::Abs([double]$metadata.theme_transition.root_delta_m)) 0 0.000001 "m" "authoritative character root"
            Add-Metric $metadata "theme_camera_delta" ([Math]::Abs([double]$metadata.theme_transition.camera_delta_m)) 0 0.000001 "m" "authoritative camera"
        }
        "interaction_approach" {
            Add-AssertionMetric $metadata "interaction_eligible" ([bool]$metadata.interaction.eligible) "authoritative interaction eligibility"
            Add-Metric $metadata "active_interactions" $metadata.interaction.active_count 0 0 "count" "authoritative interaction system"
        }
        "interaction_reach" {
            Add-AssertionMetric $metadata "reach_before_contact" (
                $metadata.interaction.lifecycle -ceq "active" -and
                $metadata.interaction.phase -ceq "approach" -and
                $metadata.interaction.contact_tick -eq 0
            ) "authoritative interaction lifecycle"
        }
        "interaction_first_contact" {
            Add-AssertionMetric $metadata "first_contact_semantic" (
                $metadata.interaction.lifecycle -ceq "active" -and
                $metadata.interaction.phase -ceq "contact" -and
                $metadata.interaction.contact_tick -gt 0
            ) "authoritative interaction lifecycle"
            Add-AssertionMetric $metadata "contact_ik_and_ordering" (
                [bool]$metadata.interaction.ik_active -and
                [bool]$metadata.interaction.ordering_valid
            ) "authoritative IK and occlusion state"
        }
        "interaction_release" {
            Add-AssertionMetric $metadata "release_semantic" (
                $metadata.interaction.phase -ceq "released" -and
                $metadata.interaction.release_tick -gt 0
            ) "authoritative interaction lifecycle"
        }
        "interaction_cleanup_front" {
            Add-Metric $metadata "cleanup_active_interactions" $metadata.interaction.active_count 0 0 "count" "authoritative interaction system"
            Add-Metric $metadata "cleanup_ik_constraints" $metadata.interaction.ik_constraint_count 0 0 "count" "authoritative interaction system"
            Add-Metric $metadata "cleanup_overrides" $metadata.interaction.override_count 0 0 "count" "authoritative presentation ownership"
            Add-Metric $metadata "cleanup_participant_owners" $metadata.interaction.participant_owner_count 0 0 "count" "authoritative presentation ownership"
        }
        "detailed_debug" {
            Add-AssertionMetric $metadata "debug_enabled" ([bool]$metadata.debug.enabled) "authoritative debug state"
            Add-Metric $metadata "debug_enabled_hold" $metadata.debug.enabled_ticks 240 4294967295 "fixed_ticks" "authoritative debug state"
            foreach ($category in @("collider", "root", "ground", "ik", "participant_link")) {
                Add-Metric $metadata "debug_$category" $metadata.debug.$category 1 4096 "primitives" "submitted production diagnostic commands"
            }
        }
        "reset_stable_front" {
            Add-Metric $metadata "reset_generation" $metadata.reset_generation 1 4294967295 "generation" "authoritative reset state"
            Add-Metric $metadata "reset_active_interactions" $metadata.interaction.active_count 0 0 "count" "authoritative interaction system"
            Add-Metric $metadata "reset_ik_constraints" $metadata.interaction.ik_constraint_count 0 0 "count" "authoritative interaction system"
            Add-Metric $metadata "reset_overrides" $metadata.interaction.override_count 0 0 "count" "authoritative presentation ownership"
        }
    }

    $captureRecords.Add([pscustomobject]@{
        order = $required.order
        capture_id = $required.id
        ppm_file = $required.file
        metadata_file = "$($required.file).json"
        png_file = "png/$pngName"
        ppm_payload_sha256 = $ppm.sha256
        png_sha256 = $pngHash
        png_path = $pngPath
        metadata = $metadata
    }) | Out-Null
}

$contactSheets = @(
    New-ContactSheet "01_complete_matrix" (1..16) $captureRecords.ToArray()
    New-ContactSheet "02_static_and_reset" @(1, 3, 8, 9, 14, 16) $captureRecords.ToArray()
    New-ContactSheet "03_locomotion_and_jump" @(2, 4, 5, 6, 7, 8) $captureRecords.ToArray()
    New-ContactSheet "04_interaction_sequence" @(10, 11, 12, 13, 14) $captureRecords.ToArray()
    New-ContactSheet "05_detailed_debug" @(15) $captureRecords.ToArray()
)

$failures = @($metricRows | Where-Object { -not $_.pass })
$metricSummaries = @(
    $metricRows |
        Group-Object -Property metric |
        Sort-Object -Property Name |
        ForEach-Object {
            $values = @($_.Group | ForEach-Object { [double]$_.actual })
            $worst = $_.Group |
                Sort-Object -Property @{ Expression = "violation"; Descending = $true },
                    @{ Expression = "actual"; Descending = $true } |
                Select-Object -First 1
            [pscustomobject]@{
                metric = $_.Name
                case_count = $_.Count
                failure_count = @($_.Group | Where-Object { -not $_.pass }).Count
                minimum = ($values | Measure-Object -Minimum).Minimum
                maximum = ($values | Measure-Object -Maximum).Maximum
                mean = ($values | Measure-Object -Average).Average
                worst_case = $worst.case_identity
            }
        }
)

$rawReport = [ordered]@{
    schema_version = 1
    status = "automated_evidence_pass_manual_visual_pending"
    evidence_directory = $EvidenceDirectory
    required_capture_count = $expected.Count
    observed_capture_count = $captureRecords.Count
    total_metric_count = $metricRows.Count
    failure_count = $failures.Count
    manual_visual_acceptance = "PENDING OWNER REVIEW"
    required_matrix = $expected
    metric_summary = $metricSummaries
    raw_metrics = $metricRows
}
$rawMetricsPath = Join-Path $OutputDirectory "raw_metrics.json"
$rawReport | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $rawMetricsPath -Encoding utf8NoBOM

$reviewCaptures = @(
    $captureRecords | ForEach-Object {
        [ordered]@{
            order = $_.order
            capture_id = $_.capture_id
            ppm_file = $_.ppm_file
            metadata_file = $_.metadata_file
            png_file = $_.png_file
            ppm_payload_sha256 = $_.ppm_payload_sha256
            png_sha256 = $_.png_sha256
            render_frame = $_.metadata.render_frame
            simulation_tick = $_.metadata.simulation_tick
            consecutive_stable_ticks = $_.metadata.consecutive_stable_ticks
            required_stable_ticks = $_.metadata.required_stable_ticks
        }
    }
)
$reviewManifest = [ordered]@{
    schema_version = 1
    status = "candidate_pending_owner_review"
    capture_count = $reviewCaptures.Count
    failure_count = $failures.Count
    captures = $reviewCaptures
    contact_sheets = $contactSheets
    raw_metrics = "raw_metrics.json"
    manual_visual_acceptance = "PENDING OWNER REVIEW"
}
$reviewManifestPath = Join-Path $OutputDirectory "review_manifest.json"
$reviewManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reviewManifestPath -Encoding utf8NoBOM

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("PROMPT 27A OWNER REVIEW PACKAGE") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("Automated evidence: $(if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' })") | Out-Null
$reportLines.Add("Manual visual acceptance: [PENDING OWNER REVIEW]") | Out-Null
$reportLines.Add("Capture count: $($captureRecords.Count)/$($expected.Count)") | Out-Null
$reportLines.Add("Metric count: $($metricRows.Count)") | Out-Null
$reportLines.Add("Metric failures: $($failures.Count)") | Out-Null
$reportLines.Add("Source: $EvidenceDirectory") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("ORDERED CAPTURES") | Out-Null
foreach ($record in $captureRecords) {
    $reportLines.Add((
        "{0:D2} {1} frame={2} tick={3} stable={4}/{5} view={6} facing={7} outfit={8} ppm_sha256={9}" -f
        $record.order,
        $record.capture_id,
        $record.metadata.render_frame,
        $record.metadata.simulation_tick,
        $record.metadata.consecutive_stable_ticks,
        $record.metadata.required_stable_ticks,
        $record.metadata.resolved_view,
        $record.metadata.gameplay_facing,
        $record.metadata.outfit,
        $record.ppm_payload_sha256
    )) | Out-Null
}
$reportLines.Add("") | Out-Null
$reportLines.Add("CONTACT SHEETS") | Out-Null
foreach ($sheet in $contactSheets) {
    $reportLines.Add("$($sheet.file) sha256=$($sheet.sha256)") | Out-Null
}
$reportLines.Add("") | Out-Null
$reportLines.Add("AUTOMATED METRIC FAILURES") | Out-Null
if ($failures.Count -eq 0) {
    $reportLines.Add("None.") | Out-Null
}
else {
    foreach ($failure in $failures) {
        $reportLines.Add((
            "{0}/{1}: actual={2} allowed={3}..{4} {5} source={6}" -f
            $failure.case_identity,
            $failure.metric,
            $failure.actual,
            $failure.allowed_minimum,
            $failure.allowed_maximum,
            $failure.unit,
            $failure.source
        )) | Out-Null
    }
}
$reportLines.Add("") | Out-Null
$reportLines.Add("This package does not approve aesthetic quality or promote goldens.") | Out-Null
$reportLines.Add("Owner review is required for composition, silhouette, pose readability, garment fit, and overall visual quality.") | Out-Null
$humanReportPath = Join-Path $OutputDirectory "review_report.txt"
$reportLines | Set-Content -LiteralPath $humanReportPath -Encoding utf8NoBOM

if ($failures.Count -ne 0) {
    throw "Prompt 27A review package contains $($failures.Count) automated metric failures"
}

Write-Output "Prompt 27A review package: PASS"
Write-Output "Captures: $($captureRecords.Count)/$($expected.Count)"
Write-Output "Metrics: $($metricRows.Count), failures: $($failures.Count)"
Write-Output "Manual visual acceptance: PENDING OWNER REVIEW"
Write-Output "Output: $OutputDirectory"
