param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot 'zig-out/p27c_r1_evidence/torso_audit'
}
$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

function New-Rectangle(
    [int]$x,
    [int]$y,
    [int]$width,
    [int]$height
) {
    return [pscustomobject]@{
        x = $x
        y = $y
        width = $width
        height = $height
    }
}

function Test-PointInRectangles(
    [int]$x,
    [int]$y,
    [object[]]$rectangles
) {
    foreach ($rectangle in $rectangles) {
        if ($x -ge $rectangle.x -and
            $x -lt $rectangle.x + $rectangle.width -and
            $y -ge $rectangle.y -and
            $y -lt $rectangle.y + $rectangle.height) {
            return $true
        }
    }
    return $false
}

function Open-Atlas([string]$relativePath) {
    $path = Join-Path $RepositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Prompt 27C-R1 atlas is missing: $path"
    }
    return [System.Drawing.Bitmap]::new([string](Resolve-Path -LiteralPath $path))
}

function Get-BgraBytes([System.Drawing.Bitmap]$bitmap) {
    $rectangle = [System.Drawing.Rectangle]::new(
        0,
        0,
        $bitmap.Width,
        $bitmap.Height
    )
    $locked = $bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        if ($locked.Stride -le 0) {
            throw 'Prompt 27C-R1 audit requires a top-down positive bitmap stride.'
        }
        $bytes = [byte[]]::new($locked.Stride * $bitmap.Height)
        [System.Runtime.InteropServices.Marshal]::Copy(
            $locked.Scan0,
            $bytes,
            0,
            $bytes.Length
        )
        return [pscustomobject]@{
            width = $bitmap.Width
            height = $bitmap.Height
            stride = $locked.Stride
            bytes = $bytes
        }
    }
    finally {
        $bitmap.UnlockBits($locked)
    }
}

function Get-PixelOffset([object]$image, [int]$x, [int]$y) {
    return $y * $image.stride + $x * 4
}

function Test-PixelEqual(
    [object]$left,
    [object]$right,
    [int]$x,
    [int]$y
) {
    $leftOffset = Get-PixelOffset $left $x $y
    $rightOffset = Get-PixelOffset $right $x $y
    for ($channel = 0; $channel -lt 4; $channel++) {
        if ($left.bytes[$leftOffset + $channel] -ne
            $right.bytes[$rightOffset + $channel]) {
            return $false
        }
    }
    return $true
}

function Get-ChangedPixelAudit(
    [object]$current,
    [object]$reference,
    [object[]]$approvedRectangles
) {
    if ($current.width -ne $reference.width -or
        $current.height -ne $reference.height) {
        throw 'Prompt 27C-R1 changed-pixel inputs have different dimensions.'
    }
    $changed = 0
    $outside = 0
    $minimumX = $current.width
    $minimumY = $current.height
    $maximumX = -1
    $maximumY = -1
    for ($y = 0; $y -lt $current.height; $y++) {
        for ($x = 0; $x -lt $current.width; $x++) {
            $currentOffset = $y * $current.stride + $x * 4
            $referenceOffset = $y * $reference.stride + $x * 4
            if ($current.bytes[$currentOffset] -ne
                    $reference.bytes[$referenceOffset] -or
                $current.bytes[$currentOffset + 1] -ne
                    $reference.bytes[$referenceOffset + 1] -or
                $current.bytes[$currentOffset + 2] -ne
                    $reference.bytes[$referenceOffset + 2] -or
                $current.bytes[$currentOffset + 3] -ne
                    $reference.bytes[$referenceOffset + 3]) {
                $changed++
                $minimumX = [math]::Min($minimumX, $x)
                $minimumY = [math]::Min($minimumY, $y)
                $maximumX = [math]::Max($maximumX, $x)
                $maximumY = [math]::Max($maximumY, $y)
                if (-not (Test-PointInRectangles $x $y $approvedRectangles)) {
                    $outside++
                }
            }
        }
    }
    return [pscustomobject]@{
        changed_pixel_count = $changed
        unapproved_changed_pixel_count = $outside
        bounds = if ($changed -eq 0) {
            $null
        }
        else {
            [pscustomobject]@{
                minimum_x = $minimumX
                minimum_y = $minimumY
                maximum_x = $maximumX
                maximum_y = $maximumY
            }
        }
    }
}

