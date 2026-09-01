param(
    [string]$AnatomyEvidenceDirectory,
    [string]$FoundationEvidenceDirectory,
    [string]$SemanticReportDirectory,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($AnatomyEvidenceDirectory)) {
    $AnatomyEvidenceDirectory = Join-Path `
        $repositoryRoot `
        'zig-out/p27c_r1_evidence/final_d3d_run/zig-out/p27c_evidence/candidate'
}
if ([string]::IsNullOrWhiteSpace($FoundationEvidenceDirectory)) {
    $FoundationEvidenceDirectory = Join-Path `
        $repositoryRoot `
        'zig-out/p27c_r1_evidence/final_d3d_run/zig-out/p27a_evidence/candidate'
}
if ([string]::IsNullOrWhiteSpace($SemanticReportDirectory)) {
    $SemanticReportDirectory = Join-Path `
        $repositoryRoot `
        'zig-out/p27c_r1_evidence/final_semantic_report'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path `
        $repositoryRoot `
        'zig-out/p27c_r1_evidence/final_review_package'
}

$AnatomyEvidenceDirectory =
    [System.IO.Path]::GetFullPath($AnatomyEvidenceDirectory)
$FoundationEvidenceDirectory =
    [System.IO.Path]::GetFullPath($FoundationEvidenceDirectory)
$SemanticReportDirectory =
    [System.IO.Path]::GetFullPath($SemanticReportDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

function Get-Sha256([string]$path) {
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $path
    ).Hash.ToLowerInvariant()
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
        throw 'Unexpected end of Prompt 27C-R1 PPM header.'
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
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Prompt 27C-R1 PPM is missing: $path"
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $index = 0
    $magic = Read-PpmToken $bytes ([ref]$index)
    $width = [int](Read-PpmToken $bytes ([ref]$index))
    $height = [int](Read-PpmToken $bytes ([ref]$index))
    $maximum = [int](Read-PpmToken $bytes ([ref]$index))
    if ($magic -cne 'P6' -or $maximum -ne 255) {
        throw "Unsupported Prompt 27C-R1 PPM header: $path"
    }
    if ($bytes[$index] -eq 13 -and $bytes[$index + 1] -eq 10) {
        $index += 2
    }
    else {
        $index += 1
    }
    $payloadLength = $width * $height * 3
    if ($bytes.Length - $index -ne $payloadLength) {
        throw "Prompt 27C-R1 PPM payload length mismatch: $path"
    }
    $payload = [byte[]]::new($payloadLength)
    [System.Array]::Copy($bytes, $index, $payload, 0, $payloadLength)
    $payloadHash = [System.Security.Cryptography.SHA256]::HashData($payload)
    $payloadSha = [System.Convert]::ToHexString(
        $payloadHash
    ).ToLowerInvariant()
    return [pscustomobject]@{
        width = $width
        height = $height
        payload = $payload
        payload_sha256 = $payloadSha
    }
}