function Get-RegionChangeAudit(
    [object]$current,
    [object]$reference,
    [object]$region
) {
    $changed = 0
    $minimumX = $current.width
    $minimumY = $current.height
    $maximumX = -1
    $maximumY = -1
    for ($y = $region.y; $y -lt $region.y + $region.height; $y++) {
        for ($x = $region.x; $x -lt $region.x + $region.width; $x++) {
            $currentOffset = $y * $current.stride + $x * 4
            $referenceOffset = $y * $reference.stride + $x * 4
            if ($current.bytes[$currentOffset] -ne
                    $reference.bytes[$referenceOffset] -or
                $current.bytes[$currentOffset + 1] -ne
                    $reference.bytes[$referenceOffset + 1] -or
                $current.bytes[$currentOffset + 2] -ne
                    $reference.bytes[$referenceOffset + 2] -or
                $current.bytes[$currentOffset + 3] -ne
                    $reference.bytes[$referenceOffset + 3]) {
                $changed++
                $minimumX = [math]::Min($minimumX, $x)
                $minimumY = [math]::Min($minimumY, $y)
                $maximumX = [math]::Max($maximumX, $x)
                $maximumY = [math]::Max($maximumY, $y)
            }
        }
    }
    return [pscustomobject]@{
        changed_pixel_count = $changed
        bounds = if ($changed -eq 0) {
            $null
        }
        else {
            [pscustomobject]@{
                minimum_x = $minimumX
                minimum_y = $minimumY
                maximum_x = $maximumX
                maximum_y = $maximumY
            }
        }
    }
}

function Get-TransparentMatteCount([object]$image, [object]$region) {
    $count = 0
    for ($y = $region.y; $y -lt $region.y + $region.height; $y++) {
        for ($x = $region.x; $x -lt $region.x + $region.width; $x++) {
            $offset = Get-PixelOffset $image $x $y
            if ($image.bytes[$offset + 3] -eq 0 -and
                ($image.bytes[$offset] -ne 0 -or
                $image.bytes[$offset + 1] -ne 0 -or
                $image.bytes[$offset + 2] -ne 0)) {
                $count++
            }
        }
    }
    return $count
}

function Get-AlphaComponentCount([object]$image, [object]$region) {
    $pixelCount = $region.width * $region.height
    $visited = [bool[]]::new($pixelCount)
    $queue = [System.Collections.Generic.Queue[int]]::new()
    $components = 0
    for ($localY = 0; $localY -lt $region.height; $localY++) {
        for ($localX = 0; $localX -lt $region.width; $localX++) {
            $localIndex = $localY * $region.width + $localX
            if ($visited[$localIndex]) {
                continue
            }
            $offset = Get-PixelOffset `
                $image `
                ($region.x + $localX) `
                ($region.y + $localY)
            if ($image.bytes[$offset + 3] -lt 16) {
                $visited[$localIndex] = $true
                continue
            }
            $components++
            $visited[$localIndex] = $true
            $queue.Enqueue($localIndex)
            while ($queue.Count -gt 0) {
                $candidate = $queue.Dequeue()
                $candidateX = $candidate % $region.width
                $candidateY = [int][math]::Floor(
                    $candidate / [double]$region.width
                )
                foreach ($delta in @(
                    @(-1, 0),
                    @(1, 0),
                    @(0, -1),
                    @(0, 1)
                )) {
                    $nextX = $candidateX + $delta[0]
                    $nextY = $candidateY + $delta[1]
                    if ($nextX -lt 0 -or $nextX -ge $region.width -or
                        $nextY -lt 0 -or $nextY -ge $region.height) {
                        continue
                    }
                    $nextIndex = $nextY * $region.width + $nextX
                    if ($visited[$nextIndex]) {
                        continue
                    }
                    $visited[$nextIndex] = $true
                    $nextOffset = Get-PixelOffset `
                        $image `
                        ($region.x + $nextX) `
                        ($region.y + $nextY)
                    if ($image.bytes[$nextOffset + 3] -ge 16) {
                        $queue.Enqueue($nextIndex)
                    }
                }
            }
        }
    }
    return $components
}

function Get-AlphaMask([object]$image, [object]$region) {
    $mask = [bool[]]::new($region.width * $region.height)
    for ($localY = 0; $localY -lt $region.height; $localY++) {
        for ($localX = 0; $localX -lt $region.width; $localX++) {
            $offset = Get-PixelOffset `
                $image `
                ($region.x + $localX) `
                ($region.y + $localY)
            $mask[$localY * $region.width + $localX] =
                $image.bytes[$offset + 3] -ge 16
        }
    }
    return $mask
}

function Get-MirroredMask(
    [bool[]]$mask,
    [int]$width,
    [int]$height
) {
    $mirrored = [bool[]]::new($mask.Length)
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $mirrored[$y * $width + ($width - 1 - $x)] =
                $mask[$y * $width + $x]
        }
    }
    return $mirrored
}

function Test-MasksEqual([bool[]]$left, [bool[]]$right) {
    if ($left.Length -ne $right.Length) {
        return $false
    }
    for ($index = 0; $index -lt $left.Length; $index++) {
        if ($left[$index] -ne $right[$index]) {
            return $false
        }
    }
    return $true
}

function Test-BilinearMatteFixture {
    $skin = @(210.0, 104.0, 58.0)
    $dark = @(13.0, 25.0, 51.0)
    $light = @(238.0, 241.0, 245.0)
    function Composite-Sample([double[]]$transparentRgb, [double[]]$background) {
        $alpha = 0.5
        $result = [double[]]::new(3)
        for ($channel = 0; $channel -lt 3; $channel++) {
            $sampleRgb = (
                $transparentRgb[$channel] + $skin[$channel]
            ) * 0.5
            $result[$channel] =
                $sampleRgb * $alpha + $background[$channel] * (1.0 - $alpha)
        }
        return $result
    }
    foreach ($background in @($dark, $light)) {
        $normalized = Composite-Sample @(0.0, 0.0, 0.0) $background
        $whiteMatte = Composite-Sample @(255.0, 255.0, 255.0) $background
        for ($channel = 0; $channel -lt 3; $channel++) {
            if ($whiteMatte[$channel] - $normalized[$channel] -lt 63.0) {
                return $false
            }
        }
    }
    return $true
}

$styles = @(
    [pscustomobject]@{
        style = 'male'
        current = 'assets/art/p27c_male_base_anatomy_atlas.png'
        predecessor = 'assets/art/p25a_male_base_anatomy_atlas.png'
        rejected = 'assets/art/source/p27c_rejected/prompt27c_owner_rejected_male_atlas.png'
        rejected_sha256 = 'fffe01c6f525801881d5c9ac7700ce395aa855bf7a1fa912fe4e752a1a3ba1f7'
        regions = @(
            [pscustomobject]@{
                id = 'male_front_torso'
                atlas = New-Rectangle 248 430 150 182
                approved = New-Rectangle 269 432 108 33
            },
            [pscustomobject]@{
                id = 'male_side_torso'
                atlas = New-Rectangle 284 17 95 216
                approved = New-Rectangle 289 17 27 42
            }
        )
    },
    [pscustomobject]@{
        style = 'female'
        current = 'assets/art/p27c_female_base_anatomy_atlas.png'
        predecessor = 'assets/art/p25a_female_base_anatomy_atlas.png'
        rejected = 'assets/art/source/p27c_rejected/prompt27c_owner_rejected_female_atlas.png'
        rejected_sha256 = 'c31aba20b4cff0439abe71f22c9d61a91308a7f02096518c230f9c7d046b3af2'
        regions = @(
            [pscustomobject]@{
                id = 'female_front_torso'
                atlas = New-Rectangle 224 446 124 182
                approved = New-Rectangle 240 449 93 34
            },
            [pscustomobject]@{
                id = 'female_side_torso'
                atlas = New-Rectangle 245 39 99 190
                approved = New-Rectangle 250 40 28 17
            }
        )
    }
)

$pageReports = [System.Collections.Generic.List[object]]::new()
$regionReports = [System.Collections.Generic.List[object]]::new()
foreach ($style in $styles) {
    $rejectedPath = Join-Path $RepositoryRoot $style.rejected
    $observedRejectedHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $rejectedPath
    ).Hash.ToLowerInvariant()
    if ($observedRejectedHash -cne $style.rejected_sha256) {
        throw "Owner-rejected $($style.style) atlas hash changed."
    }

    $currentBitmap = Open-Atlas $style.current
    $predecessorBitmap = Open-Atlas $style.predecessor
    $rejectedBitmap = Open-Atlas $style.rejected
    try {
        $current = Get-BgraBytes $currentBitmap
        $predecessor = Get-BgraBytes $predecessorBitmap
        $rejected = Get-BgraBytes $rejectedBitmap
        $approved = @($style.regions | ForEach-Object { $_.approved })
        $predecessorAudit = Get-ChangedPixelAudit `
            $current `
            $predecessor `
            $approved
        if ($predecessorAudit.changed_pixel_count -eq 0 -or
            $predecessorAudit.unapproved_changed_pixel_count -ne 0) {
            throw (
                "Prompt 27C-R1 $($style.style) page changed outside the " +
                'approved shoulder corrections.'
            )
        }
        $rejectedAudit = Get-ChangedPixelAudit `
            $current `
            $rejected `
            @(
                New-Rectangle 0 0 $current.width $current.height
            )
        foreach ($region in $style.regions) {
            $change = Get-RegionChangeAudit `
                $current `
                $predecessor `
                $region.atlas
            $matteCount = Get-TransparentMatteCount $current $region.atlas
            $componentCount = Get-AlphaComponentCount $current $region.atlas
            if ($change.changed_pixel_count -eq 0) {
                throw "Prompt 27C-R1 region was not corrected: $($region.id)"
            }
            if ($matteCount -ne 0) {
                throw "Transparent matte RGB remains in $($region.id)."
            }
            if ($componentCount -ne 1) {
                throw (
                    "$($region.id) has $componentCount alpha components; " +
                    'expected one continuous torso.'
                )
            }
            $mask = Get-AlphaMask $current $region.atlas
            $mirrored = Get-MirroredMask `
                $mask `
                $region.atlas.width `
                $region.atlas.height
            $roundTrip = Get-MirroredMask `
                $mirrored `
                $region.atlas.width `
                $region.atlas.height
            if (-not (Test-MasksEqual $mask $roundTrip)) {
                throw "Directional mirror round-trip failed for $($region.id)."
            }
            $regionReports.Add([pscustomobject]@{
                id = $region.id
                atlas_rectangle = $region.atlas
                approved_correction_rectangle = $region.approved
                changed_pixels_from_predecessor = $change.changed_pixel_count
                changed_bounds = $change.bounds
                alpha_component_count = $componentCount
                transparent_nonzero_rgb_count = $matteCount
                left_right_source_policy = 'one_source_region_reflected_by_transform'
                directional_mask_round_trip = 'pass'
            })
        }
        $pageReports.Add([pscustomobject]@{
            style = $style.style
            current_path = $style.current
            current_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath (
                    Join-Path $RepositoryRoot $style.current
                )
            ).Hash.ToLowerInvariant()
            predecessor_path = $style.predecessor
            predecessor_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath (
                    Join-Path $RepositoryRoot $style.predecessor
                )
            ).Hash.ToLowerInvariant()
            rejected_path = $style.rejected
            rejected_sha256 = $observedRejectedHash
            predecessor_changed_pixels = $predecessorAudit.changed_pixel_count
            predecessor_unapproved_changed_pixels =
                $predecessorAudit.unapproved_changed_pixel_count
            predecessor_changed_bounds = $predecessorAudit.bounds
            rejected_to_current_changed_pixels =
                $rejectedAudit.changed_pixel_count
        })
    }
    finally {
        $currentBitmap.Dispose()
        $predecessorBitmap.Dispose()
        $rejectedBitmap.Dispose()
    }
}