function Convert-PpmToBitmap([object]$ppm) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $ppm.width,
        $ppm.height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $rectangle = [System.Drawing.Rectangle]::new(
        0,
        0,
        $ppm.width,
        $ppm.height
    )
    $locked = $bitmap.LockBits(
        $rectangle,
        [System.Drawing.Imaging.ImageLockMode]::WriteOnly,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    try {
        $destination = [byte[]]::new($locked.Stride * $ppm.height)
        for ($y = 0; $y -lt $ppm.height; $y++) {
            for ($x = 0; $x -lt $ppm.width; $x++) {
                $sourceOffset = ($y * $ppm.width + $x) * 3
                $targetOffset = $y * $locked.Stride + $x * 3
                $destination[$targetOffset] = $ppm.payload[$sourceOffset + 2]
                $destination[$targetOffset + 1] =
                    $ppm.payload[$sourceOffset + 1]
                $destination[$targetOffset + 2] =
                    $ppm.payload[$sourceOffset]
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

function Save-Scaled(
    [System.Drawing.Bitmap]$source,
    [System.Drawing.Rectangle]$sourceRectangle,
    [int]$scale,
    [string]$path,
    [System.Drawing.Drawing2D.InterpolationMode]$interpolation =
        [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor,
    [System.Drawing.Color]$background =
        [System.Drawing.Color]::Transparent
) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $sourceRectangle.Width * $scale,
        $sourceRectangle.Height * $scale,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear($background)
            $graphics.CompositingMode =
                [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $graphics.InterpolationMode = $interpolation
            $graphics.PixelOffsetMode =
                [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $graphics.DrawImage(
                $source,
                [System.Drawing.Rectangle]::new(
                    0,
                    0,
                    $bitmap.Width,
                    $bitmap.Height
                ),
                $sourceRectangle,
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-Mirrored(
    [System.Drawing.Bitmap]$source,
    [System.Drawing.Rectangle]$sourceRectangle,
    [int]$scale,
    [string]$path
) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $sourceRectangle.Width * $scale,
        $sourceRectangle.Height * $scale,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $graphics.TranslateTransform($bitmap.Width, 0)
            $graphics.ScaleTransform(-1, 1)
            $graphics.DrawImage(
                $source,
                [System.Drawing.Rectangle]::new(
                    0,
                    0,
                    $bitmap.Width,
                    $bitmap.Height
                ),
                $sourceRectangle,
                [System.Drawing.GraphicsUnit]::Pixel
            )
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-Diff(
    [System.Drawing.Bitmap]$current,
    [System.Drawing.Bitmap]$reference,
    [System.Drawing.Rectangle]$rectangle,
    [string]$path
) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $rectangle.Width,
        $rectangle.Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        for ($localY = 0; $localY -lt $rectangle.Height; $localY++) {
            for ($localX = 0; $localX -lt $rectangle.Width; $localX++) {
                $x = $rectangle.X + $localX
                $y = $rectangle.Y + $localY
                $left = $current.GetPixel($x, $y)
                $right = $reference.GetPixel($x, $y)
                if ($left.ToArgb() -eq $right.ToArgb()) {
                    $bitmap.SetPixel(
                        $localX,
                        $localY,
                        [System.Drawing.Color]::FromArgb(255, 18, 31, 48)
                    )
                }
                else {
                    $magnitude = [math]::Max(
                        [math]::Abs([int]$left.A - [int]$right.A),
                        [math]::Max(
                            [math]::Abs([int]$left.R - [int]$right.R),
                            [math]::Max(
                                [math]::Abs([int]$left.G - [int]$right.G),
                                [math]::Abs([int]$left.B - [int]$right.B)
                            )
                        )
                    )
                    $bitmap.SetPixel(
                        $localX,
                        $localY,
                        [System.Drawing.Color]::FromArgb(
                            255,
                            255,
                            [math]::Max(32, 255 - $magnitude),
                            255
                        )
                    )
                }
            }
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function New-LabeledSheet(
    [object[]]$items,
    [int]$columns,
    [int]$cellWidth,
    [int]$imageHeight,
    [int]$labelHeight,
    [string]$path,
    [string]$heading
) {
    $rows = [int][math]::Ceiling($items.Count / [double]$columns)
    $headingHeight = 42
    $bitmap = [System.Drawing.Bitmap]::new(
        $columns * $cellWidth,
        $headingHeight + $rows * ($imageHeight + $labelHeight),
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 13, 25, 51))
            $graphics.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $titleFont = [System.Drawing.Font]::new('Segoe UI', 16)
            $labelFont = [System.Drawing.Font]::new('Consolas', 8)
            try {
                $graphics.DrawString(
                    $heading,
                    $titleFont,
                    [System.Drawing.Brushes]::White,
                    8,
                    8
                )
                for ($index = 0; $index -lt $items.Count; $index++) {
                    $column = $index % $columns
                    $row = [int][math]::Floor($index / [double]$columns)
                    $x = $column * $cellWidth
                    $y = $headingHeight +
                        $row * ($imageHeight + $labelHeight)
                    $image = [System.Drawing.Bitmap]::new($items[$index].path)
                    try {
                        $graphics.DrawImage(
                            $image,
                            [System.Drawing.Rectangle]::new(
                                $x,
                                $y,
                                $cellWidth,
                                $imageHeight
                            )
                        )
                    }
                    finally {
                        $image.Dispose()
                    }
                    $graphics.DrawString(
                        $items[$index].label,
                        $labelFont,
                        [System.Drawing.Brushes]::White,
                        [System.Drawing.RectangleF]::new(
                            $x + 4,
                            $y + $imageHeight + 3,
                            $cellWidth - 8,
                            $labelHeight - 6
                        )
                    )
                }
            }
            finally {
                $titleFont.Dispose()
                $labelFont.Dispose()
            }
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

$baseReviewScript = Join-Path $PSScriptRoot 'build_p27c_review_package.ps1'
& $baseReviewScript `
    -EvidenceDirectory $AnatomyEvidenceDirectory `
    -SemanticReportDirectory $SemanticReportDirectory `
    -OutputDirectory $OutputDirectory

$r1Directory = Join-Path $OutputDirectory 'r1'
[System.IO.Directory]::CreateDirectory($r1Directory) | Out-Null

$visuals = [System.Collections.Generic.List[object]]::new()
function Add-Visual(
    [string]$path,
    [string]$sourceCategory,
    [string]$sourcePath,
    [string]$sourceSha256,
    [string]$status,
    [string]$detail
) {
    $relative = [System.IO.Path]::GetRelativePath($OutputDirectory, $path).
        Replace('\', '/')
    $visuals.Add([pscustomobject]@{
        output_path = $relative
        output_sha256 = Get-Sha256 $path
        source_category = $sourceCategory
        source_path = $sourcePath
        source_sha256 = $sourceSha256
        status = $status
        detail = $detail
    })
}

$anatomyManifestPath = Join-Path $AnatomyEvidenceDirectory 'manifest.json'
$anatomyManifest = Get-Content -Raw -LiteralPath $anatomyManifestPath |
    ConvertFrom-Json
if ($anatomyManifest.backend -cne 'direct3d12' -or
    $anatomyManifest.shader_format -cne 'dxil' -or
    $anatomyManifest.capture_count -ne 8 -or
    $anatomyManifest.failure_count -ne 0) {
    throw 'Prompt 27C-R1 anatomy D3D12 manifest contract failed.'
}
foreach ($capture in $anatomyManifest.captures) {
    $pngPath = Join-Path `
        $OutputDirectory `
        ('png/' + [System.IO.Path]::ChangeExtension($capture.filename, '.png'))
    Add-Visual `
        $pngPath `
        'actual_runtime_production_atlas' `
        (Join-Path $AnatomyEvidenceDirectory $capture.filename) `
        $capture.pixel_sha256 `
        'candidate_pending_owner_review' `
        "D3D12/DXIL readback; capture=$($capture.capture_id)"
}
Get-ChildItem -LiteralPath (Join-Path $OutputDirectory 'contact_sheets') `
    -File `
    -Filter '*.png' |
    ForEach-Object {
        Add-Visual `
            $_.FullName `
            'evaluation_artifact' `
            $anatomyManifestPath `
            (Get-Sha256 $anatomyManifestPath) `
            'PENDING OWNER REVIEW' `
            'Derived contact sheet from declared D3D12/DXIL readbacks.'
    }

$foundationManifestPath =
    Join-Path $FoundationEvidenceDirectory 'capture_manifest.json'
$foundationManifest =
    Get-Content -Raw -LiteralPath $foundationManifestPath | ConvertFrom-Json
if ($foundationManifest.capture_count -ne 16 -or
    $foundationManifest.failure_count -ne 0) {
    throw 'Prompt 27C-R1 foundation regression manifest contract failed.'
}
$clothedIds = @(
    'initial_front_idle',
    'side_left_walk',
    'side_right_walk'
)
$clothedItems = [System.Collections.Generic.List[object]]::new()
foreach ($captureId in $clothedIds) {
    $capture = $foundationManifest.captures |
        Where-Object { $_.capture_id -ceq $captureId } |
        Select-Object -First 1
    if ($null -eq $capture) {
        throw "Required clothed production capture is missing: $captureId"
    }
    $ppmPath = Join-Path $FoundationEvidenceDirectory $capture.filename
    $ppm = Read-Ppm $ppmPath
    if ($ppm.payload_sha256 -cne $capture.pixel_sha256) {
        throw "Foundation readback hash mismatch: $captureId"
    }
    $bitmap = Convert-PpmToBitmap $ppm
    try {
        $pngName = "clothed_$captureId.png"
        $pngPath = Join-Path $r1Directory $pngName
        $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Add-Visual `
            $pngPath `
            'actual_runtime_production_atlas' `
            $ppmPath `
            $capture.pixel_sha256 `
            'candidate_pending_owner_review' `
            "Production skeleton/transforms with garments; capture=$captureId"
        $clothedItems.Add([pscustomobject]@{
            path = $pngPath
            label = "$captureId`nD3D12/DXIL production character + garment"
        })
    }
    finally {
        $bitmap.Dispose()
    }
}

$assetPaths = [ordered]@{
    currentMale = Join-Path $repositoryRoot 'assets/art/male_base_anatomy_atlas.png'
    currentFemale = Join-Path $repositoryRoot 'assets/art/female_base_anatomy_atlas.png'
    preMale = Join-Path $repositoryRoot 'assets/art/p25a_male_base_anatomy_atlas.png'
    preFemale = Join-Path $repositoryRoot 'assets/art/p25a_female_base_anatomy_atlas.png'
    rejectedMale = Join-Path $repositoryRoot 'assets/history/art/rejected/owner_rejected_male_atlas.png'
    rejectedFemale = Join-Path $repositoryRoot 'assets/history/art/rejected/owner_rejected_female_atlas.png'
    candidate = Join-Path $repositoryRoot 'assets/history/art/rejected/male_torso_imagegen_candidate_v1_rejected.png'
}
$assetHashes = [ordered]@{}
foreach ($property in $assetPaths.GetEnumerator()) {
    $assetHashes[$property.Key] = Get-Sha256 $property.Value
}
if ($assetHashes.candidate -cne
    '747949bf121c876e4964402eb3910a2b7c37219c5bf2e6d9226dba41719f0aaa') {
    throw 'Displayed Prompt 27C male torso candidate identity changed.'
}

$female = [System.Drawing.Bitmap]::new($assetPaths.currentFemale)
$preFemale = [System.Drawing.Bitmap]::new($assetPaths.preFemale)
$rejectedFemale = [System.Drawing.Bitmap]::new($assetPaths.rejectedFemale)
$male = [System.Drawing.Bitmap]::new($assetPaths.currentMale)
$preMale = [System.Drawing.Bitmap]::new($assetPaths.preMale)
try {
    $femaleFront = [System.Drawing.Rectangle]::new(224, 446, 124, 182)
    $femaleSide = [System.Drawing.Rectangle]::new(245, 39, 99, 190)
    $maleFront = [System.Drawing.Rectangle]::new(248, 430, 150, 182)
    $maleSide = [System.Drawing.Rectangle]::new(284, 17, 95, 216)
    $isolateSpecs = @(
        [pscustomobject]@{
            name = 'female_front_native'
            rectangle = $femaleFront
            scale = 1
            detail = 'female/front; region_id=5116; semantic_id=1101'
        },
        [pscustomobject]@{
            name = 'female_front_4x_nearest'
            rectangle = $femaleFront
            scale = 4
            detail = 'female/front; region_id=5116; nearest 4x'
        },
        [pscustomobject]@{
            name = 'female_side_right_native'
            rectangle = $femaleSide
            scale = 1
            detail = 'female/side-right; region_id=5101; semantic_id=1101'
        },
        [pscustomobject]@{
            name = 'female_side_right_4x_nearest'
            rectangle = $femaleSide
            scale = 4
            detail = 'female/side-right; region_id=5101; nearest 4x'
        }
    )
    $isolatedItems = [System.Collections.Generic.List[object]]::new()
    foreach ($spec in $isolateSpecs) {
        $path = Join-Path $r1Directory "$($spec.name).png"
        Save-Scaled $female $spec.rectangle $spec.scale $path
        Add-Visual `
            $path `
            'actual_runtime_production_atlas' `
            $assetPaths.currentFemale `
            $assetHashes.currentFemale `
            'candidate_pending_owner_review' `
            "$($spec.detail); TexturePageId=42; runtime page=1; renderer texture index=2"
        $isolatedItems.Add([pscustomobject]@{
            path = $path
            label = "$($spec.name)`n$($spec.detail)"
        })
    }

    foreach ($scale in @(1, 4)) {
        $suffix = if ($scale -eq 1) { 'native' } else { '4x_nearest' }
        $path = Join-Path $r1Directory "female_side_left_$suffix.png"
        Save-Mirrored $female $femaleSide $scale $path
        Add-Visual `
            $path `
            'evaluation_artifact' `
            $assetPaths.currentFemale `
            $assetHashes.currentFemale `
            'candidate_pending_owner_review' `
            'female/side-left; same region_id=5101 reflected by production root transform'
        $isolatedItems.Add([pscustomobject]@{
            path = $path
            label = "female_side_left_$suffix`nsame production region 5101 mirrored"
        })
    }

    foreach ($background in @(
        [pscustomobject]@{
            name = 'dark'
            color = [System.Drawing.Color]::FromArgb(255, 13, 25, 51)
        },
        [pscustomobject]@{
            name = 'light'
            color = [System.Drawing.Color]::FromArgb(255, 238, 241, 245)
        }
    )) {
        foreach ($entry in @(
            [pscustomobject]@{ name = 'front'; rectangle = $femaleFront },
            [pscustomobject]@{ name = 'side'; rectangle = $femaleSide }
        )) {
            $nearestPath = Join-Path `
                $r1Directory `
                "alpha_$($entry.name)_$($background.name)_nearest.png"
            Save-Scaled `
                $female `
                $entry.rectangle `
                4 `
                $nearestPath `
                ([System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor) `
                $background.color
            Add-Visual `
                $nearestPath `
                'evaluation_artifact' `
                $assetPaths.currentFemale `
                $assetHashes.currentFemale `
                'automated_edge_evaluation' `
                "straight-alpha over $($background.name); production nearest sampler"

            $bilinearPath = Join-Path `
                $r1Directory `
                "alpha_$($entry.name)_$($background.name)_bilinear.png"
            Save-Scaled `
                $female `
                $entry.rectangle `
                4 `
                $bilinearPath `
                ([System.Drawing.Drawing2D.InterpolationMode]::Bilinear) `
                $background.color
            Add-Visual `
                $bilinearPath `
                'evaluation_artifact' `
                $assetPaths.currentFemale `
                $assetHashes.currentFemale `
                'automated_edge_evaluation' `
                "straight-alpha over $($background.name); bilinear stress, transparent-white count=0"
        }
    }

    foreach ($entry in @(
        [pscustomobject]@{ name = 'front'; rectangle = $femaleFront },
        [pscustomobject]@{ name = 'side'; rectangle = $femaleSide }
    )) {
        $preDiffPath = Join-Path `
            $r1Directory `
            "diff_female_$($entry.name)_vs_pre27c.png"
        Save-Diff $female $preFemale $entry.rectangle $preDiffPath
        Add-Visual `
            $preDiffPath `
            'evaluation_artifact' `
            "$($assetPaths.currentFemale) + $($assetPaths.preFemale)" `
            "$($assetHashes.currentFemale)+$($assetHashes.preFemale)" `
            'bounded_pixel_difference' `
            "Pixel diff: corrected versus last accepted pre-Prompt-27C $($entry.name)"

        $rejectedDiffPath = Join-Path `
            $r1Directory `
            "diff_female_$($entry.name)_vs_rejected27c.png"
        Save-Diff $female $rejectedFemale $entry.rectangle $rejectedDiffPath
        Add-Visual `
            $rejectedDiffPath `
            'evaluation_artifact' `
            "$($assetPaths.currentFemale) + $($assetPaths.rejectedFemale)" `
            "$($assetHashes.currentFemale)+$($assetHashes.rejectedFemale)" `
            'bounded_pixel_difference' `
            "Pixel diff: corrected versus owner-rejected Prompt 27C $($entry.name)"
    }

    $maleCurrentFrontPath = Join-Path $r1Directory 'male_current_front.png'
    Save-Scaled $male $maleFront 2 $maleCurrentFrontPath
    Add-Visual `
        $maleCurrentFrontPath `
        'actual_runtime_production_atlas' `
        $assetPaths.currentMale `
        $assetHashes.currentMale `
        'candidate_pending_owner_review' `
        'male/front; TexturePageId=41; runtime page=0; renderer texture index=1; region_id=5016; semantic_id=1001; pixel=(248,430)-(398,612); uv=(0.155000,0.437436)-(0.248750,0.622584)'

    $maleCurrentSidePath = Join-Path $r1Directory 'male_current_side.png'
    Save-Scaled $male $maleSide 2 $maleCurrentSidePath
    Add-Visual `
        $maleCurrentSidePath `
        'actual_runtime_production_atlas' `
        $assetPaths.currentMale `
        $assetHashes.currentMale `
        'candidate_pending_owner_review' `
        'male/side; TexturePageId=41; runtime page=0; renderer texture index=1; region_id=5001; semantic_id=1001; pixel=(284,17)-(379,233); uv=(0.177500,0.017294)-(0.236875,0.237030)'

    $preMaleFrontPath = Join-Path $r1Directory 'male_pre27c_front.png'
    Save-Scaled $preMale $maleFront 2 $preMaleFrontPath
    Add-Visual `
        $preMaleFrontPath `
        'reference' `
        $assetPaths.preMale `
        $assetHashes.preMale `
        'last_accepted_pre_prompt27c' `
        'male/front reference; same pixel rectangle (248,430)-(398,612)'
}
finally {
    $female.Dispose()
    $preFemale.Dispose()
    $rejectedFemale.Dispose()
    $male.Dispose()
    $preMale.Dispose()
}

$candidateCopyPath = Join-Path $r1Directory 'displayed_summary_candidate.png'
[System.IO.File]::Copy($assetPaths.candidate, $candidateCopyPath, $true)
Add-Visual `
    $candidateCopyPath `
    'candidate' `
    $assetPaths.candidate `
    $assetHashes.candidate `
    'rejected_review_only_candidate' `
    'Exact summary-displayed ImageGen output; baked checkerboard/no alpha; not consumed by reauthor_p27c_anatomy.ps1; not present in a production atlas.'

$runtimeFront = $anatomyManifest.captures |
    Where-Object { $_.capture_id -ceq 'neutral_front' } |
    Select-Object -First 1
$runtimeFrontPng = Join-Path $OutputDirectory 'png/01_neutral_front.png'
$runtimeBitmap = [System.Drawing.Bitmap]::new($runtimeFrontPng)
try {
    $runtimeCropRectangle =
        [System.Drawing.Rectangle]::new(385, 65, 110, 155)
    $runtimeCropPath = Join-Path $r1Directory 'runtime_male_front_torso_crop.png'
    Save-Scaled $runtimeBitmap $runtimeCropRectangle 2 $runtimeCropPath
    Add-Visual `
        $runtimeCropPath `
        'actual_runtime_production_atlas' `
        (Join-Path $AnatomyEvidenceDirectory $runtimeFront.filename) `
        $runtimeFront.pixel_sha256 `
        'candidate_pending_owner_review' `
        'D3D12/DXIL readback screen crop x=385 y=65 w=110 h=155; male/front source region_id=5016; source atlas renderer texture index=1.'
}
finally {
    $runtimeBitmap.Dispose()
}

$provenanceItems = @(
    [pscustomobject]@{
        path = $candidateCopyPath
        label = "GOOD SUMMARY IMAGE`n$($assetPaths.candidate)`nsha=$($assetHashes.candidate)`nno atlas page/region; REJECTED REVIEW-ONLY CANDIDATE"
    },
    [pscustomobject]@{
        path = $maleCurrentFrontPath
        label = "CURRENT PRODUCTION ATLAS`n$($assetPaths.currentMale)`nsha=$($assetHashes.currentMale)`nTexturePageId=41 / runtime=0 / renderer=1; male_front_torso region=5016; CANDIDATE"
    },
    [pscustomobject]@{
        path = $runtimeCropPath
        label = "ACTUAL RUNTIME D3D12 CROP`n$AnatomyEvidenceDirectory/01_neutral_front.ppm`npixel_sha=$($runtimeFront.pixel_sha256)`nscreen=(385,65,110,155); source region=5016; CANDIDATE"
    },
    [pscustomobject]@{
        path = $preMaleFrontPath
        label = "LAST PRE-27C PRODUCTION`n$($assetPaths.preMale)`nsha=$($assetHashes.preMale)`npixel=(248,430)-(398,612); REFERENCE"
    }
)
$provenanceSheetPath = Join-Path $r1Directory 'provenance_sheet.png'
New-LabeledSheet `
    $provenanceItems `
    4 `
    380 `
    360 `
    140 `
    $provenanceSheetPath `
    'Prompt 27C-R1 exact torso provenance — [PENDING OWNER REVIEW]'
Add-Visual `
    $provenanceSheetPath `
    'evaluation_artifact' `
    'four explicitly labeled provenance sources; see visual_provenance_manifest.json' `
    'multiple_declared_sources' `
    'PENDING OWNER REVIEW' `
    'Good summary candidate versus current atlas, actual D3D12 runtime crop, and last pre-27C reference.'

$directionalItems = @(
    $isolatedItems |
    Where-Object { $_.label -like 'female_side*' }
)
$directionalSheetPath = Join-Path $r1Directory 'female_side_directional.png'
New-LabeledSheet `
    $directionalItems `
    2 `
    396 `
    760 `
    70 `
    $directionalSheetPath `
    'One female side torso source, reflected by authoritative root transform'
Add-Visual `
    $directionalSheetPath `
    'evaluation_artifact' `
    $assetPaths.currentFemale `
    $assetHashes.currentFemale `
    'automated_directional_comparison' `
    'Corresponding side silhouettes use the same alpha mask and exact horizontal reflection.'

$assembledItems = [System.Collections.Generic.List[object]]::new()
foreach ($name in @(
    '01_neutral_front.png',
    '02_neutral_side_right.png',
    '03_neutral_side_left.png'
)) {
    $assembledItems.Add([pscustomobject]@{
        path = Join-Path $OutputDirectory "png/$name"
        label = "$name`nD3D12 body-only production skeleton/transforms"
    })
}
foreach ($item in $clothedItems) {
    $assembledItems.Add($item)
}
$assembledSheetPath = Join-Path $r1Directory 'assembled_and_clothed.png'
New-LabeledSheet `
    $assembledItems.ToArray() `
    3 `
    426 `
    320 `
    64 `
    $assembledSheetPath `
    'Assembled body-only and matching clothed production routes'
Add-Visual `
    $assembledSheetPath `
    'evaluation_artifact' `
    "$anatomyManifestPath + $foundationManifestPath" `
    "$(Get-Sha256 $anatomyManifestPath)+$(Get-Sha256 $foundationManifestPath)" `
    'PENDING OWNER REVIEW' `
    'Production skeleton/transforms and unchanged garments from D3D12/DXIL readbacks.'

$ownerItems = [System.Collections.Generic.List[object]]::new()
foreach ($path in @(
    (Join-Path $r1Directory 'female_front_4x_nearest.png'),
    (Join-Path $r1Directory 'female_side_right_4x_nearest.png'),
    (Join-Path $r1Directory 'female_side_left_4x_nearest.png'),
    (Join-Path $r1Directory 'alpha_front_dark_bilinear.png'),
    (Join-Path $r1Directory 'alpha_front_light_bilinear.png'),
    (Join-Path $r1Directory 'diff_female_front_vs_rejected27c.png'),
    (Join-Path $r1Directory 'diff_female_front_vs_pre27c.png'),
    $assembledSheetPath,
    $provenanceSheetPath
)) {
    $ownerItems.Add([pscustomobject]@{
        path = $path
        label = [System.IO.Path]::GetFileNameWithoutExtension($path)
    })
}
$ownerSheetPath = Join-Path $r1Directory 'owner_review_contact_sheet.png'
New-LabeledSheet `
    $ownerItems.ToArray() `
    3 `
    480 `
    360 `
    45 `
    $ownerSheetPath `
    'Prompt 27C-R1 torso corrective review — [PENDING OWNER REVIEW]'
Add-Visual `
    $ownerSheetPath `
    'evaluation_artifact' `
    'declared R1 production, runtime, reference, and evaluation visuals' `
    'multiple_declared_sources' `
    'PENDING OWNER REVIEW' `
    'Automated gates passed; this sheet does not claim aesthetic approval.'

$pngFiles = @(
    Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File -Filter '*.png'
)
$manifestPaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($visual in $visuals) {
    if (-not $manifestPaths.Add($visual.output_path)) {
        throw "Duplicate visual provenance entry: $($visual.output_path)"
    }
}
foreach ($png in $pngFiles) {
    $relative = [System.IO.Path]::GetRelativePath(
        $OutputDirectory,
        $png.FullName
    ).Replace('\', '/')
    if (-not $manifestPaths.Contains($relative)) {
        throw "Displayed PNG lacks provenance classification: $relative"
    }
}
if ($manifestPaths.Count -ne $pngFiles.Count) {
    throw 'Visual provenance manifest contains an undeclared or missing PNG.'
}

$provenanceManifest = [ordered]@{
    schema = 'prompt27c-r1.visual-provenance.v1'
    status = 'automated_pass_owner_visual_review_pending'
    owner_visual_acceptance = 'PENDING OWNER REVIEW'
    visual_count = $visuals.Count
    png_file_count = $pngFiles.Count
    allowed_source_categories = @(
        'actual_runtime_production_atlas',
        'candidate',
        'reference',
        'evaluation_artifact'
    )
    runtime_route = [ordered]@{
        character_style = 'male'
        presentation_views = @('front', 'side')
        semantic_anatomy_identifier = 'torso'
        semantic_ids = @(
            [ordered]@{ style = 'male'; value = 1001 },
            [ordered]@{ style = 'female'; value = 1101 }
        )
        region_ids = @(
            [ordered]@{ style = 'male'; view = 'front'; value = 5016 },
            [ordered]@{ style = 'male'; view = 'side'; value = 5001 },
            [ordered]@{ style = 'female'; view = 'front'; value = 5116 },
            [ordered]@{ style = 'female'; view = 'side'; value = 5101 }
        )
        production_source = 'src/scene/character_art.zig'
        installed_resource_root = 'zig-out/bin/art'
        male_runtime_resource =
            'zig-out/bin/art/male_base_anatomy_atlas.png'
        female_runtime_resource =
            'zig-out/bin/art/female_base_anatomy_atlas.png'
        sampling = 'nearest'
        alpha = 'straight_alpha'
        rgb_blend = 'src_alpha_one_minus_src_alpha'
    }
    displayed_summary_asset = [ordered]@{
        repository_path = [System.IO.Path]::GetRelativePath(
            $repositoryRoot,
            $assetPaths.candidate
        ).Replace('\', '/')
        sha256 = $assetHashes.candidate
        original_tool_output =
            'C:/Users/Chad/.codex/generated_images/019f9ef4-c5ad-71f1-83a9-749677822134/call_8vevlE29MqtR5h5BrNshZGBW.png'
        producer = 'ImageGen Prompt 27C candidate generation'
        status = 'rejected_review_only_candidate'
        authoring_tool_consumes = $false
        exact_pixels_present_in_production_atlas = $false
        incompatibility = @(
            'baked checkerboard pixels with no alpha',
            'identity-changing proportions',
            'oversized opaque deltoid bulbs',
            'not atlas-layout compatible'
        )
    }
    visuals = $visuals
}
$manifestPath = Join-Path $OutputDirectory 'visual_provenance_manifest.json'
$provenanceManifest | ConvertTo-Json -Depth 10 |
    Set-Content -Encoding utf8 $manifestPath

$report = @(
    'PROMPT 27C-R1 CORRECTIVE REVIEW PACKAGE',
    'status=automated_pass_owner_visual_review_pending',
    'owner_visual_acceptance=PENDING OWNER REVIEW',
    "visuals=$($visuals.Count)",
    "png_files=$($pngFiles.Count)",
    'unclassified_visuals=0',
    'anatomy_d3d12=8/8',
    'foundation_d3d12=16/16',
    'source_categories=actual_runtime_production_atlas,candidate,reference,evaluation_artifact'
)
$report | Set-Content -Encoding utf8 (
    Join-Path $OutputDirectory 'p27c_r1_review_report.txt'
)

Write-Host (
    "Prompt 27C-R1 review package passed: visuals=$($visuals.Count), " +
    "D3D12 anatomy=8/8, foundation=16/16, unclassified=0, " +
    'owner_visual_acceptance=PENDING.'
)