if (-not (Test-BilinearMatteFixture)) {
    throw 'Controlled transparent-white bilinear matte fixture was not rejected.'
}

$fixtureMask = [bool[]]@(
    $false, $false, $false,
    $false, $true, $false,
    $false, $false, $false
)
$fixtureMirror = Get-MirroredMask $fixtureMask 3 3
$fixtureMirror[0] = -not $fixtureMirror[0]
if (Test-MasksEqual $fixtureMask $fixtureMirror) {
    throw 'Controlled directional-silhouette mismatch was not rejected.'
}

$fixtureBitmap = [System.Drawing.Bitmap]::new(
    5,
    5,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
try {
    $fixtureBitmap.SetPixel(1, 1, [System.Drawing.Color]::White)
    $fixtureBitmap.SetPixel(3, 3, [System.Drawing.Color]::White)
    $fixture = Get-BgraBytes $fixtureBitmap
    if ((Get-AlphaComponentCount $fixture (New-Rectangle 0 0 5 5)) -ne 2) {
        throw 'Controlled detached-geometry fixture was not rejected.'
    }
}
finally {
    $fixtureBitmap.Dispose()
}

$outsideCurrent = [System.Drawing.Bitmap]::new(
    4,
    4,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$outsideReference = [System.Drawing.Bitmap]::new(
    4,
    4,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
try {
    $outsideCurrent.SetPixel(3, 3, [System.Drawing.Color]::White)
    $outsideAudit = Get-ChangedPixelAudit `
        (Get-BgraBytes $outsideCurrent) `
        (Get-BgraBytes $outsideReference) `
        @(
            New-Rectangle 0 0 2 2
        )
    if ($outsideAudit.unapproved_changed_pixel_count -ne 1) {
        throw 'Controlled unapproved-pixel fixture was not rejected.'
    }
}
finally {
    $outsideCurrent.Dispose()
    $outsideReference.Dispose()
}

[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$report = [ordered]@{
    schema = 'prompt27c-r1.torso-audit.v1'
    status = 'automated_pass_owner_visual_review_pending'
    owner_visual_acceptance = 'PENDING OWNER REVIEW'
    production_sampler = 'nearest'
    production_alpha_convention = 'straight_alpha'
    production_rgb_blend = 'src_alpha_one_minus_src_alpha'
    automated_failure_count = 0
    page_count = $pageReports.Count
    region_count = $regionReports.Count
    pages = $pageReports
    regions = $regionReports
    controlled_fixtures = @(
        'transparent_white_bilinear_matte_rejected',
        'directional_silhouette_mismatch_rejected',
        'detached_geometry_rejected',
        'unapproved_outside_pixel_rejected'
    )
}
$report | ConvertTo-Json -Depth 8 |
    Set-Content -Encoding utf8 (
        Join-Path $OutputDirectory 'torso_audit.json'
    )

$text = @(
    'PROMPT 27C-R1 TORSO AUDIT',
    'status=automated_pass_owner_visual_review_pending',
    'owner_visual_acceptance=PENDING OWNER REVIEW',
    'alpha=straight_alpha',
    'sampler=nearest',
    "pages=$($pageReports.Count)",
    "regions=$($regionReports.Count)",
    'controlled_fixtures=4/4 rejected',
    'unapproved_changed_pixels=0'
)
$text | Set-Content -Encoding utf8 (
    Join-Path $OutputDirectory 'torso_audit.txt'
)

Write-Host (
    "Prompt 27C-R1 torso audit passed: pages=$($pageReports.Count), " +
    "regions=$($regionReports.Count), fixtures=4/4, " +
    'unapproved_changed_pixels=0, owner_visual_acceptance=PENDING.'
)
